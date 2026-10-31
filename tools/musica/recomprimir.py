#!/usr/bin/env python3
"""Recomprime as musicas ja prontas em assets/music/ numa outra qualidade de Ogg Vorbis, sem
precisar gerar tudo de novo a partir das partituras (mais rapido; uma pequena perda extra por
recodificar). Para a melhor qualidade possivel, gere de novo com:
    PENTAKOSMOS_QUALIDADE=<q> python3 tools/musica/gerar_musica.py

Uso: python3 tools/musica/recomprimir.py <qualidade>      (ex.: 2; de 0 a 10)
"""
import glob, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
q = sys.argv[1] if len(sys.argv) > 1 else "2"
antes = depois = 0
for f in sorted(glob.glob(os.path.join(ROOT, "assets", "music", "*.ogg"))):
    tmp = f + ".tmp.ogg"
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", f, "-c:a", "libvorbis", "-q:a", q, tmp], check=True)
    antes += os.path.getsize(f); depois += os.path.getsize(tmp)
    os.replace(tmp, f)
    print(os.path.basename(f))
print("Total: %.1f MB -> %.1f MB" % (antes / 1e6, depois / 1e6))
