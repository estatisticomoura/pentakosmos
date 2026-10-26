#!/usr/bin/env python3
"""Algoritmo genetico para a IA "evoluida" (caminho 2).

Cada individuo e um conjunto de parametros da IA estrategista. Em cada geracao,
todos jogam as MESMAS partidas (mesmas sementes e assentos) contra IAs normais;
a aptidao e quanto o individuo vence acima do esperado (1/n), em pontos
percentuais. Os melhores passam direto (elitismo), os demais nascem de
cruzamento e mutacao. Ao final, o campeao e validado em partidas novas e
gravado em data/ia_evoluida.json, que o jogo le ao iniciar.

Uso (na pasta do projeto):
    python3 tools/evoluir.py                     # 30 geracoes x 16 individuos x 1000 partidas
    python3 tools/evoluir.py --geracoes 50 --partidas 600
    python3 tools/evoluir.py --continuar         # retoma de onde parou
    python3 tools/evoluir.py --modo house        # treino especializado so na house completa
    python3 tools/evoluir.py --modo classico     # treino especializado so nas regras classicas
    python3 tools/evoluir.py --godot "flatpak run org.godotengine.Godot"

Configuracoes das partidas (sorteadas a cada partida, "randomizacao de dominio"):
  - 2 a 5 jogadores, com o individuo girando de assento;
  - metade das partidas nos dois modos principais (house completa e classico);
  - a outra metade com variantes aleatorias: cada house rule ligada ou desligada,
    deck oficial ou do Caio, limite de mao 9/10/11 e meta de 12 a 18 pontos.
Assim os parametros precisam funcionar bem em media em todas as variantes.

No fim ha uma FINAL: os 5 melhores da ultima geracao jogam 3000 partidas novas
cada (as mesmas para todos) e o melhor nessa disputa longa vira o campeao. Isso
evita premiar um individuo que so teve sorte numa avaliacao curta. Depois o
campeao e validado em outras 4000 partidas, e o teste de generalizacao mostra a vantagem do campeao sobre a IA normal
separada por grupo (jogadores, modo, meta, limite de mao, deck...). Um grupo
marcado com "!!" e onde o campeao ficou significativamente PIOR que a normal.
"""
import argparse
import json
import math
import os
import random
import subprocess
import tempfile
import time

from godot_pool import PROJECT, ensure_imported, godot_cmd, run_matches

MODES = ("geral", "classico", "house")


def state_path(mode):
    return os.path.join(PROJECT, "tools", "evolucao_estado%s.json" % ("" if mode == "geral" else "_" + mode))


def output_path(mode):
    return os.path.join(PROJECT, "data", "ia_evoluida%s.json" % ("" if mode == "geral" else "_" + mode))


def load_space(godot):
    ensure_imported(godot)
    out = os.path.join(tempfile.mkdtemp(prefix="pentakosmos_"), "params.json")
    proc = subprocess.run(godot_cmd(godot) + ["--headless", "--path", PROJECT, "--script",
                                              "res://tests/exportar_parametros.gd", "--", out],
                          capture_output=True, text=True)
    if not os.path.exists(out):
        raise SystemExit("O Godot nao gerou os parametros. Saida do Godot:\n%s\n%s" % (
            proc.stdout[-2000:], proc.stderr[-2000:]))
    with open(out) as f:
        d = json.load(f)
    return d["defaults"], d["ranges"], set(d["ints"])


class Space:
    def __init__(self, defaults, ranges, ints):
        self.defaults = defaults
        self.ranges = ranges
        self.ints = ints
        self.keys = sorted(ranges)

    def clip(self, k, v):
        lo, hi = self.ranges[k]
        v = min(max(v, lo), hi)
        return int(round(v)) if k in self.ints else round(float(v), 4)

    def mutate(self, ind, rng, rate, sigma):
        out = dict(ind)
        for k in self.keys:
            if rng.random() < rate:
                lo, hi = self.ranges[k]
                out[k] = self.clip(k, out[k] + rng.gauss(0, sigma * (hi - lo)))
        return out

    def crossover(self, a, b, rng):
        child = {}
        for k in self.keys:
            r = rng.random()
            if r < 0.4:
                child[k] = a[k]
            elif r < 0.8:
                child[k] = b[k]
            else:
                w = rng.random()
                child[k] = self.clip(k, w * a[k] + (1 - w) * b[k])
        return child


