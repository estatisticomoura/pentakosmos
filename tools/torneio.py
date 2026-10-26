#!/usr/bin/env python3
"""Torneio entre as tres candidatas aos niveis mais altos de IA.

  "evoluida" = estrategista com parametros do algoritmo genetico (data/ia_evoluida.json)
  "tatica"   = estrategista + negacao cirurgica + busca no fim de jogo
  "mista"    = tatica usando os parametros da evoluida

Classificacao final:  1a = IA muito dificil | 2a = IA dificil | 3a = IA intermediaria
O resultado e gravado em data/niveis.json, que o jogo le ao iniciar.

Uso (na pasta do projeto ou em tools/):
    python3 tools/torneio.py                       # 2000 partidas por formato
    python3 tools/torneio.py --partidas 4000
    python3 tools/torneio.py --godot "flatpak run org.godotengine.Godot"
    python3 tools/torneio.py --sem-gravar          # so mostra o resultado
    python3 tools/torneio.py --modo house          # so house completa -> data/niveis_house.json
    python3 tools/torneio.py --modo classico       # so classico       -> data/niveis_classico.json

Formatos (regras alternando entre house completa com deck do Caio e classico):
    duelos    2 jogadores: cada par de candidatas, alternando quem comeca
    trio      3 jogadores: as tres candidatas juntas, em todas as ordens de assento
    quarteto  4 jogadores: as tres candidatas + uma IA normal, girando os assentos
    calibra.  cada candidata contra IAs normais (forca absoluta)
"""
import argparse
import itertools
import json
import math
import os
import random
import time

from godot_pool import PROJECT, run_matches

CANDS = ["evoluida", "tatica", "mista"]
RULES = ["house", "classico"]
LEVELS = ["muito_dificil", "dificil", "intermediaria"]
LEVEL_NAMES = {"muito_dificil": "IA muito dificil", "dificil": "IA dificil", "intermediaria": "IA intermediaria"}


def mean_ci(xs):
    if not xs:
        return 0.0, 0.0
    m = sum(xs) / len(xs)
    if len(xs) < 2:
        return m, 0.0
    var = sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return m, 1.96 * math.sqrt(var / len(xs))


def orders_for(fmt):
    if fmt == "duelos":
        out = []
        for a, b in itertools.combinations(CANDS, 2):
            out += [[a, b], [b, a]]
        return out
    if fmt == "trio":
        return [list(p) for p in itertools.permutations(CANDS)]
    if fmt == "quarteto":
        return [list(p) for p in itertools.permutations(CANDS + ["normal"])]
    out = []  # calibracao
    for cand in CANDS:
        for n in (2, 3, 4):
            for s in range(n):
                seats = ["normal"] * n
                seats[s] = cand
                out.append(seats)
    return out


