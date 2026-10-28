#!/usr/bin/env python3
"""Confere as traducoes do jogo.

Os textos ficam em ingles no codigo (L.t("...") e L.f("...") e as linhas
marcadas com "# tr"). Cada idioma e um arquivo data/lang/<codigo>.json:
{"texto em ingles": "traducao"}.

Uso:
  python3 tools/idiomas.py              resumo: quantos textos faltam em cada idioma
  python3 tools/idiomas.py pt           lista o que falta em portugues
  python3 tools/idiomas.py --modelo xx  cria/completa data/lang/xx.json com os textos que faltam ("")
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANG_DIR = os.path.join(ROOT, "data", "lang")
# identificadores internos que aparecem nas linhas "# tr" mas nao sao texto
IDS = {"classico", "opcoes", "house", "gems_mode", "gold_mode", "take2_min", "market5", "exato", "flexivel",
       "noble_mode", "noble_free", "writer_free", "patrons", "ambos", "filosofos", "escritores", "nenhum", "time_ai", "time_humans", "arcaico", "fixo", "decrescente", "noble_points_mode", "deck", "oficial", "caio", "hand_limit",
       "target", "color_win", "humano", "facil", "normal", "intermediaria", "dificil", "tatica",
       "evoluida", "muito_dificil", "mista", "gemas", "solidos", "poligonal", "rules", "story", "rules_pentakosmos",
       "rules_arcaico", "opponents", "free", "num", "time", "stats", "music", "Pentakosmos", ""}
LIT = r'"((?:[^"\\]|\\.)*)"'


def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def keys():
    found = []
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True)):
        for line in open(path, encoding="utf-8"):
            code = line.split("##")[0]
            for m in re.finditer(r'L\.[tf]\(\s*' + LIT, code):
                found.append(unescape(m.group(1)))
            if re.search(r"#\s*tr\s*$", line):
                body = line[: line.rindex("#")]
                for m in re.finditer(LIT, body):
                    k = unescape(m.group(1))
                    if k not in IDS and not re.fullmatch(r"[\d ./]+", k):
                        found.append(k)
    out = []
    for k in found:
        if k not in out:
            out.append(k)
    return out


def load(code):
    path = os.path.join(LANG_DIR, code + ".json")
    if not os.path.exists(path):
        return {}
    return json.load(open(path, encoding="utf-8"))


def main():
    ks = keys()
    args = sys.argv[1:]
    if args[:1] == ["--modelo"] and len(args) == 2:
        code = args[1]
        d = load(code)
        merged = {k: d.get(k, "") for k in ks}
        os.makedirs(LANG_DIR, exist_ok=True)
        json.dump(merged, open(os.path.join(LANG_DIR, code + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("%s.json: %d textos, %d em branco" % (code, len(ks), sum(1 for k in ks if not merged[k])))
        return
    if args:
        d = load(args[0])
        for k in ks:
            if not d.get(k):
                print(json.dumps(k, ensure_ascii=False))
        return
    print("%d textos no codigo" % len(ks))
    for path in sorted(glob.glob(os.path.join(LANG_DIR, "*.json"))):
        code = os.path.basename(path)[:-5]
        d = load(code)
        miss = [k for k in ks if not d.get(k)]
        extra = [k for k in d if k not in ks]
        bad = [k for k in ks if d.get(k) and set(re.findall(r"\{\w+\}", k)) != set(re.findall(r"\{\w+\}", d[k]))]
        print("  %-4s faltam %3d | sobrando %3d | marcadores {..} errados %d" % (code, len(miss), len(extra), len(bad)))
        for k in bad:
            print("       marcador errado:", k)


if __name__ == "__main__":
    main()
