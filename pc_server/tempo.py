"""Changement de vitesse de la parole sans changer la hauteur de la voix.

WSOLA (Waveform Similarity Overlap-Add) : on recolle des fenêtres de
l'audio d'origine en choisissant, autour de chaque position attendue,
l'endroit qui prolonge le mieux la forme d'onde déjà produite. Pour la
parole, c'est bien plus propre qu'un vocodeur de phase (pas d'écho
« métallique »).
"""
from __future__ import annotations

import numpy as np


def change_tempo(samples: np.ndarray, sr: int, speed: float) -> np.ndarray:
    """Renvoie l'audio lu `speed` fois plus vite (2.0 = deux fois plus court)."""
    x = np.asarray(samples, dtype=np.float32).reshape(-1)
    if abs(speed - 1.0) < 0.01 or x.size == 0:
        return x
    win = int(sr * 0.030)          # fenêtre de 30 ms
    win += win % 2
    hop_out = win // 2             # recouvrement de 50 %
    hop_in = hop_out * speed       # avance dans l'audio d'origine
    tol = int(sr * 0.010)          # marge de recherche ± 10 ms
    if x.size < win * 2:
        return x

    window = np.hanning(win).astype(np.float32)
    pad = np.concatenate([np.zeros(tol, np.float32), x,
                          np.zeros(win + tol, np.float32)])
    n_frames = int((x.size - win) / hop_in) + 1
    out = np.zeros(n_frames * hop_out + win, np.float32)
    norm = np.zeros_like(out)

    prev = 0  # position (dans x) de la fenêtre précédemment collée
    for k in range(n_frames):
        target = int(round(k * hop_in))
        if k == 0:
            best = 0
        else:
            # Prolongement naturel de la fenêtre précédente…
            natural = pad[prev + hop_out + tol: prev + hop_out + tol + win]
            # … comparé aux candidats autour de la position attendue.
            lo = target
            seg = pad[lo: lo + win + 2 * tol]
            if seg.size < win + 2 * tol:
                break
            corr = np.correlate(seg, natural, mode='valid')
            best = target - tol + int(np.argmax(corr))
            best = min(max(best, 0), x.size - 1)
        frame = pad[best + tol: best + tol + win]
        if frame.size < win:
            break
        o = k * hop_out
        out[o: o + win] += frame * window
        norm[o: o + win] += window
        prev = best

    used = n_frames * hop_out + win
    out, norm = out[:used], norm[:used]
    nz = norm > 1e-3
    out[nz] /= norm[nz]
    expected = int(round(x.size / speed))
    return out[:expected]
