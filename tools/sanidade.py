#!/usr/bin/env python3
"""Bateria de sanidade da IA: procura combinacoes de regras em que a IA joga mal.

Sorteia muitas combinacoes de regras (inclusive governantes, escritores, metas de 8 a 30 pontos)
e, em cada uma, joga partidas entre uma IA forte e uma fraca. Mede:

  - vitorias da forte sobre a fraca (se a forte nao vence bem mais que a fraca, a IA se perde ali);
  - fichas devolvidas por ter passado do limite da mao, a cada 10 vezes (o comportamento "burro");
  - vezes em que passou a vez, reservas que nunca foram compradas e partidas que nao terminaram;
  - duracao das partidas, em rodadas.

O relatorio mostra esses numeros por valor de cada regra (por exemplo "meta 25" ou "governantes
ligados") e marca com "!!" o que preocupa. Tudo e gravado em tools/sanidade/<data>.json; com
--comparar, dois relatorios sao comparados (por exemplo, antes e depois de um treino).

Uso (na pasta do projeto):
    python3 tools/sanidade.py                          # 150 combinacoes x 8 partidas (~10 a 30 min)
    python3 tools/sanidade.py --combos 400 --partidas 12
    python3 tools/sanidade.py --comparar tools/sanidade/A.json tools/sanidade/B.json
    python3 tools/sanidade.py --godot "flatpak run org.godotengine.Godot"
"""
import argparse
import json
import math
import os
import random
import time

from godot_pool import PROJECT, run_matches

PASTA = os.path.join(PROJECT, "tools", "sanidade")

# Regras fixas sempre incluidas (as predefinicoes do jogo)
PENTAKOSMOS = {"gems_mode": "house", "gold_mode": "house", "take2_min": 3, "market5": 5, "deck": "caio",
               "philosophers": True, "writers": False, "noble_free": 2, "noble_points_mode": "decrescente",
               "writer_free": 0, "governors": False, "hand_limit": 10, "target": 15, "color_win": 10}
ARCAICO = {"gems_mode": "classico", "gold_mode": "classico", "take2_min": 4, "market5": 4, "deck": "arcaico",
           "philosophers": True, "writers": True, "noble_free": 0, "noble_points_mode": "fixo",
           "writer_free": 0, "governors": False, "hand_limit": 10, "target": 15, "color_win": 0}
PENTA_GOV = dict(PENTAKOSMOS, writers=True, writer_free=1, governors=True, gov_pick="escolha", gov_target=19)
FIXAS = [("Pentakosmos", PENTAKOSMOS), ("Arcaico", ARCAICO), ("Pentakosmos + governantes", PENTA_GOV)]

ESCOLHAS = {
    "gems_mode": ["classico", "house"], "gold_mode": ["classico", "house"], "take2_min": [3, 4],
    "market5": [4, 5], "deck": ["arcaico", "caio"], "philosophers": [True, True, False],
    "writers": [False, True], "noble_free": [0, 1, 2, 3], "noble_points_mode": ["fixo", "decrescente"],
    "writer_free": [0, 1, 2], "governors": [False, True], "gov_pick": ["escolha", "sorteio"],
    "gov_target": [15, 19, 23], "hand_limit": [9, 10, 11], "target": [8, 10, 12, 15, 18, 21, 25, 30],
    "color_win": [0, 0, 9, 10, 11, 12],
}


def regras_aleatorias(rng):
    return {k: rng.choice(v) for k, v in ESCOLHAS.items()}


def grupos_de(r):
    """Rotulos de grupo de uma combinacao de regras (para o relatorio por regra)."""
    g = ["meta %d" % r["target"] if not r.get("governors") else "meta (governantes) %d" % r["gov_target"],
         "mao %d" % r["hand_limit"], "deck " + {"caio": "Pentakosmos", "arcaico": "Arcaico"}[r["deck"]],
         "especializacao " + (str(r["color_win"]) if r["color_win"] else "desligada"),
         "pegar 2 com %d+" % r["take2_min"],
         "filosofos " + ("ligados (-%d)" % r["noble_free"] if r.get("philosophers", True) else "desligados"),
         "escritores " + ("ligados" if r.get("writers") else "desligados"),
         "governantes " + (("ligados, " + r.get("gov_pick", "escolha")) if r.get("governors") else "desligados")]
    return g


