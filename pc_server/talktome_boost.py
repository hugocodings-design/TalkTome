"""TalkTome Boost — accélération gratuite de l'app par l'ordinateur.

Le téléphone envoie ici, quand il peut joindre l'ordinateur (Wi-Fi de la
maison ou Tailscale), ce qu'il ferait sinon lui-même :
  - la synthèse des voix IA (Kokoro / Piper, sur la carte graphique) ;
  - l'IA locale Qwen (dictionnaire « dans cette phrase », traduction), via
    le serveur officiel llama.cpp, lui aussi sur la carte graphique.
Mêmes modèles que sur le téléphone : même voix, même qualité, juste plus
vite. Aucune API payante. Si l'ordinateur ne répond pas, l'app fait tout
elle-même, comme avant.

Tout vit dans %LOCALAPPDATA%\\TalkTomeBoost :
  venv\\            environnement Python (sherpa-onnx CUDA, FastAPI)
  models\\tts\\     modèles de voix (mêmes dossiers que sur le téléphone)
  models\\llm\\     qwen3-4b-instruct.gguf
  llama\\           serveur llama.cpp officiel (build CUDA)
  config.json      code d'appairage + port
  boost.log        journal
"""
from __future__ import annotations

import glob
import json
import logging
import os
import secrets
import site
import subprocess
import sys
import threading
import time
from pathlib import Path

BASE = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'TalkTomeBoost'
TTS_DIR = BASE / 'models' / 'tts'
LLM_MODEL = BASE / 'models' / 'llm' / 'qwen3-4b-instruct.gguf'
LLAMA_EXE = BASE / 'llama' / 'llama-server.exe'
CONFIG = BASE / 'config.json'
LLAMA_PORT = 47816
QWEN_PORT = 47817
QWEN_PY = BASE / 'venv-qwen' / 'Scripts' / 'python.exe'
QWEN_WORKER = BASE / 'qwen_tts_worker.py'
VERSION = 1

BASE.mkdir(parents=True, exist_ok=True)
# Lancé sans console (pythonw) : stdout/stderr n'existent pas, certaines
# bibliothèques y écrivent quand même — on les redirige vers un fichier.
if sys.stdout is None or sys.stderr is None:
    _out = open(BASE / 'console.log', 'a', encoding='utf-8', buffering=1)
    sys.stdout = sys.stdout or _out
    sys.stderr = sys.stderr or _out

logging.basicConfig(
    filename=str(BASE / 'boost.log'),
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
)
log = logging.getLogger('boost')

# Bibliothèques CUDA livrées par les paquets pip « nvidia-* ».
for sp in site.getsitepackages():
    for b in glob.glob(os.path.join(sp, 'nvidia', '*', 'bin')):
        os.add_dll_directory(b)
        os.environ['PATH'] = b + os.pathsep + os.environ['PATH']

import httpx  # noqa: E402
import numpy as np  # noqa: E402
import sherpa_onnx  # noqa: E402
import uvicorn  # noqa: E402
from fastapi import FastAPI, Header, HTTPException  # noqa: E402
from fastapi.responses import Response, StreamingResponse  # noqa: E402
from pydantic import BaseModel  # noqa: E402


# ── Configuration (code d'appairage) ─────────────────────────────────────────

def load_config() -> dict:
    cfg = {}
    if CONFIG.exists():
        try:
            cfg = json.loads(CONFIG.read_text(encoding='utf-8'))
        except ValueError:
            cfg = {}
    changed = False
    if not cfg.get('token'):
        # 6 chiffres : facile à recopier sur le téléphone.
        cfg['token'] = f'{secrets.randbelow(10**6):06d}'
        changed = True
    if not cfg.get('port'):
        cfg['port'] = 47815
        changed = True
    if changed:
        CONFIG.write_text(json.dumps(cfg, indent=2), encoding='utf-8')
    return cfg


cfg = load_config()
app = FastAPI(title='TalkTome Boost', version=str(VERSION))


def check_token(token: str | None) -> None:
    if not token or not secrets.compare_digest(token, cfg['token']):
        raise HTTPException(status_code=401, detail='code incorrect')


# ── Voix ─────────────────────────────────────────────────────────────────────

class TtsRequest(BaseModel):
    folder: str = ''
    kind: str          # 'kokoro' | 'piper' | 'qwen3'
    modelFile: str = ''
    voice: str = ''    # qwen3 : identifiant de la voix (qwen_voices.json)
    sid: int = 0
    lang: str = ''
    gb: bool = False
    text: str
    speed: float = 1.0


