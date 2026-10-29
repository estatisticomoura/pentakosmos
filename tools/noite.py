#!/usr/bin/env python3
"""Treino noturno da IA: roda tudo em sequencia, dentro de um limite de horas.

  1. Bateria de sanidade ANTES (onde a IA joga mal, com regras sorteadas).
  2. Algoritmo genetico do treino geral (regras sorteadas, inclusive escritores e governantes).
  3. Torneio do treino geral (decide quem e Fedro, Teeteto e Timeu).
  4. Se sobrar tempo: treinos especializados das regras Pentakosmos e Arcaico, com seus torneios.
  5. Bateria de sanidade DEPOIS, nas mesmas regras e partidas da primeira, e a comparacao.

O tamanho de cada etapa e calculado pela velocidade da sua maquina (medida na etapa 1), para
caber nas horas pedidas. Tudo o que aparece na tela tambem vai para tools/noite/<data>.txt.
De manha, me mande esse arquivo e os arquivos que mudaram em data/ (ia_evoluida*.json e
niveis*.json).

Uso (na pasta do projeto):
    python3 tools/noite.py                 # 8 horas
    python3 tools/noite.py --horas 6
    python3 tools/noite.py --so-geral      # sem os treinos especializados
    python3 tools/noite.py --godot "flatpak run org.godotengine.Godot"

Pode desligar a tela; so nao deixe o computador suspender. No Debian/GNOME:
    systemd-inhibit --what=idle:sleep python3 tools/noite.py
"""
import argparse
import io
import os
import shlex
import subprocess
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import sanidade  # noqa: E402
from godot_pool import PROJECT  # noqa: E402

PASTA = os.path.join(PROJECT, "tools", "noite")


class Tee(io.TextIOBase):
    def __init__(self, *streams):
        self.streams = streams

    def write(self, s):
        for st in self.streams:
            st.write(s)
            st.flush()
        return len(s)

    def flush(self):
        for st in self.streams:
            st.flush()


def rodar(cmd, log):
    """Roda um passo (outro script em Python) mostrando a saida na tela e no registro."""
    print("\n$ " + " ".join(shlex.quote(c) for c in cmd))
    proc = subprocess.Popen(cmd, cwd=PROJECT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    for linha in proc.stdout:
        sys.stdout.write(linha)
    proc.wait()
    if proc.returncode != 0:
        print("!! o passo terminou com erro (codigo %d); sigo para o proximo." % proc.returncode)
    return proc.returncode == 0


def plano_ga(segundos, vel):
    """Escolhe geracoes e partidas do algoritmo genetico para caber em `segundos`.
    vel = partidas por segundo das IAs do treino (estimada)."""
    pop, fin, nfin = 16, 1500, 5
    for partidas in (1000, 800, 600, 400, 300):
        val = 2 * partidas
        fixo = (fin * nfin + val) / vel
        resto = segundos - fixo
        if resto <= 0:
            continue
        ger = int(resto * vel / (pop * partidas))
        if ger >= 12:
            return {"geracoes": min(ger, 60), "partidas": partidas, "final": fin, "validacao": val}
    return {"geracoes": 8, "partidas": 250, "final": 800, "validacao": 600}


def main():
    ap = argparse.ArgumentParser(description="Treino noturno da IA")
    ap.add_argument("--horas", type=float, default=8.0)
    ap.add_argument("--so-geral", action="store_true", help="so o treino geral (sem Pentakosmos e Arcaico)")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 1)
    args = ap.parse_args()

    os.makedirs(PASTA, exist_ok=True)
    nome = time.strftime("%Y%m%d-%H%M")
    log = open(os.path.join(PASTA, nome + ".txt"), "w", encoding="utf-8")
    sys.stdout = Tee(sys.__stdout__, log)
    t0 = time.time()
    fim = t0 + args.horas * 3600
    py = sys.executable
    comum = ["--godot", args.godot, "--workers", str(args.workers)]
    print("Treino noturno da IA | %d processos | limite de %.1f horas | inicio %s"
          % (args.workers, args.horas, time.strftime("%H:%M")))

    # 1) sanidade antes
    print("\n=== 1. Bateria de sanidade (antes) ===")
    antes = sanidade.rodar(100, 8, godot=args.godot, workers=args.workers, rotulo="antes")
    sanidade.imprimir(antes)
    vel_sanidade = antes["partidas_por_segundo"]
    # as partidas do treino (IAs sem busca no fim de jogo) sao bem mais rapidas que as da sanidade
    vel = vel_sanidade * 2.5
    t_sanidade = antes["minutos"] * 60
    print("\nVelocidade: %.1f partidas/s na sanidade (estimativa para o treino: %.1f/s)" % (vel_sanidade, vel))

    # orcamento: reserva a sanidade final e os torneios
    modos = ["geral"] if args.so_geral else ["geral", "house", "classico"]
    pesos = {"geral": 0.5, "house": 0.3, "classico": 0.2} if len(modos) == 3 else {"geral": 1.0}
    disponivel = fim - time.time() - t_sanidade * 1.1
    torneio_partidas = 1200 if vel_sanidade > 3 else 600
    t_torneio = 4 * torneio_partidas / max(vel_sanidade, 0.1)
    for modo in modos:
        restante = fim - time.time() - t_sanidade * 1.1
        orc = min(disponivel * pesos[modo], restante) - t_torneio
        if orc < 1800:
            print("\nSem tempo para o treino %s (faltariam %.0f min); pulando." % (modo, orc / 60))
            continue
        pl = plano_ga(orc, vel)
        print("\n=== 2. Treino %s: %d geracoes x 16 x %d partidas (~%.1f h) ==="
              % (modo, pl["geracoes"], pl["partidas"], orc / 3600))
        rodar([py, os.path.join(AQUI, "evoluir.py"), "--modo", modo, "--geracoes", str(pl["geracoes"]),
               "--partidas", str(pl["partidas"]), "--final", str(pl["final"]), "--validacao", str(pl["validacao"])]
              + comum, log)
        print("\n=== 3. Torneio %s ===" % modo)
        rodar([py, os.path.join(AQUI, "torneio.py"), "--modo", modo, "--partidas", str(torneio_partidas)] + comum, log)

    # 5) sanidade depois, nas mesmas regras e sementes
    print("\n=== 4. Bateria de sanidade (depois) ===")
    depois = sanidade.rodar(100, 8, godot=args.godot, workers=args.workers, rotulo="depois")
    sanidade.imprimir(depois)
    print("\n=== Comparacao antes > depois ===")
    sanidade.comparar(antes, depois)
    print("\nTerminado em %.1f horas. Registro: %s" % ((time.time() - t0) / 3600, os.path.relpath(log.name, PROJECT)))
    print("Mande para o Claude: esse registro e os arquivos data/ia_evoluida*.json e data/niveis*.json.")


if __name__ == "__main__":
    main()
