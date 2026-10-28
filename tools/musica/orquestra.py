#!/usr/bin/env python3
"""Orquestra amostrada (VSCO 2 Community Edition, CC0) para as pecas orquestrais.
Uso: python3 orch.py <id> [...]"""
import glob, os, random, re, subprocess, sys, wave
import os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, "tools", "musica", "cache")
import mido
import numpy as np
import soundfile as sf
from scipy.signal import oaconvolve, resample_poly

SR = 44100
VS = os.path.join(CACHE, 'vsco') + '/'
SRC = os.path.join(CACHE, 'mutopia', 'ftp') + '/'
OUT = os.path.join(ROOT, 'assets', 'music') + '/'
PC = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
DYN = {'pp': 1, 'p': 2, 'mp': 3, 'mf': 4, 'f': 5, 'ff': 6}

# instrumento: pasta, sustentado?, ataque (s), soltura (s), ganho
INSTR = {
    'vln': ('Strings/Violin Section/susVib', True, 0.06, 0.35, 1.0),
    'vln_spic': ('Strings/Violin Section/Spic', False, 0.0, 0.12, 1.0),
    'vln_pizz': ('Strings/Violin Section/Pizz', False, 0.0, 0.15, 1.0),
    'vla': ('Strings/Viola Section/susvib', True, 0.06, 0.35, 1.0),
    'vla_spic': ('Strings/Viola Section/spic', False, 0.0, 0.12, 1.0),
    'vla_pizz': ('Strings/Viola Section/pizz', False, 0.0, 0.15, 1.0),
    'vc': ('Strings/Cello Section/susvib', True, 0.06, 0.4, 1.0),
    'vc_spic': ('Strings/Cello Section/spic', False, 0.0, 0.12, 1.0),
    'vc_pizz': ('Strings/Cello Section/pizzT', False, 0.0, 0.2, 1.0),
    'cb': ('Strings/Solo Contrabass/SusVib', True, 0.06, 0.4, 1.3),
    'cb_spic': ('Strings/Solo Contrabass/Spic', False, 0.0, 0.12, 1.3),
    'cb_pizz': ('Strings/Solo Contrabass/Pizz', False, 0.0, 0.25, 1.3),
    'solo': ('Strings/Solo Violin/Arco Vib', True, 0.04, 0.3, 1.0),
    'solo_spic': ('Strings/Solo Violin/spic', False, 0.0, 0.1, 1.0),
    'hn': ('Brass/F Horn/sus', True, 0.04, 0.3, 0.9),
    'tpt': ('Brass/Trumpet/sus', True, 0.02, 0.25, 0.85),
    'tbn': ('Brass/Tenor Trombone/sus', True, 0.03, 0.3, 0.85),
    'tuba': ('Brass/Tuba/sus', True, 0.03, 0.3, 0.9),
    'fl': ('Woodwinds/Flute/susvib', True, 0.04, 0.25, 0.8),
    'ob': ('Woodwinds/Oboe/Vib', True, 0.03, 0.25, 0.8),
    'cl': ('Woodwinds/Clarinet/susLong', True, 0.03, 0.25, 0.8),
    'bn': ('Woodwinds/Bassoon/sus', True, 0.03, 0.25, 0.9),
    'bn_stac': ('Woodwinds/Bassoon/stac', False, 0.0, 0.12, 0.9),
    'org': ('Keys/Organ/Loud', True, 0.03, 0.45, 0.7),
}
_banks = {}


def bank(name):
    """Le as amostras de um instrumento: {altura: {camada: [arquivos]}}."""
    if name in _banks:
        return _banks[name]
    folder = VS + INSTR[name][0]
    b = {}
    for f in glob.glob(folder + '/*.wav'):
        base = os.path.basename(f)
        if name == 'org':
            m = re.search(r'Rode_Man3Open_(\d+)', base)
            if not m:
                continue
            note, layer = 35 + int(m.group(1)), 1
        else:
            m = re.search(r'_([A-G]#?)(-?\d)(?=[_.])', base)
            if not m:
                continue
            note = 12 * (int(m.group(2)) + 2) + PC[m.group(1)]
            d = re.search(r'_v(\d)', base)
            d2 = re.search(r'_(pp|p|mp|mf|f|ff)(?=[_.])', base)
            layer = int(d.group(1)) if d else (DYN[d2.group(1)] if d2 else 1)
        b.setdefault(note, {}).setdefault(layer, []).append(f)
    _banks[name] = b
    return b


_audio = {}


def load(path):
    if path not in _audio:
        x, sr = sf.read(path, dtype='float32', always_2d=True)
        if x.shape[1] == 1:
            x = np.repeat(x, 2, axis=1)
        x = x[:, :2]
        if sr != SR:
            x = resample_poly(x, SR, sr, axis=0).astype(np.float32)
        # corta o silencio inicial
        env = np.abs(x).max(axis=1)
        thr = env.max() * 0.02
        start = max(0, int(np.argmax(env > thr)) - 64)
        _audio[path] = x[start:]
    return _audio[path]