def profile(ind):
    return json.dumps({"policy": "plano", "params": ind}, separators=(",", ":"))


CLASSICO = {"gems_mode": "classico", "gold_mode": "classico", "take2_min": 4, "market5": 4,
            "noble_mode": "exato", "noble_points_mode": "fixo", "deck": "oficial",
            "hand_limit": 10, "target": 15, "color_win": 0}
HOUSE = {"gems_mode": "house", "gold_mode": "house", "take2_min": 3, "market5": 5,
         "noble_mode": "flexivel", "noble_points_mode": "decrescente", "deck": "caio",
         "hand_limit": 10, "target": 15, "color_win": 10}
CHOICES = {"gems_mode": ["classico", "house"], "gold_mode": ["classico", "house"], "take2_min": [4, 3],
           "market5": [4, 5], "noble_mode": ["exato", "flexivel"], "noble_points_mode": ["fixo", "decrescente"],
           "deck": ["oficial", "caio"], "hand_limit": [9, 10, 11], "target": list(range(12, 19)),
           "color_win": [0, 0, 9, 10, 11, 12]}


def random_rules(rng):
    return {k: rng.choice(v) for k, v in CHOICES.items()}


def scenarios(n_games, rng, train_mode="geral"):
    """Lista de (regras, jogadores, assento, semente, modo)."""
    out = []
    for i in range(n_games):
        n = 2 + i % 4
        seat = (i // 16) % n
        kind = (i // 4) % 4
        if train_mode == "house":
            kind = 0
        elif train_mode == "classico":
            kind = 1
        if kind == 0:
            rules, mode = dict(HOUSE), "house"
        elif kind == 1:
            rules, mode = dict(CLASSICO), "classico"
        else:
            rules, mode = random_rules(rng), "variante"
        out.append((rules, n, seat, rng.randrange(1, 2 ** 31), mode))
    return out


def evaluate(pop, scen, godot, workers, per_game=False):
    matches, owner = [], []
    for pi, ind in enumerate(pop):
        prof = profile(ind)
        for rules, n, seat, seed, _mode in scen:
            seats = ["normal"] * n
            seats[seat] = prof
            matches.append({"rules": rules, "seats": seats, "seed": seed})
            owner.append((pi, seat, n))
    res = run_matches(matches, godot, workers, chunk=60, label="avaliando")
    if per_game:
        return [r["win"][seat] - 1.0 / n for r, (pi, seat, n) in zip(res, owner)]
    fit = [0.0] * len(pop)
    cnt = [0] * len(pop)
    for r, (pi, seat, n) in zip(res, owner):
        fit[pi] += r["win"][seat] - 1.0 / n
        cnt[pi] += 1
    return [100.0 * f / c for f, c in zip(fit, cnt)]


def mean_ci(xs):
    m = sum(xs) / len(xs)
    if len(xs) < 2:
        return 100 * m, 0.0
    var = sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return 100 * m, 100 * 1.96 * math.sqrt(var / len(xs))


def generalization(per, scen, train_mode="geral"):
    """Vantagem do campeao sobre a IA normal, por grupo de configuracao."""
    def key_funcs():
        yield "jogadores", lambda r, n, m: "%d jogadores" % n
        if train_mode != "geral":
            return
        yield "modo", lambda r, n, m: {"house": "house completa", "classico": "classico", "variante": "variantes"}[m]
        yield "deck", lambda r, n, m: "deck " + r["deck"]
        yield "meta", lambda r, n, m: "meta 12-13" if r["target"] <= 13 else ("meta 17-18" if r["target"] >= 17 else "meta 14-16")
        yield "mao", lambda r, n, m: "mao %d" % r["hand_limit"]
        yield "nobres", lambda r, n, m: "nobres " + ("-2 flexivel" if r["noble_mode"] == "flexivel" else "exatos")
        yield "pegar2", lambda r, n, m: "pegar 2 com %d+" % r["take2_min"]
        yield "especializacao", lambda r, n, m: "especializacao %s" % (r.get("color_win", 0) or "desligada")
    out = {}
    print("\nTeste de generalizacao (vantagem sobre a IA normal, por grupo):")
    for gname, f in key_funcs():
        buckets = {}
        for x, (rules, n, seat, seed, mode) in zip(per, scen):
            buckets.setdefault(f(rules, n, mode), []).append(x)
        line = []
        for k in sorted(buckets):
            m, c = mean_ci(buckets[k])
            flag = " !!" if m + c < 0 else ""
            line.append("%s %+.1f (±%.1f)%s" % (k, m, c, flag))
            out[k] = {"pp": round(m, 2), "ic": round(c, 2), "partidas": len(buckets[k])}
        print("  " + " | ".join(line))
    bad = [k for k, v in out.items() if v["pp"] + v["ic"] < 0]
    if bad:
        print("ATENCAO: o campeao ficou pior que a IA normal em: " + ", ".join(bad) +
              ". Pode valer evoluir um conjunto separado para esse grupo.")
    else:
        print("Nenhum grupo significativamente pior que a IA normal: um unico conjunto de parametros basta.")
    return out


def main():
    ap = argparse.ArgumentParser(description="Algoritmo genetico para a IA evoluida")
    ap.add_argument("--geracoes", type=int, default=30)
    ap.add_argument("--populacao", type=int, default=16)
    ap.add_argument("--partidas", type=int, default=1000, help="partidas por individuo por geracao")
    ap.add_argument("--finalistas", type=int, default=5, help="melhores da ultima geracao que vao para a final")
    ap.add_argument("--final", type=int, default=3000, help="partidas de cada finalista na final")
    ap.add_argument("--elite", type=int, default=4)
    ap.add_argument("--validacao", type=int, default=4000, help="partidas da validacao final")
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--semente", type=int, default=42)
    ap.add_argument("--continuar", action="store_true")
    ap.add_argument("--modo", choices=MODES, default="geral",
                    help="geral = todas as variantes; classico ou house = treino especializado so naquele modo")
    args = ap.parse_args()
    STATE = state_path(args.modo)
    OUTPUT = output_path(args.modo)
    general_file = output_path("geral")
    general = None
    if args.modo != "geral" and os.path.exists(general_file):
        g = json.load(open(general_file))
        if g.get("params"):
            general = g["params"]
    print("Modo de treino: %s" % {"geral": "geral (todas as variantes)", "classico": "so regras classicas (deck oficial)",
                                  "house": "so house completa (deck do Caio)"}[args.modo])

    space = Space(*load_space(args.godot))
    rng = random.Random(args.semente)
    history = []
    start_gen = 0
    finalists = None
    if args.continuar and os.path.exists(STATE):
        st = json.load(open(STATE))
        pop = st["populacao"]
        history = st["historico"]
        start_gen = st["geracao"]
        finalists = st.get("finalistas")
        rng.seed(args.semente + start_gen)
        print("Retomando da geracao %d" % start_gen)
    else:
        base = {k: space.defaults[k] for k in space.keys}
        if general is not None:
            # aproveita o treino geral como ponto de partida
            seed = {k: space.clip(k, general.get(k, base[k])) for k in space.keys}
            print("Populacao inicial: campeao do treino geral + IA normal + variacoes do campeao")
            pop = [seed, base] + [space.mutate(seed, rng, 0.5, 0.10) for _ in range(args.populacao - 2)]
        else:
            pop = [base] + [space.mutate(base, rng, 0.6, 0.15) for _ in range(args.populacao - 1)]

    total = args.geracoes * args.populacao * args.partidas
    print("Algoritmo genetico: %d geracoes x %d individuos x %d partidas = %d partidas | %d processos" % (
        args.geracoes, args.populacao, args.partidas, total, args.workers))
    t0 = time.time()
    best = None
    for gen in range(start_gen, args.geracoes):
        scen = scenarios(args.partidas, rng, args.modo)
        fit = evaluate(pop, scen, args.godot, args.workers)
        order = sorted(range(len(pop)), key=lambda i: -fit[i])
        best = pop[order[0]]
        finalists = [pop[i] for i in order[:args.finalistas]]
        sigma = 0.12 * (1 - gen / max(1, args.geracoes)) + 0.03
        se = 100.0 * 0.43 / math.sqrt(args.partidas)
        history.append({"geracao": gen + 1, "melhor": fit[order[0]], "media": sum(fit) / len(fit)})
        print("Geracao %2d/%d | melhor %+5.1f p.p. | media %+5.1f p.p. | (ruido ~±%.1f) | %.0fs" % (
            gen + 1, args.geracoes, fit[order[0]], sum(fit) / len(fit), 2 * se, time.time() - t0))
        changed = [(k, space.defaults[k], best[k]) for k in space.keys
                   if abs(best[k] - space.defaults[k]) > 1e-9]
        changed.sort(key=lambda x: -abs(x[2] - x[1]) / (space.ranges[x[0]][1] - space.ranges[x[0]][0]))
        print("   maiores mudancas: " + ", ".join("%s %.2f->%.2f" % c for c in changed[:5]))
        # nova geracao
        elite = [pop[i] for i in order[:args.elite]]
        new = [dict(e) for e in elite]

        def pick():
            cands = rng.sample(range(len(pop)), 3)
            return pop[max(cands, key=lambda i: fit[i])]

        while len(new) < args.populacao:
            child = space.crossover(pick(), pick(), rng)
            new.append(space.mutate(child, rng, 0.3, sigma))
        pop = new
        with open(STATE, "w") as f:
            json.dump({"geracao": gen + 1, "populacao": pop, "historico": history,
                       "melhor": best, "finalistas": finalists}, f, indent=1)

    # final: os melhores da ultima geracao jogam muitas partidas (as mesmas para todos)
    if not finalists:
        finalists = pop[:args.finalistas]
    print("\nFINAL: %d finalistas x %d partidas novas..." % (len(finalists), args.final))
    frng = random.Random(args.semente + 555)
    ffit = evaluate(finalists, scenarios(args.final, frng, args.modo), args.godot, args.workers)
    fse = 100.0 * 0.43 / math.sqrt(args.final)
    for i, f in enumerate(ffit):
        print("  finalista %d: %+.1f p.p. (ruido ~±%.1f)" % (i + 1, f, 2 * fse))
    champ = finalists[max(range(len(finalists)), key=lambda i: ffit[i])]

    # validacao do campeao em outras partidas novas
    print("\nValidando o campeao em %d partidas novas..." % args.validacao)
    vrng = random.Random(args.semente + 999)
    vscen = scenarios(args.validacao, vrng, args.modo)
    per = evaluate([champ], vscen, args.godot, args.workers, per_game=True)
    v, ci = mean_ci(per)
    print("Campeao: %+.1f p.p. acima do esperado contra IAs normais (±%.1f)" % (v, ci))
    groups = generalization(per, vscen, args.modo)
    comparison = None
    if general is not None:
        # mesmo conjunto de partidas para o campeao geral: mede o ganho da especializacao
        gper = evaluate([{k: space.clip(k, general.get(k, space.defaults[k])) for k in space.keys}],
                        vscen, args.godot, args.workers, per_game=True)
        gv, gci = mean_ci(gper)
        diff = [a - b for a, b in zip(per, gper)]
        dv, dci = mean_ci(diff)
        print("\nComparacao nas mesmas partidas: especializado %+.1f | geral %+.1f | ganho da especializacao %+.1f p.p. (±%.1f)%s"
              % (v, gv, dv, dci, "  *" if abs(dv) > dci else "  (nao significativo)"))
        comparison = {"especializado_pp": round(v, 2), "geral_pp": round(gv, 2), "ganho_pp": round(dv, 2), "ic": round(dci, 2)}
    out = {"params": champ, "vantagem_sobre_normal_pp": round(v, 2), "geracoes": len(history),
           "modo": args.modo, "comparacao_com_geral": comparison,
           "generalizacao": groups, "historico": history, "data": time.strftime("%Y-%m-%d %H:%M")}
    with open(OUTPUT, "w") as f:
        json.dump(out, f, indent=2)
    print("Gravado em %s. Proximo passo: python3 tools/torneio.py%s" % (
        os.path.relpath(OUTPUT, PROJECT), "" if args.modo == "geral" else " --modo " + args.modo))


if __name__ == "__main__":
    main()
