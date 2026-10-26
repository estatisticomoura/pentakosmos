#!/usr/bin/env python3
"""Gera os efeitos sonoros do jogo (a musica e gerada por tools/musica/gerar_musica.py).

Uso: python3 tools/gerar_sons.py   (precisa de numpy)
Saida: assets/sfx/*.wav

Para usar sons proprios, basta colocar arquivos .ogg com o mesmo nome em
assets/sfx/ (ex.: buy.ogg) - eles tem prioridade sobre os .wav provisorios.
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 44100


def note(n):
    """Frequencia de uma nota MIDI."""
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def bell(freq, dur, decay=6.0, sr=SR):
    t = t_axis(dur, sr)
    env = np.exp(-decay * t) * np.minimum(1.0, t / 0.004)
    s = (np.sin(2 * np.pi * freq * t)
         + 0.45 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-3 * t)
         + 0.25 * np.sin(2 * np.pi * freq * 3.02 * t) * np.exp(-6 * t)
         + 0.10 * np.sin(2 * np.pi * freq * 4.17 * t) * np.exp(-9 * t))
    return s * env


def noise(dur, decay=40.0, sr=SR, seed=1):
    rng = np.random.default_rng(seed)
    t = t_axis(dur, sr)
    return rng.standard_normal(len(t)) * np.exp(-decay * t)


def lowpass(x, a=0.15):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def mix(parts, total):
    out = np.zeros(int(total * SR))
    for start, sig in parts:
        i = int(start * SR)
        j = min(len(out), i + len(sig))
        out[i:j] += sig[: j - i]
    return out


def save(path, x, sr=SR, peak=0.7):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    # fade-out curto para evitar estalos
    f = min(len(x), int(0.01 * sr))
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def sfx():
    d = os.path.join(ROOT, "assets", "sfx")
    save(f"{d}/click.wav", mix([(0, lowpass(noise(0.03, 120), 0.3) * 0.6), (0, bell(1500, 0.05, 60) * 0.5)], 0.06), peak=0.35)
    save(f"{d}/select.wav", mix([(0, bell(note(88), 0.25, 14)), (0.0, bell(note(95), 0.2, 18) * 0.4)], 0.26), peak=0.4)
    clink = lambda f, s: mix([(0, bell(f, 0.09, 45) * 0.7), (0, lowpass(noise(0.03, 150, seed=s), 0.6) * 0.3)], 0.09)
    # pegar fichas: dois toques suaves de ficha
    save(f"{d}/token.wav", mix([(0, clink(2350, 2)), (0.05, clink(2900, 3) * 0.6)], 0.16), peak=0.3)
    # ficha/carta chegando ao destino: um "tic" bem curto e discreto
    save(f"{d}/chip.wav", mix([(0, bell(3200, 0.05, 70) * 0.6), (0, lowpass(noise(0.02, 220, seed=9), 0.5) * 0.4)], 0.06), peak=0.22)
    # comprar: carta deslizando + um sino suave
    swish = lowpass(noise(0.22, 9, seed=5), 0.04) * np.sin(np.linspace(0, np.pi, int(0.22 * SR)))
    save(f"{d}/buy.wav", mix([(0, swish), (0.12, bell(note(79), 0.5, 6) * 0.45), (0.12, bell(note(84), 0.5, 7) * 0.2)], 0.65), peak=0.32)
    # reservar: carta deslizando + nota grave suave
    slide = lowpass(noise(0.18, 12, seed=6), 0.03) * np.sin(np.linspace(0, np.pi, int(0.18 * SR)))
    save(f"{d}/reserve.wav", mix([(0, slide), (0.1, bell(note(67), 0.4, 8) * 0.35)], 0.5), peak=0.28)
    fan = [(0.00, 72), (0.09, 76), (0.18, 79), (0.27, 84)]
    parts = [(s, bell(note(n), 1.0, 3.0)) for s, n in fan]
    parts += [(0.36, bell(note(n), 1.4, 2.0) * 0.6) for n in (72, 76, 79, 84, 88)]
    save(f"{d}/noble.wav", mix(parts, 1.9), peak=0.55)
    t = t_axis(0.12)
    sq = lambda f: np.tanh(3 * np.sin(2 * np.pi * f * t)) * np.exp(-12 * t)
    save(f"{d}/error.wav", mix([(0, lowpass(sq(220), 0.2)), (0.11, lowpass(sq(175), 0.2))], 0.25), peak=0.35)
    save(f"{d}/turn.wav", mix([(0, bell(note(76), 0.6, 4)), (0.0, bell(note(83), 0.6, 5) * 0.5)], 0.65), peak=0.35)
    win = [(i * 0.12, bell(note(n), 1.6, 2.2)) for i, n in enumerate((60, 64, 67, 72, 76, 79, 84))]
    win += [(0.9, bell(note(n), 2.0, 1.5) * 0.5) for n in (72, 76, 79, 84)]
    save(f"{d}/win.wav", mix(win, 3.0), peak=0.55)
    tt = t_axis(0.14)
    f = np.linspace(900, 400, len(tt))
    save(f"{d}/discard.wav", np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-14 * tt), peak=0.3)


if __name__ == "__main__":
    sfx()
    print("sons gerados")