_tts_engines: dict[str, sherpa_onnx.OfflineTts] = {}
_tts_lock = threading.Lock()
_provider = 'cuda'


def _engine(req: TtsRequest) -> sherpa_onnx.OfflineTts:
    global _provider
    # Le dossier doit être un modèle réellement installé (pas de chemin libre).
    installed = {p.name for p in TTS_DIR.iterdir() if p.is_dir()}
    if req.folder not in installed:
        raise HTTPException(status_code=404, detail=f'modèle absent : {req.folder}')
    key = f'{req.folder}|{req.lang}|{req.gb}'
    eng = _tts_engines.get(key)
    if eng is not None:
        return eng
    d = TTS_DIR / req.folder
    model_file = d / Path(req.modelFile).name
    if req.kind == 'kokoro':
        lex = 'lexicon-gb-en.txt' if req.gb else 'lexicon-us-en.txt'
        model = sherpa_onnx.OfflineTtsModelConfig(
            kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                model=str(model_file), voices=str(d / 'voices.bin'),
                tokens=str(d / 'tokens.txt'), data_dir=str(d / 'espeak-ng-data'),
                dict_dir=str(d / 'dict'),
                lexicon=f'{d / lex},{d / "lexicon-zh.txt"}', lang=req.lang),
            num_threads=4, provider=_provider)
    else:
        model = sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=str(model_file), tokens=str(d / 'tokens.txt'),
                data_dir=str(d / 'espeak-ng-data')),
            num_threads=4, provider=_provider)
    try:
        eng = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=model))
    except Exception:
        if _provider != 'cuda':
            raise
        log.exception('CUDA indisponible, passage au processeur')
        _provider = 'cpu'
        return _engine(req)
    # Garder au plus 4 moteurs en mémoire graphique.
    if len(_tts_engines) >= 4:
        _tts_engines.pop(next(iter(_tts_engines)))
    _tts_engines[key] = eng
    log.info('voix chargée : %s (%s)', key, _provider)
    return eng


def _wav(samples: np.ndarray, sr: int) -> bytes:
    pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype('<i2').tobytes()
    n = len(pcm)
    header = b''.join([
        b'RIFF', (36 + n).to_bytes(4, 'little'), b'WAVE', b'fmt ',
        (16).to_bytes(4, 'little'), (1).to_bytes(2, 'little'), (1).to_bytes(2, 'little'),
        sr.to_bytes(4, 'little'), (sr * 2).to_bytes(4, 'little'),
        (2).to_bytes(2, 'little'), (16).to_bytes(2, 'little'),
        b'data', n.to_bytes(4, 'little'),
    ])
    return header + pcm


@app.post('/tts')
def tts(req: TtsRequest, x_boost_token: str | None = Header(default=None)):
    check_token(x_boost_token)
    if req.kind == 'qwen3':
        return _qwen_tts(req)
    t = time.perf_counter()
    with _tts_lock:
        eng = _engine(req)
        audio = eng.generate(req.text, sid=req.sid, speed=req.speed)
    samples = np.asarray(audio.samples, dtype=np.float32)
    if samples.size == 0 or audio.sample_rate <= 0:
        raise HTTPException(status_code=422, detail='synthèse vide')
    log.info('tts %.1fs audio en %d ms', samples.size / audio.sample_rate,
             (time.perf_counter() - t) * 1000)
    return Response(content=_wav(samples, audio.sample_rate), media_type='audio/wav')


# ── Voix Qwen3-TTS (programme séparé, voir qwen_tts_worker.py) ──────────────

_qwen_proc: subprocess.Popen | None = None


def _qwen_http_ok() -> bool:
    try:
        return httpx.get(f'http://127.0.0.1:{QWEN_PORT}/health', timeout=0.5).status_code == 200
    except httpx.HTTPError:
        return False


def start_qwen() -> None:
    global _qwen_proc
    if _qwen_http_ok():
        log.info('Qwen3-TTS déjà actif, réutilisé')
        return
    if not QWEN_PY.exists() or not QWEN_WORKER.exists():
        log.info('Qwen3-TTS non installé (install_qwen_tts.ps1)')
        return
    _qwen_proc = subprocess.Popen(
        [str(QWEN_PY), str(QWEN_WORKER)], cwd=str(BASE),
        stdout=open(BASE / 'qwen_worker.log', 'ab'), stderr=subprocess.STDOUT,
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
    )
    log.info('Qwen3-TTS démarré (pid %s)', _qwen_proc.pid)


