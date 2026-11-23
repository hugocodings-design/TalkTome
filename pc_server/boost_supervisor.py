"""Garde TalkTome Boost en marche : le relance s'il s'arrête.

Lancé au démarrage de Windows (raccourci « TalkTome Boost »). Si le serveur
plante ou est fermé, il est relancé 5 secondes plus tard. Si un serveur
répond déjà sur le port (lancé à la main), on ne fait rien et on revérifie.
"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

BASE = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'TalkTomeBoost'
SERVER = BASE / 'talktome_boost.py'
LOG = BASE / 'supervisor.log'


def port() -> int:
    try:
        return int(json.loads((BASE / 'config.json').read_text(encoding='utf-8'))['port'])
    except (OSError, ValueError, KeyError):
        return 47815


def listening(p: int) -> bool:
    try:
        with socket.create_connection(('127.0.0.1', p), timeout=1):
            return True
    except OSError:
        return False


def log(msg: str) -> None:
    with open(LOG, 'a', encoding='utf-8') as f:
        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")


def main() -> None:
    log('superviseur démarré')
    while True:
        if listening(port()):
            time.sleep(20)
            continue
        log('serveur arrêté : relance')
        flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
        code = subprocess.call([sys.executable, str(SERVER)], cwd=str(BASE),
                               creationflags=flags)
        log(f'serveur terminé (code {code})')
        time.sleep(5)


if __name__ == '__main__':
    main()
