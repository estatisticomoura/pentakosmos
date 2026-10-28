#!/usr/bin/env python3
"""O Danubio Azul ao piano: tempo de valsa vienense (2o tempo adiantado, 3o atrasado) e fraseado.
Chamado por gerar_musica.py; sozinho: python3 tools/musica/danubio.py [piano|orq]"""
import os, random, subprocess, sys, wave
import numpy as np
from scipy.signal import oaconvolve

sys.path.insert(0, os.path.dirname(__file__))
import orquestra as orch
import piano

SR = 44100
MIDI = orch.SRC + 'StraussJJ/O314/blue_danube/blue_danube.midi'
OUT = orch.OUT
BPM = 142.0


def load_beats():
    """Notas em tempos de batida (a anacruse e a batida 0; compassos comecam em 1, 4, 7...)."""
    notes, end = orch.read_notes(MIDI, 1.0)
    beat = 60.0 / 150.0
    out = [dict(b=x['t'] / beat, d=(x['e'] - x['t']) / beat, n=x['n'], v=x['v'], ch=x['ch']) for x in notes]
    return out, end / beat


def make_warp(total_beats, final):
    """Batida -> segundos. Dentro do compasso: o 2o tempo vem um pouco antes e o 3o um pouco
    depois (o 'balanco' vienense). Entre frases de 8 compassos: leve impulso no meio e
    respiracao no fim. Na ultima passagem, ritardando final."""
    knots = np.array([0.0, 1.0, 2.0, 3.0])
    moved = np.array([0.0, 0.86, 1.97, 3.0])
    grid = np.linspace(0, total_beats, int(total_beats * 24) + 1)
    # posicao dentro do compasso (compassos comecam na batida 1)
    rel = grid - 1.0
    m = np.floor(rel / 3.0)
    u = rel - 3.0 * m
    swing = np.interp(u, knots, moved) + 3.0 * m + 1.0
    swing[grid < 1.0] = grid[grid < 1.0] * 1.12      # anacruse um pouco mais calma
    # andamento por frase: 8 compassos = 24 batidas
    ph = ((grid - 1.0) % 24.0) / 24.0
    speed = 1.0 + 0.05 * np.sin(np.pi * ph) - 0.10 * np.clip((ph - 0.85) / 0.15, 0, 1) ** 2
    speed = np.where(grid < 1.0, 0.92, speed)
    if final:
        last = np.clip((grid - (total_beats - 12.0)) / 12.0, 0, 1)
        speed *= 1.0 - 0.32 * last ** 1.5
    dt = np.diff(swing) / speed[1:]
    secs = np.concatenate([[0.0], np.cumsum(dt)]) * 60.0 / BPM
    return lambda b: float(np.interp(b, grid, secs))


def phrase_dyn(b):
    """Arco dinamico de cada frase de 4 compassos: cresce ate o 3o compasso e relaxa."""
    ph = ((b - 1.0) % 12.0) / 12.0
    return 0.88 + 0.18 * np.sin(np.pi * min(1.0, ph * 1.15))


