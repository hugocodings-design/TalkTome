"""Qwen3-TTS pour TalkTome Boost — voix réservées à l'ordinateur.

Programme séparé, dans son propre environnement Python (venv-qwen) : PyTorch
y vit à part, sans risque pour le serveur principal (sherpa-onnx). Le
serveur principal le démarre et lui transmet les demandes des voix
« Qwen3 » sur http://127.0.0.1:47817.

Voix : décrites dans qwen_voices.json. Chacune est créée UNE fois par le
modèle VoiceDesign (un court extrait de référence, rangé dans
qwen_voices\\<id>.wav), puis imitée par le modèle Base à chaque phrase :
c'est la méthode recommandée par Qwen pour garder exactement la même voix
d'une phrase à l'autre.

  python qwen_tts_worker.py --prepare   télécharge les modèles et crée les
                                        extraits manquants (installation)
  python qwen_tts_worker.py             serveur local (lancé par Boost)

Réglages facultatifs dans config.json (même fichier que Boost) :
  "qwen_tts_size":  "1.7B" (défaut) ou "0.6B" — modèle de lecture ; le 0.6B
                    prend moitié moins de mémoire graphique
  "qwen_tts_dtype": "float16" (défaut) ou "float32"
  "qwen_tts_idle_minutes": 10 — libère la carte graphique après ce délai
"""
from __future__ import annotations

import gc
import json
import logging
import os
import sys
import threading
import time
from pathlib import Path

BASE = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'TalkTomeBoost'
HERE = Path(__file__).resolve().parent
VOICES_JSON = (HERE / 'qwen_voices.json') if (HERE / 'qwen_voices.json').exists() \
    else BASE / 'qwen_voices.json'
REF_DIR = BASE / 'qwen_voices'
CONFIG = BASE / 'config.json'
PORT = 47817

BASE.mkdir(parents=True, exist_ok=True)
REF_DIR.mkdir(parents=True, exist_ok=True)
if sys.stdout is None or sys.stderr is None:  # lancé sans console
    _out = open(BASE / 'qwen_console.log', 'a', encoding='utf-8', buffering=1)
    sys.stdout = sys.stdout or _out
    sys.stderr = sys.stderr or _out

