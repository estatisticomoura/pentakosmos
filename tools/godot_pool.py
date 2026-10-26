"""Roda partidas IA x IA em varios processos do Godot ao mesmo tempo.

Usado por evoluir.py e torneio.py. Cada processo recebe um lote de partidas
(arquivo JSON) e devolve os resultados (outro JSON).
"""
import json
import os
import shlex
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def godot_cmd(arg):
    """'godot', um caminho, ou 'flatpak run org.godotengine.Godot'."""
    return shlex.split(arg) if arg else ["godot"]


_imported = False


def ensure_imported(godot="godot"):
    """Na primeira execucao, o Godot precisa importar o projeto (cria a pasta .godot)."""
    global _imported
    if _imported:
        return
    cache = os.path.join(PROJECT, ".godot", "global_script_class_cache.cfg")
    if not os.path.exists(cache):
        print("Importando o projeto no Godot (so na primeira vez)...")
        proc = subprocess.run(godot_cmd(godot) + ["--headless", "--path", PROJECT, "--import"],
                              capture_output=True, text=True)
        if not os.path.exists(cache):
            raise RuntimeError("Nao consegui importar o projeto com o comando %r.\n%s\n%s" % (
                godot, proc.stdout[-2000:], proc.stderr[-2000:]))
    _imported = True


def run_matches(matches, godot="godot", workers=None, chunk=40, label="", quiet=False):
    """matches: lista de {"rules", "seats", "seed"}. Retorna os resultados na mesma ordem."""
    ensure_imported(godot)
    workers = workers or os.cpu_count() or 1
    cmd = godot_cmd(godot)
    batches = [matches[i:i + chunk] for i in range(0, len(matches), chunk)]
    results = [None] * len(batches)
    tmp = tempfile.mkdtemp(prefix="pentakosmos_")
    t0 = time.time()
    done = 0

    def work(bi):
        inp = os.path.join(tmp, f"in_{bi}.json")
        out = os.path.join(tmp, f"out_{bi}.json")
        with open(inp, "w") as f:
            json.dump({"matches": batches[bi]}, f)
        proc = subprocess.run(cmd + ["--headless", "--path", PROJECT, "--script", "res://tests/partidas.gd",
                                     "--", inp, out], capture_output=True, text=True)
        if not os.path.exists(out):
            raise RuntimeError("Godot falhou no lote %d:\n%s\n%s" % (bi, proc.stdout[-2000:], proc.stderr[-2000:]))
        with open(out) as f:
            res = json.load(f)["results"]
        os.remove(inp)
        os.remove(out)
        return bi, res

    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(work, i) for i in range(len(batches))]
        for fu in as_completed(futs):
            bi, res = fu.result()
            results[bi] = res
            done += len(res)
            if not quiet:
                el = time.time() - t0
                rate = done / el if el > 0 else 0
                sys.stdout.write("\r  %s %d/%d partidas (%.0f/s, faltam ~%.0fs)   " % (
                    label, done, len(matches), rate, (len(matches) - done) / max(rate, 1e-9)))
                sys.stdout.flush()
    if not quiet:
        sys.stdout.write("\n")
    try:
        os.rmdir(tmp)
    except OSError:
        pass
    return [r for b in results for r in b]