def _qwen_tts(req: TtsRequest) -> Response:
    # 422 (et non 503) quand Qwen3-TTS manque : le téléphone ne doit pas en
    # conclure que tout l'ordinateur est hors service.
    if not _qwen_http_ok():
        raise HTTPException(status_code=422, detail='Qwen3-TTS indisponible sur cet ordinateur')
    t = time.perf_counter()
    try:
        r = httpx.post(f'http://127.0.0.1:{QWEN_PORT}/tts',
                       json={'voice': req.voice, 'text': req.text, 'speed': req.speed},
                       timeout=180)
    except httpx.HTTPError as e:
        raise HTTPException(status_code=422, detail=f'Qwen3-TTS : {e}')
    if r.status_code != 200:
        raise HTTPException(status_code=422, detail=f'Qwen3-TTS : {r.text[:200]}')
    log.info('qwen3 %s en %d ms', req.voice, (time.perf_counter() - t) * 1000)
    return Response(content=r.content, media_type='audio/wav')


# ── IA locale (Qwen via llama.cpp) ───────────────────────────────────────────

_llama_proc: subprocess.Popen | None = None


def _llama_http_ok() -> bool:
    try:
        return httpx.get(f'http://127.0.0.1:{LLAMA_PORT}/health', timeout=0.5).status_code == 200
    except httpx.HTTPError:
        return False


def start_llama() -> None:
    global _llama_proc
    if _llama_http_ok():
        # Déjà lancé (instance précédente restée ouverte) : on le réutilise.
        log.info('llama-server déjà actif, réutilisé')
        return
    if not LLAMA_EXE.exists() or not LLM_MODEL.exists():
        log.warning('IA locale indisponible (llama-server ou modèle absent)')
        return
    _llama_proc = subprocess.Popen(
        [str(LLAMA_EXE), '-m', str(LLM_MODEL), '--host', '127.0.0.1',
         '--port', str(LLAMA_PORT), '-ngl', '99', '-c', '4096', '--parallel', '1'],
        cwd=str(LLAMA_EXE.parent),
        stdout=open(BASE / 'llama.log', 'ab'), stderr=subprocess.STDOUT,
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
    )
    log.info('llama-server démarré (pid %s)', _llama_proc.pid)


def llama_ready() -> bool:
    # On interroge le port plutôt que notre propre processus : un
    # llama-server lancé par une instance précédente compte aussi.
    return _llama_http_ok()


class LlmRequest(BaseModel):
    prompt: str
    n_predict: int = 200
    temperature: float = 0.2
    top_k: int = 20
    top_p: float = 0.8
    min_p: float = 0.0


@app.post('/llm')
async def llm(req: LlmRequest, x_boost_token: str | None = Header(default=None)):
    check_token(x_boost_token)
    if not llama_ready():
        raise HTTPException(status_code=503, detail='IA locale pas prête')
    body = {
        'prompt': req.prompt, 'n_predict': req.n_predict, 'stream': True,
        'temperature': req.temperature, 'top_k': req.top_k, 'top_p': req.top_p,
        'min_p': req.min_p, 'repeat_penalty': 1.0, 'cache_prompt': True,
        'stop': ['<|im_end|>'],
    }

    async def stream():
        # Le texte est renvoyé brut, morceau par morceau : le téléphone
        # l'affiche au fil de l'eau. Si le téléphone coupe, la génération
        # s'arrête aussi (fermeture de la connexion vers llama-server).
        async with httpx.AsyncClient(timeout=None) as client:
            async with client.stream('POST', f'http://127.0.0.1:{LLAMA_PORT}/completion',
                                     json=body) as r:
                async for line in r.aiter_lines():
                    if not line.startswith('data: '):
                        continue
                    try:
                        data = json.loads(line[6:])
                    except ValueError:
                        continue
                    piece = data.get('content', '')
                    if piece:
                        yield piece.encode('utf-8')
                    if data.get('stop'):
                        break

    return StreamingResponse(stream(), media_type='text/plain; charset=utf-8')


@app.get('/health')
def health(x_boost_token: str | None = Header(default=None)):
    check_token(x_boost_token)
    return {'ok': True, 'version': VERSION, 'tts': _provider, 'llm': llama_ready(),
            'qwen3': _qwen_http_ok()}


def main() -> None:
    log.info('TalkTome Boost démarre — port %s, code %s', cfg['port'], cfg['token'])
    if '--no-llm' not in sys.argv:  # --no-llm : voix seulement (tests)
        start_llama()
    start_qwen()
    try:
        uvicorn.run(app, host='0.0.0.0', port=int(cfg['port']), log_level='warning',
                    log_config=None)
    finally:
        for proc in (_llama_proc, _qwen_proc):
            if proc and proc.poll() is None:
                proc.terminate()


if __name__ == '__main__':
    main()