logging.basicConfig(
    filename=str(BASE / 'qwen_tts.log'), level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger('qwen-tts')

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402
import torch  # noqa: E402

sys.path.insert(0, str(HERE))
from tempo import change_tempo  # noqa: E402


def _config() -> dict:
    try:
        return json.loads(CONFIG.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


CFG = _config()
SIZE = CFG.get('qwen_tts_size', '1.7B')
DTYPE = torch.float32 if CFG.get('qwen_tts_dtype') == 'float32' else torch.float16
# Délai de veille : celui que Home Connections a donné à TalkTome Boost
# (« tts_idle_seconds », 0 = jamais), sinon l'ancien réglage en minutes.
IDLE_SECONDS = float(CFG['tts_idle_seconds']) if 'tts_idle_seconds' in CFG     else 60 * float(CFG.get('qwen_tts_idle_minutes', 10))
# Essais par voix et par humeur (on garde le plus ressemblant à la voix neutre).
EMOTION_CANDIDATES = max(1, int(CFG.get('qwen_emotion_candidates', 3)))
DEVICE = 'cuda:0' if torch.cuda.is_available() else 'cpu'
if DEVICE == 'cpu':
    DTYPE = torch.float32  # le float16 n'est pas utilisable sur processeur
BASE_MODEL = f'Qwen/Qwen3-TTS-12Hz-{SIZE}-Base'
# VoiceDesign n'existe qu'en 1.7B ; il ne sert qu'à l'installation.
DESIGN_MODEL = 'Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign'

_SPEC = json.loads(VOICES_JSON.read_text(encoding='utf-8'))
VOICES: dict[str, dict] = {v['id']: v for v in _SPEC['voices']}
MOODS: dict[str, dict] = _SPEC.get('moods', {})


def ref_path(voice_id: str, mood: str = 'neutral') -> Path:
    """Extrait de référence d'une voix pour une humeur (neutre : <id>.wav)."""
    return REF_DIR / (f'{voice_id}.wav' if mood == 'neutral' else f'{voice_id}__{mood}.wav')


def _load(name: str):
    from qwen_tts import Qwen3TTSModel
    log.info('chargement de %s (%s, %s)', name, DEVICE, DTYPE)
    # Carte RTX 2080 (Turing) : pas de FlashAttention 2 → attention PyTorch
    # standard (sdpa), et float16 plutôt que bfloat16.
    return Qwen3TTSModel.from_pretrained(
        name, device_map=DEVICE, dtype=DTYPE, attn_implementation='sdpa')


def _free(model) -> None:
    del model
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()


def _cosine(a, b) -> float:
    a = a.flatten().float()
    b = b.flatten().float()
    return float(torch.dot(a, b) / (a.norm() * b.norm() + 1e-9))


def prepare() -> None:
    """Télécharge les modèles et crée les extraits manquants : la voix neutre,
    puis un extrait par humeur. Reprend là où il s'était arrêté."""
    cand_dir = REF_DIR / 'candidates'
    neutral_missing = [v for v in VOICES.values() if not ref_path(v['id']).exists()]
    emotion_jobs = [(v, m) for v in VOICES.values() for m in MOODS
                    if not ref_path(v['id'], m).exists()]
    if neutral_missing or emotion_jobs:
        design = _load(DESIGN_MODEL)
        for v in neutral_missing:
            t = time.perf_counter()
            wavs, sr = design.generate_voice_design(
                text=v['ref_text'], language=v['language'], instruct=v['instruct'])
            sf.write(ref_path(v['id']), wavs[0], sr)
            (REF_DIR / f"{v['id']}.txt").write_text(v['ref_text'], encoding='utf-8')
            _say(f"voix créée : {v['id']} ({v['name']}) en {time.perf_counter() - t:.0f} s")
        # Plusieurs essais par humeur : la description seule ne garantit pas
        # exactement la même personne, on choisira ensuite le plus proche.
        cand_dir.mkdir(parents=True, exist_ok=True)
        for n, (v, m) in enumerate(emotion_jobs, 1):
            text = MOODS[m]['ref_text'][v['language']]
            instruct = f"{v['instruct']}. {MOODS[m]['instruct']}"
            for k in range(EMOTION_CANDIDATES):
                out = cand_dir / f"{v['id']}__{m}__{k}.wav"
                if out.exists():
                    continue
                wavs, sr = design.generate_voice_design(
                    text=text, language=v['language'], instruct=instruct)
                sf.write(out, wavs[0], sr)
            _say(f"humeur {n}/{len(emotion_jobs)} : {v['id']} {m}")
        _free(design)

    # Choix du meilleur essai par empreinte vocale (modèle Base), puis
    # téléchargement du modèle de lecture au passage.
    model = _load(BASE_MODEL)
    if emotion_jobs:
        def embedding(path: Path):
            item = model.create_voice_clone_prompt(ref_audio=str(path), x_vector_only_mode=True)[0]
            return item.ref_spk_embedding

        for v, m in emotion_jobs:
            neutral = embedding(ref_path(v['id']))
            best, best_score = None, -2.0
            for k in range(EMOTION_CANDIDATES):
                c = cand_dir / f"{v['id']}__{m}__{k}.wav"
                if not c.exists():
                    continue
                score = _cosine(neutral, embedding(c))
                if score > best_score:
                    best, best_score = c, score
            if best is None:
                continue
            best.replace(ref_path(v['id'], m))
            (REF_DIR / f"{v['id']}__{m}.txt").write_text(
                MOODS[m]['ref_text'][v['language']], encoding='utf-8')
            for k in range(EMOTION_CANDIDATES):
                (cand_dir / f"{v['id']}__{m}__{k}.wav").unlink(missing_ok=True)
            _say(f"humeur gardée : {v['id']} {m} (ressemblance {best_score:.2f})")
    _free(model)
    if cand_dir.exists() and not any(cand_dir.iterdir()):
        cand_dir.rmdir()
    _say('Qwen3-TTS prêt (voix et humeurs).')


def _say(msg: str) -> None:
    log.info(msg)
    print(msg, flush=True)


# ── Serveur local ────────────────────────────────────────────────────────────

from pydantic import BaseModel  # noqa: E402


class Req(BaseModel):
    voice: str
    text: str
    speed: float = 1.0
    mood: str = 'neutral'


class Engine:
    def __init__(self) -> None:
        self.model = None
        self.prompts: dict[str, object] = {}
        self.lock = threading.Lock()
        self.last_use = time.monotonic()

    def _ensure(self):
        if self.model is None:
            self.model = _load(BASE_MODEL)
            self.prompts.clear()
        return self.model

    def _prompt(self, voice_id: str, mood: str = 'neutral'):
        # Humeur sans extrait (pas encore préparée) : la voix neutre.
        if mood != 'neutral' and not ref_path(voice_id, mood).exists():
            mood = 'neutral'
        key = f'{voice_id}|{mood}'
        p = self.prompts.get(key)
        if p is None:
            wav = ref_path(voice_id, mood)
            if not wav.exists():
                raise FileNotFoundError(f'extrait absent : {wav} (lancer --prepare)')
            ref_text = wav.with_suffix('.txt').read_text(encoding='utf-8')
            p = self.model.create_voice_clone_prompt(ref_audio=str(wav), ref_text=ref_text)
            self.prompts[key] = p
        return p

    def synthesize(self, voice_id: str, text: str, speed: float,
                   mood: str = 'neutral') -> tuple[np.ndarray, int]:
        v = VOICES.get(voice_id)
        if v is None:
            raise KeyError(f'voix inconnue : {voice_id}')
        with self.lock:
            self.last_use = time.monotonic()
            model = self._ensure()
            with torch.inference_mode():
                wavs, sr = model.generate_voice_clone(
                    text=text, language=v['language'],
                    voice_clone_prompt=self._prompt(voice_id, mood))
            self.last_use = time.monotonic()
        audio = np.asarray(wavs[0], dtype=np.float32).reshape(-1)
        return change_tempo(audio, sr, speed), sr

    def unload_if_idle(self) -> None:
        with self.lock:
            if (self.model is not None and IDLE_SECONDS > 0
                    and time.monotonic() - self.last_use > IDLE_SECONDS):
                log.info('inactif : modèle déchargé (mémoire graphique libérée)')
                self._unload()

    def unload(self) -> None:
        with self.lock:
            if self.model is not None:
                log.info('modèle déchargé à la demande (mémoire graphique libérée)')
                self._unload()

    def _unload(self) -> None:
        model, self.model = self.model, None
        self.prompts.clear()
        _free(model)


def serve() -> None:
    import uvicorn
    from fastapi import FastAPI, HTTPException
    from fastapi.responses import Response

    engine = Engine()
    app = FastAPI(title='TalkTome Boost — Qwen3-TTS')

    def wav_bytes(samples: np.ndarray, sr: int) -> bytes:
        pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype('<i2').tobytes()
        n = len(pcm)
        return b''.join([
            b'RIFF', (36 + n).to_bytes(4, 'little'), b'WAVE', b'fmt ',
            (16).to_bytes(4, 'little'), (1).to_bytes(2, 'little'), (1).to_bytes(2, 'little'),
            sr.to_bytes(4, 'little'), (sr * 2).to_bytes(4, 'little'),
            (2).to_bytes(2, 'little'), (16).to_bytes(2, 'little'),
            b'data', n.to_bytes(4, 'little'), pcm])

    @app.get('/health')
    def health():
        ready = all(ref_path(i).exists() for i in VOICES)
        moods_ready = sum(ref_path(i, m).exists() for i in VOICES for m in MOODS)
        return {'ok': True, 'voices_ready': ready, 'moods_ready': moods_ready,
                'moods_total': len(VOICES) * len(MOODS), 'device': DEVICE,
                'model': BASE_MODEL, 'loaded': engine.model is not None}

    class IdleReq(BaseModel):
        seconds: float

    @app.post('/idle')
    def idle(req: IdleReq):
        global IDLE_SECONDS
        IDLE_SECONDS = max(0.0, req.seconds)
        log.info('veille après %s s', IDLE_SECONDS or 'jamais')
        return {'ok': True}

    @app.post('/free')
    def free():
        engine.unload()
        return {'ok': True}

    @app.post('/tts')
    def tts(req: Req):
        t = time.perf_counter()
        try:
            samples, sr = engine.synthesize(req.voice, req.text, req.speed, req.mood)
        except (KeyError, FileNotFoundError) as e:
            raise HTTPException(status_code=404, detail=str(e))
        if samples.size == 0:
            raise HTTPException(status_code=422, detail='synthèse vide')
        log.info('%s : %.1f s audio en %d ms', req.voice, samples.size / sr,
                 (time.perf_counter() - t) * 1000)
        return Response(content=wav_bytes(samples, sr), media_type='audio/wav')

    def janitor():
        while True:
            time.sleep(30)
            try:
                engine.unload_if_idle()
            except Exception:
                log.exception('déchargement impossible')

    threading.Thread(target=janitor, daemon=True).start()
    log.info('Qwen3-TTS démarre — port %s, %s, %s', PORT, BASE_MODEL, DEVICE)
    uvicorn.run(app, host='127.0.0.1', port=PORT, log_level='warning', log_config=None)


if __name__ == '__main__':
    if '--prepare' in sys.argv:
        prepare()
    else:
        serve()
