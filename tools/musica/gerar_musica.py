#!/usr/bin/env python3
"""Gera as musicas do Pentakosmos a partir de partituras em dominio publico.

Passos (tudo automatico):
  1. baixa so as partituras usadas do Mutopia Project (github.com/MutopiaProject/MutopiaProject);
  2. converte para a versao atual do LilyPond e gera os MIDIs;
  3. baixa o banco de sons GeneralUser GS (pacote npm "generaluser");
  4. sintetiza cada peca (com pedal automatico, pequenas variacoes humanas e reverberacao)
     e grava assets/music/<id>.ogg.

Requisitos: git, npm, ffmpeg e
  pip install lilypond music21 mido numpy scipy
  pip install --no-deps tinysoundfont
Uso: python3 tools/musica/gerar_musica.py [id ...]
"""
import glob, json, os, random, shutil, subprocess, sys
import mido
import numpy as np
from scipy.signal import oaconvolve
import tinysoundfont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, "tools", "musica", "cache")
SR = 44100
SF2 = os.path.join(CACHE, "package", "GeneralUser.sf2")
SRC = os.path.join(CACHE, "mutopia", "ftp") + "/"
OUT = os.path.join(ROOT, "assets", "music") + "/"

# id: midi(s), tempo (fator de duracao), programas por canal, pedal, reverb, repeticoes, ganho por canal
PIECES = {
    "gymnopedie_1": dict(midi=["SatieE/gymnopedie_1/gymnopedie_1.midi"], stretch=1.3, prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "gymnopedie_2": dict(midi=["SatieE/gymnopedie_2/gymnopedie_2.midi"], stretch=1.1, prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "gymnopedie_3": dict(midi=["SatieE/gymnopedie_3/gymnopedie_3.midi"], stretch=1.1, prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "gnossienne_1": dict(midi=["SatieE/Gnossienne/no_1/no_1.midi"], stretch=1.0, prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "gnossienne_2": dict(midi=["SatieE/Gnossienne/no_2/no_2.midi"], stretch=1.0, prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "gnossienne_3": dict(midi=["SatieE/Gnossienne/no_3/no_3.midi"], stretch=0.95, prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "bach_air": dict(midi=["BachJS/BWV1068/bach-air/bach-air-lys/bach-air-score.midi"], stretch=1.15,
                     prog={0: 49, 1: 49, 2: 49, 3: 42}, room="church", gain={0: 1.15}),
    "bach_toccata_fugue": dict(midi=["BachJS/BWV565/ToccataFugue/ToccataFugue.midi"], stretch=1.0,
                               prog={0: 19, 1: 19, 2: 19}, room="church"),
    "bach_goldberg_aria": dict(midi=["BachJS/BWV988/bwv-988-aria/bwv-988-aria.midi"], stretch=1.4, prog={0: 0, 1: 0}, room="hall"),
    "bach_prelude_c": dict(midi=["BachJS/BWV846/wtk1-prelude1/wtk1-prelude1.midi"], stretch=1.15, prog={0: 0, 1: 0}, room="hall",
                           pedal="bar"),
    "chopin_nocturne_op9_2": dict(midi=["ChopinFF/O9/chopin_nocturne_op9_n2/chopin_nocturne_op9_n2.midi"], stretch=1.15,
                                  prog={0: 0, 1: 0}, pedal="bass", room="hall", gain={0: 1.1}),
    "vivaldi_summer": dict(midi=["VivaldiA/O8/summer/summer-lys/summer-score.midi",
                                 "VivaldiA/O8/summer/summer-lys/summer-score-1.midi",
                                 "VivaldiA/O8/summer/summer-lys/summer-score-2.midi"], stretch=1.0,
                           prog={0: 40, 1: 48, 2: 48, 3: 48, 4: 42}, room="hall", gain={0: 1.15}),
    "debussy_clair_de_lune": dict(midi=["DebussyC/L75/debussy_Ste_Bergamesq_Clair/debussy_Ste_Bergamesq_Clair.midi"],
                                  stretch=1.05, prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "debussy_arabesque_1": dict(midi=["DebussyC/L66/debussy_Arabesque_1/debussy_Arabesque_1.midi"], stretch=1.05,
                                prog={0: 0, 1: 0}, pedal="bass", room="hall"),
    "grieg_mountain_king": dict(midi=["GriegE/O46/Dans_l_antre_du_roi_de_la_montagne/Dans_l_antre_du_roi_de_la_montagne.midi"],
                                stretch=1.0, prog={0: 0, 1: 0}, room="hall"),
    "mussorgsky_bald_mountain": dict(midi=["MussorgskyM/nobm/nobm.midi"], stretch=1.0, prog={0: 0, 1: 0}, room="hall"),
    "holst_thaxted": dict(midi=["HolstGT/Thaxted/Thaxted.midi"], stretch=1.25, prog={0: 60, 1: 49, 2: 49},
                          room="church", repeat=2, gain={0: 1.2}),
    "handel_rejouissance": dict(midi=["HandelGF/BWV351/LaRej/LaRej.midi"], stretch=1.0, prog={0: 56, 1: 19, 2: 19},
                                room="church", repeat=2),
    "strauss_blue_danube": dict(midi=["StraussJJ/O314/blue_danube/blue_danube.midi"], stretch=1.1, prog={0: 0, 1: 0},
                                pedal="bass", room="hall", repeat=2),
}


def events_of(path, stretch):
    """Lista (tempo_s, msg) com tempo absoluto em segundos."""
    m = mido.MidiFile(path)
    t = 0.0
    out = []
    for msg in m:  # iteracao com delta em segundos (respeita mudancas de andamento)
        t += msg.time * stretch
        if not msg.is_meta:
            out.append((t, msg))
    return out, t


def humanize(evs, piece, rng):
    prog = piece.get("prog", {})
    gain = piece.get("gain", {})
    res = []
    for t, msg in evs:
        if msg.type == "program_change" and msg.channel in prog:
            continue
        if msg.type == "note_on" and msg.velocity > 0:
            v = msg.velocity * gain.get(msg.channel, 1.0) + rng.uniform(-5, 5)
            msg = msg.copy(velocity=int(max(12, min(124, v))))
            t += rng.uniform(0.0, 0.012)
        res.append((t, msg))
    return res


def pedal_events(evs, mode, end):
    """Pedal de sustentacao automatico: troca a cada nota nova do baixo (canal 1)."""
    out = []
    if mode == "bass":
        onsets = sorted({round(t, 3) for t, m in evs if m.type == "note_on" and m.velocity > 0 and m.channel == 1})
    elif mode == "bar":
        onsets = sorted({round(t, 3) for t, m in evs if m.type == "note_on" and m.velocity > 0 and m.channel == 1})
    else:
        return out
    last = -10.0
    for t in onsets:
        if t - last < 0.25:
            continue
        for ch in (0, 1):
            out.append((max(0.0, t - 0.02), mido.Message("control_change", channel=ch, control=64, value=0)))
            out.append((t + 0.05, mido.Message("control_change", channel=ch, control=64, value=100)))
        last = t
    for ch in (0, 1):
        out.append((end + 0.3, mido.Message("control_change", channel=ch, control=64, value=0)))
    return out


def reverb_ir(room, rng):
    rt = {"hall": 2.2, "church": 3.4}[room]
    n = int(rt * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for c in range(2):
        noise = rng.standard_normal(n)
        # o ar absorve mais os agudos: suaviza a cauda aos poucos
        k = int(0.0006 * SR) + 1
        noise = np.convolve(noise, np.ones(k) / k, mode="same")
        ir[:, c] = noise * np.exp(-6.9 * t / rt)
    ir[: int(0.012 * SR)] = 0  # pre-delay
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    return ir


def render(pid):
    piece = PIECES[pid]
    rng = random.Random(pid)
    nrng = np.random.default_rng(abs(hash(pid)) % (2 ** 32))
    seq = []
    offset = 0.0
    for rep in range(piece.get("repeat", 1)):
        for k, mid in enumerate(piece["midi"]):
            evs, end = events_of(SRC + mid, piece["stretch"])
            evs = humanize(evs, piece, rng)
            evs += pedal_events(evs, piece.get("pedal"), end)
            seq += [(t + offset, m) for t, m in evs]
            offset += end + (2.5 if k < len(piece["midi"]) - 1 or rep < piece.get("repeat", 1) - 1 else 0.0)
    seq.sort(key=lambda e: e[0])
    synth = tinysoundfont.Synth(samplerate=SR, gain=-6)
    sf = synth.sfload(SF2)
    for ch in range(16):
        synth.program_select(ch, sf, 0, piece.get("prog", {}).get(ch, 0))
    total = int((offset + 4.0) * SR)
    audio = np.zeros((total, 2), dtype=np.float32)
    pos = 0
    for t, msg in seq:
        target = min(total, int(t * SR))
        if target > pos:
            buf = synth.generate_simple(target - pos)
            audio[pos:target] = np.frombuffer(buf, dtype=np.float32).reshape(-1, 2)
            pos = target
        if msg.type == "note_on":
            if msg.velocity > 0:
                synth.noteon(msg.channel, msg.note, msg.velocity)
            else:
                synth.noteoff(msg.channel, msg.note)
        elif msg.type == "note_off":
            synth.noteoff(msg.channel, msg.note)
        elif msg.type == "control_change":
            synth.control_change(msg.channel, msg.control, msg.value)
        elif msg.type == "program_change":
            synth.program_select(msg.channel, sf, 0, msg.program)
        elif msg.type == "pitchwheel":
            synth.pitchbend(msg.channel, msg.pitch + 8192)
    if total > pos:
        audio[pos:] = np.frombuffer(synth.generate_simple(total - pos), dtype=np.float32).reshape(-1, 2)
    dry = audio.astype(np.float64)
    ir = reverb_ir(piece.get("room", "hall"), nrng)
    wet = np.stack([oaconvolve(dry[:, c], ir[:, c])[: len(dry)] for c in range(2)], axis=1)
    mix = dry * 0.82 + wet * (0.30 if piece.get("room") == "hall" else 0.38)
    # nivel: RMS alvo e pico maximo
    rms = np.sqrt((mix ** 2).mean()) + 1e-9
    mix *= 10 ** (-20 / 20) / rms
    peak = np.abs(mix).max()
    if peak > 0.89:
        mix *= 0.89 / peak
    f_in, f_out = int(0.02 * SR), int(2.5 * SR)
    mix[:f_in] *= np.linspace(0, 1, f_in)[:, None]
    mix[-f_out:] *= np.linspace(1, 0, f_out)[:, None] ** 2
    os.makedirs(OUT, exist_ok=True)
    wav = OUT + pid + ".wav"
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(mix, -1, 1) * 32767).astype(np.int16).tobytes())
    ogg = OUT + pid + ".ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav)
    print("%-28s %5.0f s  %5.1f MB" % (pid, len(mix) / SR, os.path.getsize(ogg) / 1e6), flush=True)


MAIN_LY = {
    "gymnopedie_1": "SatieE/gymnopedie_1/gymnopedie_1.ly", "gymnopedie_2": "SatieE/gymnopedie_2/gymnopedie_2.ly",
    "gymnopedie_3": "SatieE/gymnopedie_3/gymnopedie_3.ly", "gnossienne_1": "SatieE/Gnossienne/no_1/no_1.ly",
    "gnossienne_2": "SatieE/Gnossienne/no_2/no_2.ly", "gnossienne_3": "SatieE/Gnossienne/no_3/no_3.ly",
    "bach_air": "BachJS/BWV1068/bach-air/bach-air-lys/bach-air-score.ly",
    "bach_toccata_fugue": "BachJS/BWV565/ToccataFugue/ToccataFugue.ly",
    "bach_goldberg_aria": "BachJS/BWV988/bwv-988-aria/bwv-988-aria.ly",
    "bach_prelude_c": "BachJS/BWV846/wtk1-prelude1/wtk1-prelude1.ly",
    "chopin_nocturne_op9_2": "ChopinFF/O9/chopin_nocturne_op9_n2/chopin_nocturne_op9_n2.ly",
    "vivaldi_summer": "VivaldiA/O8/summer/summer-lys/summer-score.ly",
    "debussy_clair_de_lune": "DebussyC/L75/debussy_Ste_Bergamesq_Clair/debussy_Ste_Bergamesq_Clair.ly",
    "debussy_arabesque_1": "DebussyC/L66/debussy_Arabesque_1/debussy_Arabesque_1.ly",
    "grieg_mountain_king": "GriegE/O46/Dans_l_antre_du_roi_de_la_montagne/Dans_l_antre_du_roi_de_la_montagne.ly",
    "mussorgsky_bald_mountain": "MussorgskyM/nobm/nobm.ly", "holst_thaxted": "HolstGT/Thaxted/Thaxted.ly",
    "handel_rejouissance": "HandelGF/BWV351/LaRej/LaRej.ly", "strauss_blue_danube": "StraussJJ/O314/blue_danube/blue_danube.ly",
}


def prepare():
    os.makedirs(CACHE, exist_ok=True)
    repo = os.path.join(CACHE, "mutopia")
    if not os.path.exists(repo):
        subprocess.run(["git", "clone", "-q", "--filter=blob:none", "--no-checkout", "--depth", "1",
                        "https://github.com/MutopiaProject/MutopiaProject", repo], check=True)
        subprocess.run(["git", "-C", repo, "sparse-checkout", "init", "--no-cone"], check=True)
        dirs = set()
        for p in MAIN_LY.values():
            d = os.path.dirname(p)
            if d.endswith("-lys"):
                d = os.path.dirname(d)
            dirs.add("/ftp/" + d + "/")
        dirs = sorted(dirs)
        open(os.path.join(repo, ".git", "info", "sparse-checkout"), "w").write("\n".join(dirs) + "\n")
        subprocess.run(["git", "-C", repo, "checkout", "-q", "HEAD"], check=True)
        import lilypond
        bindir = os.path.dirname(str(lilypond.executable()))
        for f in glob.glob(SRC + "**/*.*ly*", recursive=True):
            subprocess.run([os.path.join(bindir, "convert-ly"), "-e", "-d", f], capture_output=True)
        for p in MAIN_LY.values():
            d, b = os.path.split(SRC + p)
            subprocess.run([str(lilypond.executable()), "-dno-print-pages", "-dbackend=null", "-l", "ERROR", b],
                           cwd=d, capture_output=True)
    if not os.path.exists(SF2):
        subprocess.run(["npm", "pack", "generaluser"], cwd=CACHE, check=True, capture_output=True)
        tgz = glob.glob(os.path.join(CACHE, "generaluser-*.tgz"))[0]
        subprocess.run(["tar", "xzf", tgz], cwd=CACHE, check=True)


if __name__ == "__main__":
    prepare()
    ids = sys.argv[1:] or list(PIECES)
    for pid in ids:
        render(pid)