def render_note(name, note, vel, dur, rng):
    folder, sustained, att, rel, gain = INSTR[name]
    b = bank(name)
    root = min(b, key=lambda r: (abs(r - note), r < note))
    layers = sorted(b[root])
    layer = layers[min(len(layers) - 1, int(vel / 128 * len(layers)))]
    s = load(rng.choice(b[root][layer]))
    ratio = 2 ** ((note - root) / 12.0)
    want = int((dur + rel) * SR) if sustained else int((min(dur, 1.5) + rel) * SR)
    avail = int((len(s) - 2) / ratio)
    if sustained and want > avail:
        # nota mais longa que a amostra: repete um trecho do meio com fusao suave
        a, z = int(len(s) * 0.35), int(len(s) * 0.8)
        seg = s[a:z]
        xf = min(int(0.08 * SR), len(seg) // 3)
        loop = seg.copy()
        body = [s[:z]]
        total = z
        while total * 1 / ratio < want + SR:
            prev = body[-1]
            fade = np.linspace(0, 1, xf)[:, None]
            prev[-xf:] = prev[-xf:] * (1 - fade) + loop[:xf] * fade
            body.append(loop[xf:].copy())
            total += len(loop) - xf
        s = np.concatenate(body)
        avail = int((len(s) - 2) / ratio)
    n = max(1, min(want, avail))
    idx = np.arange(n) * ratio
    i0 = idx.astype(np.int64)
    fr = (idx - i0)[:, None]
    out = s[i0] * (1 - fr) + s[i0 + 1] * fr
    if att > 0:
        k = min(n, int(att * SR))
        out[:k] *= np.linspace(0, 1, k)[:, None]
    k = min(n, int(rel * SR))
    end = min(n, int(dur * SR) + k) if sustained else n
    out = out[:end]
    if k > 0 and len(out) > k:
        out[-k:] *= np.linspace(1, 0, k)[:, None] ** 2
    return out * gain * (0.4 + 0.6 * vel / 127.0)


def read_notes(path, stretch=1.0):
    m = mido.MidiFile(path)
    t = 0.0
    on, notes = {}, []
    for msg in m:
        t += msg.time * stretch
        if msg.type == 'note_on' and msg.velocity > 0:
            on.setdefault((msg.channel, msg.note), []).append((t, msg.velocity))
        elif msg.type in ('note_off', 'note_on'):
            lst = on.get((msg.channel, msg.note))
            if lst:
                st, v = lst.pop(0)
                notes.append(dict(t=st, e=t, n=msg.note, v=v, ch=msg.channel))
    return notes, t


def groups_by_onset(notes, ch):
    g = {}
    for x in notes:
        if x['ch'] == ch:
            g.setdefault(round(x['t'], 3), []).append(x)
    return g


# ---------------------------------------------------------------- orquestracoes
def arr_air(notes, total):
    out = []
    for x in notes:
        d = x['e'] - x['t']
        if x['ch'] == 0:
            out.append(('vln', x['n'], min(127, x['v'] + 12), x['t'], d))
        elif x['ch'] == 1:
            out.append(('vln', x['n'], x['v'] - 8, x['t'], d))
        elif x['ch'] == 2:
            out.append(('vla', x['n'], x['v'] - 6, x['t'], d))
        else:
            out.append(('vc', x['n'], x['v'], x['t'], d))
            out.append(('cb', x['n'] - 12, x['v'] - 10, x['t'], d))
    return out


def arr_vivaldi(notes, total):
    out = []
    for x in notes:
        d = x['e'] - x['t']
        short = d < 0.2
        if x['ch'] == 0:
            out.append(('solo_spic' if short else 'solo', x['n'], min(127, x['v'] + 10), x['t'], d))
        elif x['ch'] in (1, 2):
            out.append(('vln_spic' if short else 'vln', x['n'], x['v'] - 6, x['t'], d))
        elif x['ch'] == 3:
            out.append(('vla_spic' if short else 'vla', x['n'], x['v'] - 6, x['t'], d))
        else:
            out.append(('vc_spic' if short else 'vc', x['n'], x['v'], x['t'], d))
            out.append(('cb_spic' if short else 'cb', x['n'] - 12, x['v'] - 12, x['t'], d))
    return out


def arr_toccata(notes, total):
    out = []
    for x in notes:
        d = x['e'] - x['t']
        out.append(('org', x['n'], x['v'], x['t'], d))
        if x['ch'] == 2:  # pedal: dobra uma oitava abaixo (registro de 16 pes)
            out.append(('org', x['n'] - 12, x['v'] - 15, x['t'], d))
    return out


def arr_rejouissance(notes, total, rep):
    out = []
    for x in notes:
        d = x['e'] - x['t']
        if x['ch'] == 0:
            out.append(('tpt', x['n'], min(127, x['v'] + 8), x['t'], d))
            if rep == 1:
                out.append(('ob', x['n'], x['v'] - 15, x['t'], d))
        elif x['ch'] == 1:
            out.append(('vln_spic' if d < 0.25 else 'vln', x['n'], x['v'] - 4, x['t'], d))
            if rep == 1:
                out.append(('hn', x['n'] - 12, x['v'] - 20, x['t'], d))
        else:
            out.append(('vc_spic' if d < 0.25 else 'vc', x['n'], x['v'], x['t'], d))
            out.append(('cb_spic' if d < 0.25 else 'cb', x['n'] - 12, x['v'] - 10, x['t'], d))
            out.append(('bn', x['n'], x['v'] - 20, x['t'], d))
    return out


def arr_thaxted(notes, total, rep):
    out = []
    for x in notes:
        d = x['e'] - x['t']
        if x['ch'] == 0:
            out.append(('hn', x['n'], min(127, x['v'] + 10), x['t'], d))
            out.append(('vln', x['n'] + 12 if rep == 1 else x['n'], x['v'] - (0 if rep == 1 else 12), x['t'], d))
            if rep == 1:
                out.append(('tpt', x['n'], x['v'] - 20, x['t'], d))
        elif x['ch'] == 1:
            out.append(('vla', x['n'], x['v'] - 10, x['t'], d))
            out.append(('cl', x['n'], x['v'] - 22, x['t'], d))
        else:
            out.append(('vc', x['n'], x['v'] - 4, x['t'], d))
            out.append(('cb', x['n'] - 12, x['v'] - 14, x['t'], d))
            if rep == 1:
                out.append(('tbn', x['n'], x['v'] - 22, x['t'], d))
    return out


def arr_reduction(notes, total, style):
    """Orquestra uma reducao para piano: melodia no topo da mao direita,
    vozes internas e baixo na mao esquerda; a intensidade decide a forca do naipe."""
    out = []
    for ch in (0, 1):
        for t, g in groups_by_onset(notes, ch).items():
            g.sort(key=lambda x: x['n'])
            for i, x in enumerate(g):
                d = x['e'] - x['t']
                v = x['v']
                loud = v >= 90
                soft = v < 65
                if style == 'grieg':
                    short = d < 0.35
                    if ch == 0 and i == len(g) - 1:
                        if soft:
                            out.append(('bn_stac' if short else 'bn', x['n'] - 12, v + 10, t, d))
                            out.append(('vc_pizz', x['n'] - 12, v, t, d))
                        else:
                            out.append(('vln_spic' if short else 'vln', x['n'], v, t, d))
                            out.append(('vla_spic' if short else 'vla', x['n'] - 12, v - 10, t, d))
                            if loud:
                                out.append(('fl', x['n'] + 12, v - 25, t, d))
                                out.append(('tpt', x['n'], v - 20, t, d))
                    elif ch == 0:
                        out.append(('vla_pizz' if soft else ('vla_spic' if short else 'vla'), x['n'], v - 12, t, d))
                    else:
                        if i == 0:
                            out.append(('cb_pizz' if soft else 'cb_spic', x['n'] - (12 if x['n'] > 40 else 0), v, t, d))
                            out.append(('vc_pizz' if soft else 'vc_spic', x['n'], v - 6, t, d))
                            if loud:
                                out.append(('tuba', x['n'] - 12 if x['n'] > 40 else x['n'], v - 15, t, d))
                        else:
                            out.append(('hn' if not soft else 'cl', x['n'], v - 18, t, d))
                else:  # valsa
                    if ch == 0 and i == len(g) - 1:
                        out.append(('vln', x['n'], v + 8, t, d))
                        out.append(('fl', x['n'] + 12, v - 25, t, d))
                    elif ch == 0:
                        out.append(('vla', x['n'], v - 14, t, d))
                    else:
                        if i == 0 and len(g) == 1 or i == 0 and x['n'] < 50:
                            out.append(('cb_pizz', x['n'] - (12 if x['n'] > 40 else 0), v, t, d))
                            out.append(('vc_pizz', x['n'], v - 6, t, d))
                        else:
                            out.append(('hn', x['n'], v - 22, t, d))
                            out.append(('vla_pizz', x['n'] + 12, v - 18, t, d))
    return out


PIECES = {
    'bach_air': dict(midi=['BachJS/BWV1068/bach-air/bach-air-lys/bach-air-score.midi'], arr=arr_air, stretch=1.05, room='church',
                     segments=[(0, 40), (40, 48), (0, 40), (48, 56), (56, 152), (56, 152)]),
    'vivaldi_summer': dict(midi=['VivaldiA/O8/summer/summer-lys/summer-score.midi',
                                 'VivaldiA/O8/summer/summer-lys/summer-score-1.midi',
                                 'VivaldiA/O8/summer/summer-lys/summer-score-2.midi'], arr=arr_vivaldi, stretch=1.0, room='hall'),
    'bach_toccata_fugue': dict(midi=['BachJS/BWV565/ToccataFugue/ToccataFugue.midi'], arr=arr_toccata, stretch=1.0, room='church'),
    'handel_rejouissance': dict(midi=['HandelGF/BWV351/LaRej/LaRej.midi'], arr=arr_rejouissance, stretch=1.0, room='hall',
                                repeat=2),
    'holst_thaxted': dict(midi=['HolstGT/Thaxted/Thaxted.midi'], arr=arr_thaxted, stretch=1.25, room='hall', repeat=2),
    'grieg_mountain_king': dict(midi=['GriegE/O46/Dans_l_antre_du_roi_de_la_montagne/Dans_l_antre_du_roi_de_la_montagne.midi'],
                                arr=lambda n, t: arr_reduction(n, t, 'grieg'), stretch=1.15, room='hall', accel=1.55),
}


def render(pid):
    piece = PIECES[pid]
    rng = random.Random(pid)
    nrng = np.random.default_rng(abs(hash(pid)) % 2 ** 32)
    events = []
    off = 0.0
    for rep in range(piece.get('repeat', 1)):
        for k, mid in enumerate(piece['midi']):
            notes, end = read_notes(SRC + mid, piece['stretch'])
            if piece.get('segments'):
                # repeticoes escritas so como marcas na partitura: monta a ordem de execucao
                st = piece['stretch']
                seq, pos = [], 0.0
                for a, b in piece['segments']:
                    a, b = a * st, b * st
                    for x in notes:
                        if a - 1e-3 <= x['t'] < b - 1e-3:
                            seq.append(dict(x, t=x['t'] - a + pos, e=min(x['e'], b + 0.5) - a + pos))
                    pos += b - a
                notes, end = seq, pos
            fn = piece['arr']
            ev = fn(notes, end, rep) if fn in (arr_rejouissance, arr_thaxted) else fn(notes, end)
            events += [(i, n, v, t + off, d) for i, n, v, t, d in ev]
            off += end + (2.0 if len(piece['midi']) > 1 else 0.9)
    if piece.get('accel'):
        # acelerando continuo (Grieg): o andamento cresce ate 'accel' vezes no final
        a = piece['accel']
        grid = np.linspace(0, off, 2000)
        speed = 1 + (a - 1) * (grid / off) ** 2
        real = np.concatenate([[0], np.cumsum(np.diff(grid) / speed[1:])])
        warp = lambda x: float(np.interp(x, grid, real))
        events = [(i, n, v, warp(t), warp(t + d) - warp(t)) for i, n, v, t, d in events]
        off = warp(off)
    total = int((off + 5) * SR)
    mix = np.zeros((total, 2), np.float32)
    for inst, note, vel, t, d in events:
        vel = int(np.clip(vel + rng.uniform(-4, 4), 10, 127))
        t += rng.uniform(0, 0.015)
        a = render_note(inst, note, vel, max(0.05, d), rng)
        i = int(t * SR)
        j = min(total, i + len(a))
        if j > i:
            mix[i:j] += a[:j - i]
    dry = mix.astype(np.float64)
    rt = {'hall': 2.3, 'church': 3.3}[piece['room']]
    n = int(rt * SR)
    tt = np.arange(n) / SR
    ir = np.stack([np.convolve(nrng.standard_normal(n), np.ones(30) / 30, mode='same') * np.exp(-6.9 * tt / rt)
                   for _ in range(2)], axis=1)
    ir[:int(0.02 * SR)] = 0
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    wet = np.stack([oaconvolve(dry[:, c], ir[:, c])[:len(dry)] for c in range(2)], axis=1)
    out = dry * 0.8 + wet * (0.32 if piece['room'] == 'hall' else 0.42)
    rms = np.sqrt((out ** 2).mean()) + 1e-9
    out *= 10 ** (-20 / 20) / rms
    pk = np.abs(out).max()
    if pk > 0.89:
        out *= 0.89 / pk
    f = int(2.5 * SR)
    out[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
    os.makedirs(OUT, exist_ok=True)
    wav = OUT + pid + '.wav'
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(out, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', OUT + pid + '.ogg'],
                   check=True)
    os.remove(wav)
    print('%-24s %5.0f s  %d eventos' % (pid, len(out) / SR, len(events)), flush=True)


if __name__ == '__main__':
    for pid in sys.argv[1:] or list(PIECES):
        render(pid)