def montar(combos, n_partidas, forte, fraco, rng):
    """Partidas: em cada combinacao, duelos forte x fraco (alternando quem comeca) e partidas
    de 3 jogadores [forte, normal, fraco] em assentos girando."""
    jogos = []
    for ci, (nome, regras) in enumerate(combos):
        for k in range(n_partidas):
            if k % 2 == 0:
                seats = [forte, fraco] if (k // 2) % 2 == 0 else [fraco, forte]
            else:
                base = [forte, "normal", fraco]
                s = (k // 2) % 3
                seats = base[s:] + base[:s]
            jogos.append({"combo": ci, "rules": regras, "seats": seats, "seed": rng.randrange(1, 2 ** 31)})
    return jogos


def resumir(jogos, res, combos, forte, fraco):
    """Agrega por combinacao e por grupo de regra."""
    por_combo = {}
    for j, r in zip(jogos, res):
        c = por_combo.setdefault(j["combo"], {"vit_forte": [], "desc": {}, "pass": {}, "abertas": {},
                                               "turnos": {}, "rodadas": [], "travadas": 0, "partidas": 0})
        c["partidas"] += 1
        c["rodadas"].append(r["rounds"])
        if not r.get("finished", True):
            c["travadas"] += 1
        i_f, i_w = j["seats"].index(forte), j["seats"].index(fraco)
        tot = r["win"][i_f] + r["win"][i_w]
        # vitoria da forte contra a fraca (empates e vitorias da normal contam metade)
        c["vit_forte"].append(0.5 if tot == 0 else r["win"][i_f] / tot)
        for i, kind in enumerate(j["seats"]):
            st = r["stats"][i]
            for chave, campo in (("desc", "discards"), ("pass", "passes"), ("abertas", "open_reserves"), ("turnos", "turns")):
                c[chave][kind] = c[chave].get(kind, 0) + st[campo]
    linhas = []
    for ci, c in sorted(por_combo.items()):
        nome, regras = combos[ci]
        turnos = c["turnos"]
        linhas.append({
            "nome": nome, "regras": regras, "partidas": c["partidas"],
            "vitoria_forte": sum(c["vit_forte"]) / len(c["vit_forte"]),
            "devolvidas_10_vezes": {k: 10.0 * c["desc"][k] / max(1, turnos[k]) for k in turnos},
            "passes_10_vezes": {k: 10.0 * c["pass"][k] / max(1, turnos[k]) for k in turnos},
            "reservas_abertas": {k: c["abertas"][k] / c["partidas"] for k in turnos},
            "rodadas": sum(c["rodadas"]) / len(c["rodadas"]), "travadas": c["travadas"],
            "_vit": c["vit_forte"],
        })
    return linhas


def media_ic(xs):
    if not xs:
        return 0.0, 0.0
    m = sum(xs) / len(xs)
    if len(xs) < 2:
        return m, 0.0
    v = sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return m, 1.96 * math.sqrt(v / len(xs))


def por_grupo(linhas, forte, fraco):
    grupos = {}
    for l in linhas:
        for g in grupos_de(l["regras"]):
            b = grupos.setdefault(g, {"vit": [], "desc_f": [], "desc_w": [], "pass": [], "rod": [], "trav": 0, "n": 0})
            b["vit"] += l["_vit"]
            b["desc_f"].append(l["devolvidas_10_vezes"].get(forte, 0))
            b["desc_w"].append(l["devolvidas_10_vezes"].get(fraco, 0))
            b["pass"].append(l["passes_10_vezes"].get(forte, 0))
            b["rod"].append(l["rodadas"])
            b["trav"] += l["travadas"]
            b["n"] += l["partidas"]
    out = {}
    for g, b in grupos.items():
        m, ic = media_ic(b["vit"])
        out[g] = {"vitoria_forte": round(m, 3), "ic": round(ic, 3), "partidas": b["n"],
                  "devolvidas_forte": round(sum(b["desc_f"]) / len(b["desc_f"]), 2),
                  "devolvidas_fraca": round(sum(b["desc_w"]) / len(b["desc_w"]), 2),
                  "passes_forte": round(sum(b["pass"]) / len(b["pass"]), 2),
                  "rodadas": round(sum(b["rod"]) / len(b["rod"]), 1), "travadas": b["trav"]}
    return out


def imprimir(rel):
    g = rel["grupos"]
    print("\nIA forte = %s, fraca = %s | %d combinacoes, %d partidas, %.0f min"
          % (rel["forte"], rel["fraca"], rel["combos"], rel["partidas"], rel["minutos"]))
    print("Geral: a forte vence a fraca em %.0f%% (±%.0f) | fichas devolvidas a cada 10 vezes: forte %.2f, fraca %.2f"
          % (100 * rel["geral"]["vitoria_forte"], 100 * rel["geral"]["ic"], rel["geral"]["devolvidas_forte"],
             rel["geral"]["devolvidas_fraca"]))
    print("\n%-34s %9s %8s %10s %8s %8s %6s" % ("grupo", "vit.forte", "(±)", "devolv.F/W", "passes", "rodadas", "trav."))
    for k in sorted(g):
        v = g[k]
        alerta = []
        if v["vitoria_forte"] + v["ic"] < 0.6:
            alerta.append("forte nao domina")
        if v["devolvidas_forte"] > max(0.5, 2 * rel["geral"]["devolvidas_forte"]):
            alerta.append("devolve demais")
        if v["travadas"]:
            alerta.append("partidas travadas")
        print("%-34s %8.0f%% %7.0f%% %5.2f/%-4.2f %8.2f %8.1f %6d %s"
              % (k, 100 * v["vitoria_forte"], 100 * v["ic"], v["devolvidas_forte"], v["devolvidas_fraca"],
                 v["passes_forte"], v["rodadas"], v["travadas"], ("!! " + ", ".join(alerta)) if alerta else ""))
    piores = sorted(rel["linhas"], key=lambda l: l["vitoria_forte"])[:5]
    print("\nCombinacoes em que a forte foi pior (poucas partidas cada: confira com mais partidas):")
    for l in piores:
        r = l["regras"]
        print("  %3.0f%%  %s" % (100 * l["vitoria_forte"], ", ".join("%s=%s" % (k, r[k]) for k in sorted(r))))


def comparar(a, b):
    print("Comparacao: A = %s | B = %s" % (a["quando"], b["quando"]))
    print("%-34s %14s %14s %16s" % ("grupo", "vit.forte A>B", "devolv.F A>B", "rodadas A>B"))
    for k in sorted(set(a["grupos"]) & set(b["grupos"])):
        x, y = a["grupos"][k], b["grupos"][k]
        print("%-34s %5.0f%% > %3.0f%% %6.2f > %5.2f %7.1f > %5.1f"
              % (k, 100 * x["vitoria_forte"], 100 * y["vitoria_forte"], x["devolvidas_forte"], y["devolvidas_forte"],
                 x["rodadas"], y["rodadas"]))
    ga, gb = a["geral"], b["geral"]
    print("\nGERAL: vitoria da forte %.0f%% > %.0f%% | devolvidas (forte) %.2f > %.2f"
          % (100 * ga["vitoria_forte"], 100 * gb["vitoria_forte"], ga["devolvidas_forte"], gb["devolvidas_forte"]))


def rodar(combos_n=150, partidas=8, forte="muito_dificil", fraca="facil", godot="godot", workers=None,
          semente=7, rotulo="", quiet=False):
    rng = random.Random(semente)
    combos = list(FIXAS) + [("aleatoria %d" % (i + 1), regras_aleatorias(rng)) for i in range(combos_n)]
    jogos = montar(combos, partidas, forte, fraca, rng)
    t0 = time.time()
    res = run_matches([{k: j[k] for k in ("rules", "seats", "seed")} for j in jogos], godot, workers,
                      chunk=24, label="sanidade", quiet=quiet)
    linhas = resumir(jogos, res, combos, forte, fraca)
    grupos = por_grupo(linhas, forte, fraca)
    tudo = [x for l in linhas for x in l["_vit"]]
    m, ic = media_ic(tudo)
    geral = {"vitoria_forte": round(m, 3), "ic": round(ic, 3),
             "devolvidas_forte": round(sum(l["devolvidas_10_vezes"].get(forte, 0) for l in linhas) / len(linhas), 2),
             "devolvidas_fraca": round(sum(l["devolvidas_10_vezes"].get(fraca, 0) for l in linhas) / len(linhas), 2)}
    for l in linhas:
        del l["_vit"]
    rel = {"quando": time.strftime("%Y-%m-%d %H:%M"), "rotulo": rotulo, "forte": forte, "fraca": fraca,
           "combos": len(combos), "partidas": len(jogos), "minutos": (time.time() - t0) / 60,
           "partidas_por_segundo": len(jogos) / max(1e-9, time.time() - t0),
           "geral": geral, "grupos": grupos, "linhas": linhas}
    os.makedirs(PASTA, exist_ok=True)
    caminho = os.path.join(PASTA, time.strftime("%Y%m%d-%H%M") + ("-" + rotulo if rotulo else "") + ".json")
    with open(caminho, "w") as f:
        json.dump(rel, f, indent=1, ensure_ascii=False)
    rel["arquivo"] = caminho
    return rel


def main():
    ap = argparse.ArgumentParser(description="Bateria de sanidade da IA")
    ap.add_argument("--combos", type=int, default=150, help="combinacoes de regras sorteadas (alem das 3 predefinicoes)")
    ap.add_argument("--partidas", type=int, default=8, help="partidas por combinacao")
    ap.add_argument("--forte", default="muito_dificil")
    ap.add_argument("--fraca", default="facil")
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--semente", type=int, default=7)
    ap.add_argument("--comparar", nargs=2, metavar=("A.json", "B.json"))
    args = ap.parse_args()
    if args.comparar:
        comparar(*(json.load(open(p)) for p in args.comparar))
        return
    rel = rodar(args.combos, args.partidas, args.forte, args.fraca, args.godot, args.workers, args.semente)
    imprimir(rel)
    print("\nGravado em " + os.path.relpath(rel["arquivo"], PROJECT))


if __name__ == "__main__":
    main()