def arrangement(notes, total, pas, kind):
    """Lista (instrumento, nota, vel, batida_inicio, batida_dur)."""
    ev = []
    by_onset = {}
    for x in notes:
        by_onset.setdefault((round(x['b'], 3), x['ch']), []).append(x)
    mel = sorted([g for (b, ch), g in by_onset.items() if ch == 0], key=lambda g: g[0]['b'])
    # melodia legato: cada nota dura ate a proxima
    mel_onsets = [g[0]['b'] for g in mel]
    for k, g in enumerate(mel):
        g.sort(key=lambda x: x['n'])
        b = g[0]['b']
        nxt = mel_onsets[k + 1] if k + 1 < len(mel_onsets) else total
        dur = max(g[-1]['d'], (nxt - b) * 1.02)
        dyn = phrase_dyn(b)
        top = g[-1]
        contour = (top['n'] - 70) * 0.9          # notas mais altas, um pouco mais fortes
        v = (74 if pas == 0 else 92) * dyn + contour
        if kind == 'piano':
            ev.append(('pno', top['n'], v + 6, b, dur))
            for x in g[:-1]:
                ev.append(('pno', x['n'], v - 16, b, dur))
            continue
        if pas == 0:
            # 1a passagem, dolce: tema nas trompas e violoncelos (como no original), tercas no clarinete
            hn = top['n'] - 12 if top['n'] > 72 else top['n']
            ev.append(('hn', hn, v - 4, b, dur))
            ev.append(('vc', hn, v - 10, b, dur))
            for x in g[:-1]:
                ev.append(('cl', x['n'] - (12 if x['n'] > 76 else 0), v - 22, b, dur))
        else:
            # 2a passagem, brilhante: violinos com a flauta uma oitava acima, tercas nos segundos violinos
            ev.append(('vln', top['n'], v + 4, b, dur))
            ev.append(('fl', top['n'] + 12, v - 26, b, dur))
            for x in g[:-1]:
                ev.append(('vln', x['n'], v - 18, b, dur))
    # acompanhamento: baixo no 1o tempo, acordes curtos e leves no 2o e 3o
    for (b, ch), g in by_onset.items():
        if ch != 1:
            continue
        g.sort(key=lambda x: x['n'])
        u = (b - 1.0) % 3.0
        dyn = phrase_dyn(b)
        if abs(u) < 0.05 or abs(u - 3.0) < 0.05:
            base = g[0]['n']
            v = (66 if pas == 0 else 80) * dyn
            if kind == 'piano':
                ev.append(('pno', base - 12 if base > 45 else base, v, b, 2.6))
                continue
            ev.append(('cb', base - 12 if base > 40 else base, v, b, 1.1))
            ev.append(('bn', base, v - 22, b, 1.0))
            if pas == 1:
                # trompas sustentam a harmonia (nota longa, nada de "um-pa-pa")
                ev.append(('hn', base + 12, v - 30, b, 2.9))
        else:
            v = (50 if pas == 0 else 60) * dyn
            for x in g:
                if kind == 'piano':
                    ev.append(('pno', x['n'], v - 4, b, 0.7))
                else:
                    ev.append(('vla', x['n'], v - 6, b, 0.55))
                    if pas == 1:
                        ev.append(('vln', x['n'] + 12, v - 16, b, 0.5))
    return ev


def render(kind):
    notes, total = load_beats()
    rng = random.Random('danube' + kind)
    nrng = np.random.default_rng(7 if kind == 'piano' else 11)
    events = []
    off = 0.0
    for pas in range(2):
        final = pas == 1
        warp = make_warp(total + (3.0 if final else 0.0), final)
        ev = arrangement(notes, total, pas, kind)
        if final:
            # fermata no acorde final
            last = max(e[3] for e in ev)
            ev = [(i, n, v, b, d + 3.0 if b >= last - 0.01 else d) for i, n, v, b, d in ev]
        for inst, n, v, b, d in ev:
            t0 = warp(b)
            t1 = warp(b + d)
            events.append((inst, n, v, off + t0, t1 - t0))
        off += warp(total) + 0.35
    total_s = off + 6.0
    mix = np.zeros((int(total_s * SR), 2), np.float32)
    for inst, n, v, t, d in events:
        v = int(np.clip(v + rng.uniform(-3, 3), 12, 124))
        t += rng.uniform(0.0, 0.012)
        if inst == 'pno':
            a = piano.note_audio(n, v, int((d + 0.25) * SR))
            if len(a) == 0:
                continue
            rel = min(len(a), int(0.2 * SR))
            a[-rel:] *= np.linspace(1, 0, rel)[:, None] ** 2
            a = a * (0.35 + 0.65 * v / 127.0)
        else:
            a = orch.render_note(inst, n, v, max(0.05, d), rng)
        i = int(t * SR)
        j = min(len(mix), i + len(a))
        if j > i:
            mix[i:j] += a[:j - i]
    dry = mix.astype(np.float64)
    rt = 2.4
    n = int(rt * SR)
    tt = np.arange(n) / SR
    ir = np.stack([np.convolve(nrng.standard_normal(n), np.ones(30) / 30, mode='same') * np.exp(-6.9 * tt / rt)
                   for _ in range(2)], axis=1)
    ir[:int(0.02 * SR)] = 0
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    wet = np.stack([oaconvolve(dry[:, c], ir[:, c])[:len(dry)] for c in range(2)], axis=1)
    out = dry * 0.8 + wet * (0.30 if kind == 'piano' else 0.36)
    rms = np.sqrt((out ** 2).mean()) + 1e-9
    out *= 10 ** (-20 / 20) / rms
    pk = np.abs(out).max()
    if pk > 0.89:
        out *= 0.89 / pk
    f = int(3.0 * SR)
    out[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
    os.makedirs(OUT, exist_ok=True)
    name = 'strauss_blue_danube' if kind == 'piano' else 'strauss_blue_danube_' + kind
    wav = OUT + name + '.wav'
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(out, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5', OUT + name + '.ogg'],
                   check=True)
    os.remove(wav)
    print(name, round(len(out) / SR), 's', len(events), 'notas')


if __name__ == '__main__':
    for k in sys.argv[1:] or ['piano']:
        render(k)
