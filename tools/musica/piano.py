#!/usr/bin/env python3
"""Piano amostrado (Salamander Grand Piano V3, 16 camadas de velocidade) com pedal,
enfase na melodia, rubato e reverberacao. Uso: python3 piano.py <id> [...]"""
import os, random, subprocess, sys, wave
import os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, "tools", "musica", "cache")
import mido
import numpy as np
from scipy.signal import oaconvolve
# qualidade do Ogg Vorbis (0 a 10); padrao 2 (~70 kbps), escolhido em teste de escuta.
# Para mudar todas as musicas: PENTAKOSMOS_QUALIDADE=1 python3 tools/musica/gerar_musica.py
QUALIDADE = os.environ.get("PENTAKOSMOS_QUALIDADE", "2")

SR = 44100
SAMPLES = os.path.join(CACHE, 'salamander') + '/'
SRC = os.path.join(CACHE, 'mutopia', 'ftp') + '/'
OUT = os.path.join(ROOT, 'assets', 'music') + '/'
NAMES = {'C': 0, 'D#': 3, 'F#': 6, 'A': 9}
ROOTS = sorted({(o + 1) * 12 + v for o in range(-1, 9) for k, v in NAMES.items()
                if os.path.exists(SAMPLES + '%s%dv8.ogg' % (k, o))})
_cache = {}


def sample(root, layer):
    key = (root, layer)
    if key not in _cache:
        octave = root // 12 - 1
        name = [k for k, v in NAMES.items() if v == root % 12][0]
        path = SAMPLES + '%s%dv%d.ogg' % (name, octave, layer)
        raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', path, '-t', '9', '-ar', str(SR), '-ac', '2',
                              '-f', 'f32le', '-'], capture_output=True).stdout
        _cache[key] = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)
    return _cache[key]


def note_audio(note, vel, length):
    """Audio de uma nota: escolhe a amostra mais proxima e reamostra a altura."""
    root = min(ROOTS, key=lambda r: abs(r - note))
    layer = int(np.clip(round(1 + (vel / 127.0) ** 1.15 * 15), 1, 16))
    s = sample(root, layer)
    ratio = 2 ** ((note - root) / 12.0)
    n = int(min(length, (len(s) - 2) / ratio))
    if n <= 0:
        return np.zeros((0, 2), np.float32)
    idx = np.arange(n) * ratio
    i0 = idx.astype(np.int64)
    fr = (idx - i0)[:, None]
    a = s[i0] * (1 - fr) + s[i0 + 1] * fr
    return a.astype(np.float32)


PIECES = {
    "gymnopedie_1": dict(midi="SatieE/gymnopedie_1/gymnopedie_1.midi", stretch=1.0, pedal="bass", melody=0),
    "gymnopedie_2": dict(midi="SatieE/gymnopedie_2/gymnopedie_2.midi", stretch=1.1, pedal="bass", melody=0),
    "gymnopedie_3": dict(midi="SatieE/gymnopedie_3/gymnopedie_3.midi", stretch=1.1, pedal="bass", melody=0),
    "gnossienne_1": dict(midi="SatieE/Gnossienne/no_1/no_1.midi", stretch=1.0, pedal="bass", melody=0),
    "gnossienne_2": dict(midi="SatieE/Gnossienne/no_2/no_2.midi", stretch=1.0, pedal="bass", melody=0),
    "gnossienne_3": dict(midi="SatieE/Gnossienne/no_3/no_3.midi", stretch=0.95, pedal="bass", melody=0),
    "bach_goldberg_aria": dict(midi="BachJS/BWV988/bwv-988-aria/bwv-988-aria.midi", stretch=1.3, pedal="light", melody=0),
    "bach_prelude_c": dict(midi="BachJS/BWV846/wtk1-prelude1/wtk1-prelude1.midi", stretch=1.1, pedal="bass", melody=None),
    "chopin_nocturne_op9_2": dict(midi="ChopinFF/O9/chopin_nocturne_op9_n2/chopin_nocturne_op9_n2.midi", stretch=1.15,
                                  pedal="bass", melody=0),
    "debussy_clair_de_lune": dict(midi="DebussyC/L75/debussy_Ste_Bergamesq_Clair/debussy_Ste_Bergamesq_Clair.midi",
                                  stretch=1.05, pedal="bass", melody=0),
    "debussy_arabesque_1": dict(midi="DebussyC/L66/debussy_Arabesque_1/debussy_Arabesque_1.midi", stretch=1.05,
                                pedal="bass", melody=0),
    "mussorgsky_bald_mountain": dict(midi="MussorgskyM/nobm/nobm.midi", stretch=1.0, pedal="light", melody=None),
}


def read_notes(path, stretch):
    """Notas (inicio, fim, altura, velocidade, canal) e pedais do arquivo."""
    m = mido.MidiFile(path)
    t = 0.0
    on = {}
    notes, pedal = [], []
    for msg in m:
        t += msg.time * stretch
        if msg.type == 'note_on' and msg.velocity > 0:
            on.setdefault((msg.channel, msg.note), []).append((t, msg.velocity))
        elif msg.type in ('note_off', 'note_on'):
            lst = on.get((msg.channel, msg.note))
            if lst:
                st, v = lst.pop(0)
                notes.append([st, t, msg.note, v, msg.channel])
        elif msg.type == 'control_change' and msg.control == 64:
            pedal.append((t, msg.value >= 64))
    return notes, pedal, t


