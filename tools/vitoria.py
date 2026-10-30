#!/usr/bin/env python3
"""Compara as duas regras de quem vence quando ha especializacao (usado pelo tools/noite.py).

  especialista  versao 1.4: quem cumpriu a especializacao fica acima de todos
  indice        nova: vence a maior fracao da propria meta, de pontos (pontos / meta) ou de
                especializacao (pontos no melhor elemento / meta de especializacao)

As mesmas partidas (mesmas sementes e assentos) sao jogadas com as duas regras, sempre com a
vitoria por especializacao ligada. Mede quantas partidas sao vencidas por cada caminho, quantas
mudam de vencedor, se a IA mais forte continua vencendo e quanto a partida dura.
"""
import math
import random

import sanidade

REGRAS = ["especialista", "indice"]
NOMES_IA = {"muito_dificil": "Timeu", "dificil": "Teeteto", "normal": "estrategista", "facil": "Lisis"}


def montar(rng, combos, por_combo):
    jogos = []
    for ci in range(combos):
        regras = sanidade.regras_aleatorias(rng)
        if not regras["color_win"]:
            regras["color_win"] = rng.choice([9, 10, 11, 12])
        for k in range(por_combo):
            semente = rng.randrange(1, 2 ** 31)
            if k % 2 == 0:
                base = ["muito_dificil", "normal", "facil"]
            else:
                base = ["muito_dificil", "dificil", "normal", "facil"]
            s = (k // 2) % len(base)
            seats = base[s:] + base[:s]
            for regra in REGRAS:
                jogos.append(({"combo": ci, "seed": semente, "regra": regra, "seats": seats},
                              {"rules": dict(regras, victory=regra), "seats": seats, "seed": semente}))
    return jogos


def _caminho(st):
    """'esp' se a melhor fracao da meta do jogador vem da especializacao, senao 'pts'."""
    if st.get("spec", 0) <= 0:
        return "pts"
    return "esp" if st["color_best"] / st["spec"] > st["_pts"] / max(1, st["target"]) else "pts"


def acumular(dados, jogos, res):
    pares = {}
    for (info, _j), r in zip(jogos, res):
        sts = r["stats"]
        for i, st in enumerate(sts):
            st["_pts"] = r["points"][i]
        venc = [i for i, v in enumerate(r["win"]) if v > 0]
        esp_chegou = [i for i, st in enumerate(sts) if st["spec"] > 0 and st["color_best"] >= st["spec"]]
        pts_chegou = [i for i, st in enumerate(sts) if r["points"][i] >= st["target"]]
        reg = {
            "venc": venc,
            "caminho": [_caminho(sts[i]) for i in venc],
            "conflito": bool(esp_chegou) and any(i not in esp_chegou for i in pts_chegou),
            "esp_venceu_conflito": any(i in esp_chegou for i in venc),
            "ias": [info["seats"][i] for i in venc],
            "win": r["win"], "seats": info["seats"], "rodadas": r["rounds"],
        }
        pares.setdefault((info["combo"], info["seed"]), {})[info["regra"]] = reg
    for p in pares.values():
        if all(x in p for x in REGRAS):
            dados.setdefault("vitoria", []).append(p)


def _pct(xs):
    if not xs:
        return 0.0, 0.0
    m = sum(xs) / len(xs)
    return 100 * m, 100 * 1.96 * math.sqrt(max(m * (1 - m), 1e-9) / len(xs))


def relatorio(dados):
    pares = dados.get("vitoria", [])
    if not pares:
        return []
    out = ["", "=" * 100, "REGRA DE VITORIA: especialista (1.4) x indice (fracao da propria meta)",
           "%d partidas, cada uma jogada com as duas regras (mesmas sementes e assentos)." % len(pares), ""]
    for regra in REGRAS:
        rs = [p[regra] for p in pares]
        esp = _pct([1.0 if "esp" in r["caminho"] else 0.0 for r in rs])
        conf = [r for r in rs if r["conflito"]]
        espc = _pct([1.0 if r["esp_venceu_conflito"] else 0.0 for r in conf])
        rod = sum(r["rodadas"] for r in rs) / len(rs)
        out.append("%-13s vencidas pela especializacao %5.1f%% (±%.1f) | conflitos (alguem especializou e outro chegou a meta"
                   " de pontos): %d, a especializacao venceu %5.1f%% (±%.1f) | rodadas %.1f"
                   % (regra, esp[0], esp[1], len(conf), espc[0], espc[1], rod))
        linha = []
        for ia, nome in NOMES_IA.items():
            xs = [r["win"][r["seats"].index(ia)] for r in rs if ia in r["seats"]]
            if xs:
                linha.append("%s %.1f%%" % (nome, 100 * sum(xs) / len(xs)))
        out.append("              vitorias por IA: " + " | ".join(linha))
    mud = _pct([1.0 if p["especialista"]["venc"] != p["indice"]["venc"] else 0.0 for p in pares])
    out.append("")
    out.append("Partidas em que o vencedor muda de uma regra para a outra: %.1f%% (±%.1f)." % mud)
    out.append("(Parte da mudanca vem de as IAs jogarem diferente sob cada regra, nao so da contagem final.)")
    return out
