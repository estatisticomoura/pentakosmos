#!/usr/bin/env python3
"""Gera as musicas do Pentakosmos a partir de partituras em dominio publico.

1. Baixa so as partituras usadas do Mutopia Project e gera os MIDIs com o LilyPond,
   expandindo as repeticoes.
2. Baixa os instrumentos gravados, de licenca livre:
   - Salamander Grand Piano V3 (Alexander Holm, CC BY 3.0), pacotes npm @audio-samples/piano-velocity1..16;
   - VSCO 2 Community Edition (Versilian Studios, CC0), github.com/sgossner/VSCO-2-CE.
3. Renderiza as pecas de piano (piano.py) e as orquestrais (orquestra.py) em assets/music/<id>.ogg.

Requisitos: git, npm, ffmpeg e
  pip install lilypond mido numpy scipy soundfile
Uso: python3 tools/musica/gerar_musica.py [id ...]
"""
import glob, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")

MUTOPIA = {
    "SatieE/gymnopedie_1/gymnopedie_1.ly", "SatieE/gymnopedie_2/gymnopedie_2.ly", "SatieE/gymnopedie_3/gymnopedie_3.ly",
    "SatieE/Gnossienne/no_1/no_1.ly", "SatieE/Gnossienne/no_2/no_2.ly", "SatieE/Gnossienne/no_3/no_3.ly",
    "BachJS/BWV1068/bach-air/bach-air-lys/bach-air-score.ly", "BachJS/BWV565/ToccataFugue/ToccataFugue.ly",
    "BachJS/BWV988/bwv-988-aria/bwv-988-aria.ly", "BachJS/BWV846/wtk1-prelude1/wtk1-prelude1.ly",
    "ChopinFF/O9/chopin_nocturne_op9_n2/chopin_nocturne_op9_n2.ly", "VivaldiA/O8/summer/summer-lys/summer-score.ly",
    "DebussyC/L75/debussy_Ste_Bergamesq_Clair/debussy_Ste_Bergamesq_Clair.ly",
    "DebussyC/L66/debussy_Arabesque_1/debussy_Arabesque_1.ly",
    "GriegE/O46/Dans_l_antre_du_roi_de_la_montagne/Dans_l_antre_du_roi_de_la_montagne.ly", "MussorgskyM/nobm/nobm.ly",
    "HolstGT/Thaxted/Thaxted.ly", "HandelGF/BWV351/LaRej/LaRej.ly", "StraussJJ/O314/blue_danube/blue_danube.ly",
}
VSCO_DIRS = ["Strings/Violin Section/susVib", "Strings/Violin Section/Spic", "Strings/Violin Section/Pizz",
             "Strings/Viola Section/susvib", "Strings/Viola Section/spic", "Strings/Viola Section/pizz",
             "Strings/Cello Section/susvib", "Strings/Cello Section/spic", "Strings/Cello Section/pizzT",
             "Strings/Solo Contrabass/SusVib", "Strings/Solo Contrabass/Spic", "Strings/Solo Contrabass/Pizz",
             "Strings/Solo Violin/Arco Vib", "Strings/Solo Violin/spic", "Brass/F Horn/sus", "Brass/Trumpet/sus",
             "Brass/Tenor Trombone/sus", "Brass/Tuba/sus", "Woodwinds/Flute/susvib", "Woodwinds/Oboe/Vib",
             "Woodwinds/Clarinet/susLong", "Woodwinds/Bassoon/sus", "Woodwinds/Bassoon/stac", "Keys/Organ/Loud"]


def sparse_clone(url, dest, paths):
    if os.path.exists(dest):
        return
    subprocess.run(["git", "clone", "-q", "--filter=blob:none", "--no-checkout", "--depth", "1", url, dest], check=True)
    subprocess.run(["git", "-C", dest, "sparse-checkout", "init", "--no-cone"], check=True)
    open(os.path.join(dest, ".git", "info", "sparse-checkout"), "w").write("\n".join("/" + p + "/" for p in paths) + "\n")
    subprocess.run(["git", "-C", dest, "checkout", "-q", "HEAD"], check=True)


def prepare():
    os.makedirs(CACHE, exist_ok=True)
    mut = os.path.join(CACHE, "mutopia")
    if not os.path.exists(mut):
        dirs = set()
        for p in MUTOPIA:
            d = os.path.dirname(p)
            dirs.add("ftp/" + (os.path.dirname(d) if d.endswith("-lys") else d))
        sparse_clone("https://github.com/MutopiaProject/MutopiaProject", mut, sorted(dirs))
        import lilypond
        lp = str(lilypond.executable())
        conv = os.path.join(os.path.dirname(lp), "convert-ly")
        src = os.path.join(mut, "ftp")
        for f in glob.glob(src + "/**/*.*ly*", recursive=True):
            subprocess.run([conv, "-e", "-d", f], capture_output=True)
        for p in MUTOPIA:
            f = os.path.join(src, p)
            s = open(f, encoding="utf-8", errors="replace").read()
            # o MIDI precisa tocar as repeticoes por extenso
            s = re.sub(r"\\score\s*\{(\s*)(\\header\s*\{[^}]*\}\s*)?",
                       lambda m: "\\score {" + m.group(1) + (m.group(2) or "") + "\\unfoldRepeats ", s)
            open(f, "w", encoding="utf-8").write(s)
            d, b = os.path.split(f)
            subprocess.run([lp, "-dno-print-pages", "-dbackend=null", "-l", "ERROR", b], cwd=d, capture_output=True)
    sal = os.path.join(CACHE, "salamander")
    if not os.path.exists(sal):
        os.makedirs(sal)
        tmp = os.path.join(CACHE, "npm")
        os.makedirs(tmp, exist_ok=True)
        for v in range(1, 17):
            subprocess.run(["npm", "pack", "@audio-samples/piano-velocity%d" % v], cwd=tmp, check=True, capture_output=True)
        for t in glob.glob(os.path.join(tmp, "*.tgz")):
            subprocess.run(["tar", "xzf", t, "-C", sal, "--strip-components=2", "package/audio"], check=True)
    sparse_clone("https://github.com/sgossner/VSCO-2-CE", os.path.join(CACHE, "vsco"), VSCO_DIRS)


if __name__ == "__main__":
    prepare()
    sys.path.insert(0, HERE)
    import piano, orquestra
    ids = sys.argv[1:]
    for pid in (ids or list(piano.PIECES)):
        if pid in piano.PIECES:
            piano.render(pid)
    for pid in (ids or list(orquestra.PIECES)):
        if pid in orquestra.PIECES:
            orquestra.render(pid)
