#!/usr/bin/env python3
"""Treino noturno da IA: teste A/B entre a heuristica NOVA e a ATUAL (versao 1.4), com ablacao.

Roda na sua maquina, pelo tempo que voce mandar. Em rodadas, sorteia combinacoes de regras
(inclusive escritores, governantes e metas de 8 a 30 pontos) e, em cada uma, joga as MESMAS
partidas (mesmas sementes e assentos) com varias versoes da IA no mesmo assento:

  atual                 a heuristica da versao 1.4
  nova                  todas as novidades ligadas
  nova sem <novidade>   todas menos uma (ablacao: mostra qual novidade ajuda e qual atrapalha)

As novidades: fase (o quanto falta da partida, pelo jogador mais adiantado), mao (guardar fichas
vale menos com a mao cheia), desperdicio (penalidade por pegar fichas que teriam de voltar),
governantes (cartas que aproximam de um governante livre) e fimdejogo (busca ativada por
proporcao da meta; so no Timeu).

Testa dois niveis: o estrategista (IA normal) e o mais forte (Timeu). Os adversarios sao fixos
(IA facil e IA normal da versao 1.4). Como as partidas sao pareadas, as diferencas saem com
muito menos ruido, e cada uma vem com o intervalo de confianca de 95%.

Uso (na pasta do projeto):
    python3 tools/noite.py                 # 8 horas
    python3 tools/noite.py --horas 0.25    # teste curto
    python3 tools/noite.py --godot "flatpak run org.godotengine.Godot"

Para o computador nao suspender durante a noite (Debian):
    systemd-inhibit --what=idle:sleep python3 tools/noite.py --horas 8

O relatorio e reescrito a cada rodada em tools/noite/<data>.txt (e os dados em .json): se voce
interromper (Ctrl+C) ou faltar luz, o que ja rodou esta salvo. De manha, mande o .txt ao Claude.
"""
import argparse
import json
import math
import os
import random
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import sanidade  # noqa: E402
from godot_pool import PROJECT, run_matches  # noqa: E402

PASTA = os.path.join(PROJECT, "tools", "noite")
NIVEIS = {"normal": "estrategista (IA normal)", "muito_dificil": "mais forte (Timeu)"}
NOVIDADES = ["fase", "mao", "desperdicio", "governantes", "fimdejogo"]
MIN_PARTIDAS = 30


def perfil(base, legacy=False, sem=()):
    d = {"base": base}
    if legacy:
        d["legacy"] = True
    if sem:
        d["sem"] = list(sem)
    return json.dumps(d, separators=(",", ":"))


FACIL = perfil("facil", True)
NORMAL = perfil("normal", True)


def variantes(nivel):
    out = [("atual", perfil(nivel, True)), ("nova", perfil(nivel))]
    for f in NOVIDADES:
        if f == "fimdejogo" and nivel != "muito_dificil":
            continue  # so o Timeu usa a busca no fim de jogo
        out.append(("sem " + f, perfil(nivel, sem=[f])))
    return out


