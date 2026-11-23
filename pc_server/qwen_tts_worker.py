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
IDLE_SECONDS = 60 * float(CFG.get('qwen_tts_idle_minutes', 10))
DEVICE = 'cuda:0' if torch.cuda.is_available() else 'cpu'
if DEVICE == 'cpu':
    DTYPE = torch.float32  # le float16 n'est pas utilisable sur processeur
BASE_MODEL = f'Qwen/Qwen3-TTS-12Hz-{SIZE}-Base'
# VoiceDesign n'existe qu'en 1.7B ; il ne sert qu'à l'installation.
DESIGN_MODEL = 'Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign'

VOICES: dict[str, dict] = {
    v['id']: v for v in json.loads(VOICES_JSON.read_text(encoding='utf-8'))['voices']}


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


def prepare() -> None:
    """Télécharge les modèles et crée les extraits de référence manquants."""
    missing = [v for v in VOICES.values() if not (REF_DIR / f"{v['id']}.wav").exists()]
    if missing:
        design = _load(DESIGN_MODEL)
        for v in missing:
            t = time.perf_counter()
            wavs, sr = design.generate_voice_design(
                text=v['ref_text'], language=v['language'], instruct=v['instruct'])
            sf.write(REF_DIR / f"{v['id']}.wav", wavs[0], sr)
            (REF_DIR / f"{v['id']}.txt").write_text(v['ref_text'], encoding='utf-8')
            msg = f"voix créée : {v['id']} ({v['name']}) en {time.perf_counter() - t:.0f} s"
            log.info(msg)
            print(msg, flush=True)
        _free(design)
    else:
        print('Toutes les voix existent déjà.', flush=True)
    # Télécharge aussi le modèle de lecture, pour que la première phrase
    # n'attende pas un téléchargement.
    model = _load(BASE_MODEL)
    _free(model)
    print('Qwen3-TTS prêt.', flush=True)


# ── Serveur local ────────────────────────────────────────────────────────────

from pydantic import BaseModel  # noqa: E402


class Req(BaseModel):
    voice: str
    text: str
    speed: float = 1.0


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

    def _prompt(self, voice_id: str):
        p = self.prompts.get(voice_id)
        if p is None:
            wav = REF_DIR / f'{voice_id}.wav'
            if not wav.exists():
                raise FileNotFoundError(f'extrait absent : {wav} (lancer --prepare)')
            ref_text = (REF_DIR / f'{voice_id}.txt').read_text(encoding='utf-8')
            p = self.model.create_voice_clone_prompt(ref_audio=str(wav), ref_text=ref_text)
            self.prompts[voice_id] = p
        return p

    def synthesize(self, voice_id: str, text: str, speed: float) -> tuple[np.ndarray, int]:
        v = VOICES.get(voice_id)
        if v is None:
            raise KeyError(f'voix inconnue : {voice_id}')
        with self.lock:
            self.last_use = time.monotonic()
            model = self._ensure()
            with torch.inference_mode():
                wavs, sr = model.generate_voice_clone(
                    text=text, language=v['language'],
                    voice_clone_prompt=self._prompt(voice_id))
            self.last_use = time.monotonic()
        audio = np.asarray(wavs[0], dtype=np.float32).reshape(-1)
        return change_tempo(audio, sr, speed), sr

    def unload_if_idle(self) -> None:
        with self.lock:
            if self.model is not None and time.monotonic() - self.last_use > IDLE_SECONDS:
                log.info('inactif : modèle déchargé (mémoire graphique libérée)')
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
        ready = all((REF_DIR / f'{i}.wav').exists() for i in VOICES)
        return {'ok': True, 'voices_ready': ready, 'device': DEVICE,
                'model': BASE_MODEL, 'loaded': engine.model is not None}

    @app.post('/tts')
    def tts(req: Req):
        t = time.perf_counter()
        try:
            samples, sr = engine.synthesize(req.voice, req.text, req.speed)
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