def build(fmt, games, rng, rules_list):
    orders = orders_for(fmt)
    out = []
    for i in range(games):
        seats = orders[i % len(orders)]
        rules = rules_list[(i // len(orders)) % len(rules_list)]
        out.append({"rules": rules, "seats": seats, "seed": rng.randrange(1, 2 ** 31)})
    return out


def excess(results, matches, who):
    """Vitoria menos a esperada (1/n), por partida em que 'who' jogou."""
    xs = []
    for r, m in zip(results, matches):
        if who in m["seats"]:
            xs.append(r["win"][m["seats"].index(who)] - 1.0 / len(m["seats"]))
    return xs


def main():
    ap = argparse.ArgumentParser(description="Torneio: evoluida x tatica x mista")
    ap.add_argument("--partidas", type=int, default=2000, help="partidas por formato")
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--godot", default="godot", help="comando do Godot")
    ap.add_argument("--semente", type=int, default=2026)
    ap.add_argument("--sem-gravar", action="store_true")
    ap.add_argument("--modo", choices=["geral", "classico", "house"], default="geral",
                    help="geral = house e classico alternados; classico ou house = so aquele modo")
    args = ap.parse_args()
    rules_list = RULES if args.modo == "geral" else [args.modo]
    suffix = "" if args.modo == "geral" else "_" + args.modo
    print("Modo do torneio: %s" % args.modo)

    evo_file = os.path.join(PROJECT, "data", "ia_evoluida%s.json" % suffix)
    if not os.path.exists(evo_file):
        print("(sem treino especializado para este modo: a evoluida e a mista usam o treino geral)")
        evo_file = os.path.join(PROJECT, "data", "ia_evoluida.json")
    evo = json.load(open(evo_file))
    if not evo.get("params"):
        print("AVISO: data/ia_evoluida.json ainda nao tem parametros evoluidos; a evoluida e a mista"
              " estao iguais a normal e a tatica. Rode antes: python3 tools/evoluir.py\n")
    elif "vantagem_sobre_normal_pp" in evo:
        print("IA evoluida em uso: %+.1f p.p. sobre a normal na validacao do algoritmo genetico.\n"
              % evo["vantagem_sobre_normal_pp"])

    rng = random.Random(args.semente)
    t0 = time.time()
    summary = {}
    head_scores = {c: [] for c in CANDS}  # excesso de vitorias nos formatos entre candidatas
    for fmt in ("duelos", "trio", "quarteto", "calibracao"):
        matches = build(fmt, args.partidas, rng, rules_list)
        res = run_matches(matches, args.godot, args.workers, chunk=25, label=fmt)
        summary[fmt] = {}
        if fmt == "duelos":
            print("  duelos (2 jogadores, % de vitorias da candidata da linha contra a da coluna):" )
            print("  %-10s" % "" + "".join("%12s" % c for c in CANDS))
            for a in CANDS:
                row = "  %-10s" % a
                for b in CANDS:
                    if a == b:
                        row += "%12s" % "-"
                        continue
                    xs = [r["win"][m["seats"].index(a)] for r, m in zip(res, matches)
                          if a in m["seats"] and b in m["seats"]]
                    mm, cc = mean_ci(xs)
                    summary[fmt]["%s_x_%s" % (a, b)] = {"vitorias": mm, "ic": cc}
                    row += "%7.1f%%±%-3.0f" % (100 * mm, 100 * cc)
                print(row)
        if fmt != "calibracao":
            line = []
            for c in CANDS:
                xs = excess(res, matches, c)
                head_scores[c] += xs
                m, ci = mean_ci(xs)
                summary[fmt][c] = {"acima_do_esperado": m, "ic": ci}
                line.append("%s %+5.1f (±%.1f)" % (c, 100 * m, 100 * ci))
            print("  %-9s acima do esperado: %s" % (fmt, " | ".join(line)))
        else:
            for c in CANDS:
                m, ci = mean_ci(excess(res, matches, c))
                summary["calibracao"][c] = {"vantagem_sobre_normal": m, "ic": ci}
                print("  vs normais: %-9s %+5.1f p.p. acima do esperado (±%.1f)" % (c, 100 * m, 100 * ci))

    # classificacao pelos formatos em que as candidatas se enfrentam
    score = {c: mean_ci(head_scores[c]) for c in CANDS}
    ranking = sorted(CANDS, key=lambda c: -score[c][0])
    print("\nTempo: %.0fs" % (time.time() - t0))
    print("Classificacao (media de vitorias acima do esperado nos confrontos diretos):")
    for i, c in enumerate(ranking):
        print("  %do %-9s %+5.1f p.p. (±%.1f)  -> %s" % (i + 1, c, 100 * score[c][0], 100 * score[c][1],
                                                       LEVEL_NAMES[LEVELS[i]]))
    for i in range(2):
        a, b = ranking[i], ranking[i + 1]
        gap = score[a][0] - score[b][0]
        if gap < math.hypot(score[a][1], score[b][1]):
            print("  (%s e %s ficaram estatisticamente empatadas: a ordem entre elas pode ser sorte)" % (a, b))
    if not args.sem_gravar:
        out = {LEVELS[i]: ranking[i] for i in range(3)}
        out["torneio"] = {"partidas_por_formato": args.partidas, "resultado": summary,
                          "data": time.strftime("%Y-%m-%d %H:%M")}
        with open(os.path.join(PROJECT, "data", "niveis%s.json" % suffix), "w") as f:
            json.dump(out, f, indent=2, ensure_ascii=False)
        print("Gravado em data/niveis%s.json. Exporte o jogo de novo para valer nas versoes instaladas." % suffix)


if __name__ == "__main__":
    main()