def montar_rodada(combos, rng, por_combo):
    jogos = []
    for ci, (_nome, regras) in enumerate(combos):
        for nivel in NIVEIS:
            vs = variantes(nivel)
            for k in range(por_combo):
                semente = rng.randrange(1, 2 ** 31)
                if k % 2 == 0:
                    base = ["X", FACIL] if (k // 2) % 2 == 0 else [FACIL, "X"]
                else:
                    trio = ["X", NORMAL, FACIL]
                    s = (k // 2) % 3
                    base = trio[s:] + trio[:s]
                for nome, prof in vs:
                    seats = [prof if x == "X" else x for x in base]
                    jogos.append(({"combo": ci, "nivel": nivel, "tipo": "pareada", "variante": nome,
                                   "x": base.index("X"), "seed": semente},
                                  {"rules": regras, "seats": seats, "seed": semente}))
            for k in range(2):
                semente = rng.randrange(1, 2 ** 31)
                seats = [perfil(nivel), perfil(nivel, True)]
                if k == 1:
                    seats.reverse()
                jogos.append(({"combo": ci, "nivel": nivel, "tipo": "duelo", "nova": seats.index(perfil(nivel))},
                              {"rules": regras, "seats": seats, "seed": semente}))
    return jogos


def media_ic(xs):
    if not xs:
        return 0.0, 0.0
    m = sum(xs) / len(xs)
    if len(xs) < 2:
        return m, 0.0
    v = sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return m, 1.96 * math.sqrt(v / len(xs))


def acumular(dados, jogos, res, combos):
    grupos = {}
    for (info, _jogo), r in zip(jogos, res):
        regras = combos[info["combo"]][1]
        if info["tipo"] == "duelo":
            dados["duelos"].append({"nivel": info["nivel"], "regras": regras, "v": r["win"][info["nova"]]})
            continue
        st = r["stats"][info["x"]]
        g = grupos.setdefault((info["combo"], info["nivel"], info["seed"]),
                              {"nivel": info["nivel"], "regras": regras, "r": {}})
        g["r"][info["variante"]] = [r["win"][info["x"]], round(10.0 * st["discards"] / max(1, st["turns"]), 3),
                                    r["rounds"], 0 if r.get("finished", True) else 1]
    dados["pares"].extend(grupos.values())


def dif(pares, a, b, i=0):
    """Diferenca media (a - b) no indice i (0 = vitoria, 1 = devolvidas) e intervalo de 95%."""
    xs = [p["r"][a][i] - p["r"][b][i] for p in pares if a in p["r"] and b in p["r"]]
    return media_ic(xs) + (len(xs),)


def sig(m, ic, n):
    if n < MIN_PARTIDAS:
        return " "
    return "+" if m - ic > 0 else ("-" if m + ic < 0 else " ")


def relatorio(dados, inicio, rodadas, args):
    out = []
    w = out.append
    w("PENTAKOSMOS - TESTE A/B DA IA COM ABLACAO (heuristica nova x atual)")
    w("Data: %s | %.1f horas | %d rodadas | %d jogos pareados + %d duelos | %d processos"
      % (time.strftime("%Y-%m-%d %H:%M"), (time.time() - inicio) / 3600, rodadas, len(dados["pares"]),
         len(dados["duelos"]), args.workers))
    w("")
    w("Como ler: vitorias contra adversarios fixos (IA facil e normal da 1.4), nas mesmas partidas para todas as")
    w("variantes. 'vs atual' e 'vs nova' = diferenca em pontos percentuais e intervalo de 95%; '+' ou '-' no fim")
    w("marca diferenca real. Uma 'sem X' acima da 'nova' quer dizer que a novidade X atrapalha.")
    w("'devolv.' = fichas devolvidas por passar do limite da mao, a cada 10 vezes.")
    for nivel, nome in NIVEIS.items():
        pares = [p for p in dados["pares"] if p["nivel"] == nivel]
        duelos = [d for d in dados["duelos"] if d["nivel"] == nivel]
        if not pares:
            continue
        nomes = [v for v, _ in variantes(nivel)]
        w("")
        w("=" * 100)
        w(nome.upper())
        w("%-20s %8s %20s %20s %8s %8s" % ("variante", "vitorias", "vs atual", "vs nova", "devolv.", "rodadas"))
        for v in nomes:
            xs = [p["r"][v] for p in pares if v in p["r"]]
            if not xs:
                continue
            wa = dif(pares, v, "atual")
            wn = dif(pares, v, "nova")
            w("%-20s %7.1f%% %+8.1f ±%4.1f %s %+8.1f ±%4.1f %s %8.2f %8.1f"
              % (v, 100 * sum(x[0] for x in xs) / len(xs), 100 * wa[0], 100 * wa[1], sig(*wa),
                 100 * wn[0], 100 * wn[1], sig(*wn), sum(x[1] for x in xs) / len(xs), sum(x[2] for x in xs) / len(xs)))
        m, ic = media_ic([d["v"] for d in duelos])
        w("Duelos nova x atual: a nova vence %.1f%% (±%.1f) em %d duelos" % (100 * m, 100 * ic, len(duelos)))
        trav = sum(x[3] for p in pares for x in p["r"].values())
        if trav:
            w("!! %d partidas nao terminaram" % trav)
        # por regra: nova - atual, e quanto cada 'sem X' muda em relacao a nova
        sem = [v for v in nomes if v.startswith("sem ")]
        w("")
        w("Por regra (pontos percentuais; 'nova-atual' e, para cada novidade, 'sem X' - 'nova'):")
        w("%-32s %6s %14s %8s " % ("grupo", "jogos", "nova-atual", "duelo") + "".join("%18s" % v for v in sem))
        grupos = {}
        for p in pares:
            for g in sanidade.grupos_de(p["regras"]):
                grupos.setdefault(g, [[], []])[0].append(p)
        for d in duelos:
            for g in sanidade.grupos_de(d["regras"]):
                grupos.setdefault(g, [[], []])[1].append(d)
        for g in sorted(grupos):
            ps, ds = grupos[g]
            na = dif(ps, "nova", "atual")
            md, icd = media_ic([d["v"] for d in ds])
            cel = "".join("%+11.1f±%4.1f%s " % (100 * x[0], 100 * x[1], sig(*x)) for x in (dif(ps, v, "nova") for v in sem))
            w("%-32s %6d %+7.1f±%4.1f%s %6.0f%% " % (g, len(ps), 100 * na[0], 100 * na[1], sig(*na), 100 * md) + cel)
    w("")
    w("Atencao: com dezenas de grupos, alguns '+' ou '-' aparecem por acaso (comparacoes multiplas).")
    w("Confie mais no GERAL e em padroes que se repetem em varios grupos.")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Treino noturno: teste A/B da IA com ablacao")
    ap.add_argument("--horas", type=float, default=8.0)
    ap.add_argument("--combos", type=int, default=20, help="combinacoes de regras por rodada")
    ap.add_argument("--partidas", type=int, default=6, help="partidas pareadas por combinacao e nivel")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--semente", type=int, default=0, help="0 = muda a cada noite")
    args = ap.parse_args()

    os.makedirs(PASTA, exist_ok=True)
    nome = time.strftime("%Y%m%d-%H%M")
    txt = os.path.join(PASTA, nome + ".txt")
    js = os.path.join(PASTA, nome + ".json")
    rng = random.Random(args.semente or int(time.time()))
    inicio = time.time()
    fim = inicio + args.horas * 3600
    dados = {"pares": [], "duelos": []}
    rodadas = 0
    duracao = 0.0
    print("Teste A/B da IA | %d processos | ate %s | relatorio: %s"
          % (args.workers, time.strftime("%H:%M", time.localtime(fim)), os.path.relpath(txt, PROJECT)))
    try:
        while time.time() + duracao < fim or rodadas == 0:
            combos = [("aleatoria", sanidade.regras_aleatorias(rng)) for _ in range(args.combos)]
            if rodadas == 0:
                combos = list(sanidade.FIXAS) + combos
            jogos = montar_rodada(combos, rng, args.partidas)
            t = time.time()
            res = run_matches([j for _, j in jogos], args.godot, args.workers, chunk=12,
                              label="rodada %d" % (rodadas + 1))
            duracao = time.time() - t
            acumular(dados, jogos, res, combos)
            rodadas += 1
            rel = relatorio(dados, inicio, rodadas, args)
            with open(txt, "w", encoding="utf-8") as f:
                f.write(rel)
            with open(js, "w", encoding="utf-8") as f:
                json.dump(dados, f)
            print("Rodada %d em %.0f min. Relatorio atualizado." % (rodadas, duracao / 60))
    except KeyboardInterrupt:
        print("\nInterrompido. O relatorio tem tudo ate a ultima rodada completa.")
    print("\n" + relatorio(dados, inicio, rodadas, args))
    print("Mande ao Claude o arquivo %s" % os.path.relpath(txt, PROJECT))


if __name__ == "__main__":
    main()
