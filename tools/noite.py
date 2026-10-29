#!/usr/bin/env python3
"""Treino noturno da IA: teste A/B entre a heuristica NOVA e a ATUAL (versao 1.4).

Roda na sua maquina, pelo tempo que voce mandar. Em rodadas, sorteia combinacoes de regras
(inclusive escritores, governantes e metas de 8 a 30 pontos) e, em cada uma, joga as MESMAS
partidas (mesmas sementes e assentos) duas vezes: uma com a IA nova e outra com a atual. Como as
partidas sao pareadas, a diferenca entre as duas sai com muito menos ruido.

Testa dois niveis: o estrategista (IA normal) e o mais forte (Timeu, com negacao e busca no fim
de jogo). Para cada um mede, com intervalo de confianca de 95%:
  - vitorias contra adversarios fixos (a IA facil e a normal, sempre na versao atual);
  - duelos diretos: nova contra atual;
  - fichas devolvidas por passar do limite da mao, a cada 10 vezes;
  - duracao das partidas, em rodadas.
E mostra tudo isso por regra (meta, mao, deck, governantes...), marcando o que mudou de verdade.

Uso (na pasta do projeto):
    python3 tools/noite.py                 # 8 horas
    python3 tools/noite.py --horas 1       # teste curto
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


def perfil(base, antiga):
    d = {"base": base}
    if antiga:
        d["legacy"] = True
    return json.dumps(d, separators=(",", ":"))


FACIL = perfil("facil", True)
NORMAL = perfil("normal", True)


def montar_rodada(combos, rng, por_combo):
    """Partidas de uma rodada. Cada item: (info, partida)."""
    jogos = []
    for ci, (nome, regras) in enumerate(combos):
        for nivel in NIVEIS:
            for k in range(por_combo):
                semente = rng.randrange(1, 2 ** 31)
                # pareadas: o mesmo jogo com a IA nova e com a atual no assento X
                if k % 2 == 0:
                    base = ["X", FACIL] if (k // 2) % 2 == 0 else [FACIL, "X"]
                else:
                    trio = ["X", NORMAL, FACIL]
                    s = (k // 2) % 3
                    base = trio[s:] + trio[:s]
                for versao in ("nova", "atual"):
                    seats = [perfil(nivel, versao == "atual") if x == "X" else x for x in base]
                    jogos.append(({"combo": ci, "nivel": nivel, "tipo": "pareada", "versao": versao, "par": k,
                                   "x": base.index("X")}, {"rules": regras, "seats": seats, "seed": semente}))
            # duelos diretos nova x atual, alternando quem comeca
            for k in range(2):
                semente = rng.randrange(1, 2 ** 31)
                seats = [perfil(nivel, False), perfil(nivel, True)]
                if k == 1:
                    seats.reverse()
                jogos.append(({"combo": ci, "nivel": nivel, "tipo": "duelo", "nova": seats.index(perfil(nivel, False))},
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
    """Junta os resultados da rodada em `dados` (registros simples, que viram o relatorio)."""
    pares = {}
    for (info, jogo), r in zip(jogos, res):
        regras = combos[info["combo"]][1]
        if info["tipo"] == "duelo":
            dados["duelos"].append({"nivel": info["nivel"], "regras": regras, "v": r["win"][info["nova"]]})
            continue
        x = info["x"]
        st = r["stats"][x]
        chave = (info["combo"], info["nivel"], info["par"], jogo["seed"])
        pares.setdefault(chave, {})[info["versao"]] = {
            "v": r["win"][x], "desc": 10.0 * st["discards"] / max(1, st["turns"]),
            "rod": r["rounds"], "trav": 0 if r.get("finished", True) else 1, "regras": regras, "nivel": info["nivel"]}
    for p in pares.values():
        if "nova" in p and "atual" in p:
            dados["pares"].append({"nivel": p["nova"]["nivel"], "regras": p["nova"]["regras"],
                                   "nova": {k: p["nova"][k] for k in ("v", "desc", "rod", "trav")},
                                   "atual": {k: p["atual"][k] for k in ("v", "desc", "rod", "trav")}})


def linha(rotulo, pares, duelos):
    dv = [p["nova"]["v"] - p["atual"]["v"] for p in pares]
    dd = [p["nova"]["desc"] - p["atual"]["desc"] for p in pares]
    m_v, ic_v = media_ic(dv)
    m_d, ic_d = media_ic(dd)
    m_du, ic_du = media_ic([d["v"] for d in duelos])
    vn = 100 * sum(p["nova"]["v"] for p in pares) / max(1, len(pares))
    va = 100 * sum(p["atual"]["v"] for p in pares) / max(1, len(pares))
    dn = sum(p["nova"]["desc"] for p in pares) / max(1, len(pares))
    da = sum(p["atual"]["desc"] for p in pares) / max(1, len(pares))
    rn = sum(p["nova"]["rod"] for p in pares) / max(1, len(pares))
    ra = sum(p["atual"]["rod"] for p in pares) / max(1, len(pares))
    marca = ""
    if len(pares) < 30:
        return ("%-32s %5d | poucas partidas ainda" % (rotulo, len(pares)))
    if m_v - ic_v > 0:
        marca = " melhor"
    elif m_v + ic_v < 0:
        marca = " !! PIOR"
    if len(duelos) < 20:
        pass
    elif m_du - ic_du > 0.5:
        marca += " (vence a atual)"
    elif m_du + ic_du < 0.5:
        marca += " !! (perde para a atual)"
    return ("%-32s %5d | vitorias %4.1f%% > %4.1f%% (%+5.1f ±%4.1f) | duelo %4.0f%% ±%3.0f | devolvidas %.2f > %.2f (%+.2f ±%.2f) | rodadas %.1f > %.1f%s"
            % (rotulo, len(pares), va, vn, 100 * m_v, 100 * ic_v, 100 * m_du, 100 * ic_du, da, dn, m_d, ic_d, ra, rn, marca))


def relatorio(dados, inicio, rodadas, args):
    out = []
    w = out.append
    horas = (time.time() - inicio) / 3600
    w("PENTAKOSMOS - TESTE A/B DA IA (heuristica nova x atual)")
    w("Data: %s | %.1f horas | %d rodadas | %d partidas pareadas + %d duelos | %d processos"
      % (time.strftime("%Y-%m-%d %H:%M"), horas, rodadas, 2 * len(dados["pares"]), len(dados["duelos"]), args.workers))
    w("")
    w("Como ler: 'vitorias A > N' = taxa de vitorias da IA atual > da nova, nas mesmas partidas, contra a IA facil")
    w("e a normal (versao atual). Entre parenteses, a diferenca nova - atual e o intervalo de 95%.")
    w("'duelo' = vitorias da nova contra a atual, frente a frente (50% = empate). 'devolvidas' = fichas devolvidas")
    w("por passar do limite da mao, a cada 10 vezes. 'melhor' / '!! PIOR' so aparecem quando a diferenca e real.")
    for nivel, nome in NIVEIS.items():
        pares = [p for p in dados["pares"] if p["nivel"] == nivel]
        duelos = [d for d in dados["duelos"] if d["nivel"] == nivel]
        if not pares:
            continue
        w("")
        w("=== %s ===" % nome.upper())
        w(linha("GERAL", pares, duelos))
        grupos = {}
        for p in pares:
            for g in sanidade.grupos_de(p["regras"]):
                grupos.setdefault(g, [[], []])[0].append(p)
        for d in duelos:
            for g in sanidade.grupos_de(d["regras"]):
                grupos.setdefault(g, [[], []])[1].append(d)
        for g in sorted(grupos):
            w(linha(g, *grupos[g]))
        trav = sum(p["nova"]["trav"] for p in pares)
        if trav:
            w("!! %d partidas da IA nova nao terminaram" % trav)
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Treino noturno: teste A/B da IA")
    ap.add_argument("--horas", type=float, default=8.0)
    ap.add_argument("--combos", type=int, default=30, help="combinacoes de regras por rodada")
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