def tempo_map(total, rng, final_rit=True):
    """Rubato suave: o tempo flui um pouco mais devagar e mais depressa; ritardando no final."""
    grid = np.linspace(0, total, max(2, int(total / 2) + 1))
    drift = np.cumsum(rng.normal(0, 0.012, len(grid)))
    drift = np.convolve(drift - drift.mean(), np.ones(5) / 5, mode='same')
    speed = 1.0 + np.clip(drift, -0.05, 0.05)
    if final_rit:
        speed[grid > total - 8] *= np.linspace(1.0, 1.25, int((grid > total - 8).sum()))
    # tempo real = integral do fator de lentidao
    real = np.concatenate([[0], np.cumsum(np.diff(grid) * speed[1:])])
    return lambda x: np.interp(x, grid, real)


def shape(notes, piece, rng):
    """Melodia mais presente, acordes um pouco espalhados, variacao humana de intensidade."""
    mel = piece.get('melody')
    by_on = {}
    for n in notes:
        by_on.setdefault((round(n[0], 2), n[4]), []).append(n)
    for (t, ch), group in by_on.items():
        group.sort(key=lambda n: n[2])
        top = group[-1]
        for i, n in enumerate(group):
            v = n[3] + rng.uniform(-4, 4)
            if mel is not None and ch == mel and n is top:
                v += 14
            elif mel is not None:
                v -= 6
            n[3] = int(np.clip(v, 8, 125))
            if len(group) > 2:
                n[0] += i * 0.008  # acorde levemente arpejado de baixo para cima
    return notes


def auto_pedal(notes, mode, end):
    if mode == 'none' or mode == 'file':
        return []
    bass = sorted({round(n[0], 3) for n in notes if n[4] == 1})
    out = []
    last = -10
    gap = 0.25 if mode == 'bass' else 0.9
    for t in bass:
        if t - last < gap:
            continue
        out += [(t - 0.03, False), (t + 0.06, True)]
        last = t
    out.append((end + 0.5, False))
    return out


def render(pid):
    piece = PIECES[pid]
    rng = random.Random(pid)
    nrng = np.random.default_rng(abs(hash(pid)) % 2 ** 32)
    all_notes, all_ped = [], []
    off = 0.0
    for r in range(piece.get('repeat', 1)):
        notes, ped, end = read_notes(SRC + piece['midi'], piece['stretch'])
        ped = ped if piece['pedal'] == 'file' else auto_pedal(notes, piece['pedal'], end)
        all_notes += [[n[0] + off, n[1] + off] + n[2:] for n in notes]
        all_ped += [(t + off, d) for t, d in ped]
        off += end + 1.0
    tm = tempo_map(off, nrng)
    all_notes = shape(all_notes, piece, rng)
    for n in all_notes:
        n[0], n[1] = float(tm(n[0])), float(tm(n[1]))
    all_ped = sorted((float(tm(t)), d) for t, d in all_ped)
    ped_t = np.array([p[0] for p in all_ped]) if all_ped else np.array([0.0])
    ped_d = np.array([p[1] for p in all_ped]) if all_ped else np.array([False])

    def release_time(t_off):
        """Com o pedal abaixado, a nota soa ate o pedal subir."""
        i = np.searchsorted(ped_t, t_off, side='right') - 1
        if i >= 0 and ped_d[i]:
            ups = np.where((ped_t > t_off) & (~ped_d))[0]
            return ped_t[ups[0]] if len(ups) else t_off + 4
        return t_off

    total = int((tm(off) + 5) * SR)
    out = np.zeros((total, 2), np.float32)
    rel = int(0.18 * SR)
    for st, en, note, vel, ch in all_notes:
        end = max(en, release_time(en))
        length = int((end - st) * SR) + rel
        a = note_audio(note, vel, length)
        if len(a) == 0:
            continue
        if len(a) > rel:
            a[-rel:] *= np.linspace(1, 0, rel)[:, None] ** 2
        i = int(st * SR)
        j = min(total, i + len(a))
        out[i:j] += a[:j - i] * (0.35 + 0.65 * vel / 127.0)
    dry = out.astype(np.float64)
    rt = 2.0
    n = int(rt * SR)
    t = np.arange(n) / SR
    ir = np.stack([np.convolve(nrng.standard_normal(n), np.ones(30) / 30, mode='same') * np.exp(-6.9 * t / rt)
                   for _ in range(2)], axis=1)
    ir[:int(0.015 * SR)] = 0
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    wet = np.stack([oaconvolve(dry[:, c], ir[:, c])[:len(dry)] for c in range(2)], axis=1)
    mix = dry * 0.85 + wet * 0.28
    rms = np.sqrt((mix ** 2).mean()) + 1e-9
    mix *= 10 ** (-20 / 20) / rms
    pk = np.abs(mix).max()
    if pk > 0.89:
        mix *= 0.89 / pk
    f = int(2.5 * SR)
    mix[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
    os.makedirs(OUT, exist_ok=True)
    wav = OUT + pid + '.wav'
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(mix, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', QUALIDADE, OUT + pid + '.ogg'],
                   check=True)
    os.remove(wav)
    print('%-26s %5.0f s' % (pid, len(mix) / SR), flush=True)


if __name__ == '__main__':
    for pid in sys.argv[1:] or list(PIECES):
        render(pid)
