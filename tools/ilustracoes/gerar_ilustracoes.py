#!/usr/bin/env python3
"""Gera as ilustracoes do Pentakosmos em lote pela API de imagens da OpenAI.

So usa a biblioteca padrao do Python 3: nao precisa instalar nada.

Uso rapido (na pasta do projeto):
    export OPENAI_API_KEY="sk-..."                      # a sua chave da API
    python3 tools/ilustracoes/gerar_ilustracoes.py --lista      # mostra o que sera gerado, sem gastar
    python3 tools/ilustracoes/gerar_ilustracoes.py --teste 3    # gera so as 3 primeiras, para ver o estilo e o custo
    python3 tools/ilustracoes/gerar_ilustracoes.py              # gera todas (retoma de onde parou)

Tudo vai para build/ilustracoes/ (ou --saida). Imagens ja geradas sao puladas, entao da para
interromper (Ctrl+C) e rodar de novo. No fim, abra build/ilustracoes/galeria.html no navegador
para comparar as versoes.

Detalhes em tools/ilustracoes/LEIA-ME.md.
"""
import argparse
import base64
import csv
import getpass
import html
import json
import os
import random
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.dirname(os.path.dirname(AQUI))
ESTILO = os.path.join(AQUI, "estilo.txt")
PROMPTS_BASE = os.path.join(AQUI, "prompts.csv")
PROMPTS_EXPANSAO = os.path.join(PROJETO, "expansao", "ilustracoes.csv")

# Precos por 1 milhao de tokens (US$), conferidos em outubro de 2026.
# Se a OpenAI mudar a tabela, ajuste aqui ou use --preco-saida / --preco-entrada.
PRECO_ENTRADA_TEXTO = 5.00
PRECO_SAIDA_IMAGEM = 30.00

_trava = threading.Lock()


def ler_prompts(caminhos):
    itens = []
    for cam in caminhos:
        with open(cam, encoding="utf-8", newline="") as f:
            for linha in csv.DictReader(f):
                arq = (linha.get("arquivo") or "").strip()
                pr = (linha.get("prompt") or "").strip()
                if not arq or not pr or arq.startswith("#"):
                    continue
                itens.append({"arquivo": arq, "prompt": pr,
                              "tamanho": (linha.get("tamanho") or "").strip()})
    return itens


def montar_prompt(estilo, item):
    return estilo.strip() + "\n\nSCENE:\n" + item["prompt"]


def chamar_api(chave, url_base, corpo, tentativas=6):
    dados = json.dumps(corpo).encode("utf-8")
    espera = 5.0
    for t in range(tentativas):
        req = urllib.request.Request(url_base.rstrip("/") + "/images/generations", data=dados, method="POST",
                                     headers={"Authorization": "Bearer " + chave,
                                              "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=600) as r:
                return json.loads(r.read().decode("utf-8")), None
        except urllib.error.HTTPError as e:
            try:
                msg = json.loads(e.read().decode("utf-8")).get("error", {}).get("message", "")
            except Exception:
                msg = ""
            if e.code in (429, 500, 502, 503, 504) and t < tentativas - 1:
                if "quota" in msg.lower() or "billing" in msg.lower():
                    return None, "sem credito na conta da API: " + msg
                time.sleep(espera + random.random() * 2)
                espera = min(espera * 2, 120)
                continue
            return None, "erro %d: %s" % (e.code, msg or e.reason)
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            if t < tentativas - 1:
                time.sleep(espera)
                espera = min(espera * 2, 120)
                continue
            return None, "sem conexao: %s" % e
    return None, "desisti depois de %d tentativas" % tentativas


def custo(uso, args):
    if not uso:
        return 0.0
    ent = uso.get("input_tokens", 0) or 0
    sai = uso.get("output_tokens", 0) or 0
    return ent * args.preco_entrada / 1e6 + sai * args.preco_saida / 1e6


def caminho_saida(args, item, v):
    base = os.path.join(args.saida, item["arquivo"])
    ext = "." + args.formato
    return base + ("_v%d" % v if args.versoes > 1 else "") + ext


def gerar_uma(chave, args, estilo, item, v, estado):
    destino = caminho_saida(args, item, v)
    corpo = {"model": args.modelo, "prompt": montar_prompt(estilo, item),
             "size": item["tamanho"] or args.tamanho, "quality": args.qualidade,
             "output_format": args.formato, "n": 1}
    if args.formato in ("webp", "jpeg"):
        corpo["output_compression"] = args.compressao
    resp, erro = chamar_api(chave, args.url_base, corpo)
    if erro:
        return destino, erro, 0.0
    try:
        img = base64.b64decode(resp["data"][0]["b64_json"])
    except (KeyError, IndexError, TypeError):
        return destino, "resposta sem imagem", 0.0
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    tmp = destino + ".parcial"
    with open(tmp, "wb") as f:
        f.write(img)
    os.replace(tmp, destino)
    gasto = custo(resp.get("usage"), args)
    with _trava:
        estado["gasto"] += gasto
        reg = {"arquivo": os.path.relpath(destino, args.saida), "modelo": args.modelo,
               "qualidade": args.qualidade, "uso": resp.get("usage"), "custo_estimado": round(gasto, 4),
               "quando": time.strftime("%Y-%m-%d %H:%M:%S")}
        with open(os.path.join(args.saida, "registro.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(reg, ensure_ascii=False) + "\n")
    return destino, None, gasto


def escrever_galeria(args, itens):
    linhas = ["<!doctype html><meta charset='utf-8'><title>Ilustracoes Pentakosmos</title>",
              "<style>body{background:#14161f;color:#eee;font-family:sans-serif;margin:16px}"
              "h2{font-size:15px;margin:24px 0 6px;color:#f0c96a}.l{display:flex;gap:10px;flex-wrap:wrap}"
              "figure{margin:0}img{height:340px;border-radius:8px;display:block}"
              "figcaption{font-size:12px;color:#aaa}p{max-width:900px;color:#999;font-size:12px}</style>",
              "<h1>Ilustracoes</h1>"]
    for it in itens:
        figs = []
        for v in range(1, args.versoes + 1):
            cam = caminho_saida(args, it, v)
            if os.path.exists(cam):
                rel = os.path.relpath(cam, args.saida).replace(os.sep, "/")
                figs.append("<figure><a href='%s'><img loading=lazy src='%s'></a><figcaption>%s</figcaption></figure>"
                            % (html.escape(rel), html.escape(rel), html.escape(os.path.basename(cam))))
        if figs:
            linhas.append("<h2>%s</h2><p>%s</p><div class=l>%s</div>"
                          % (html.escape(it["arquivo"]), html.escape(it["prompt"]), "".join(figs)))
    with open(os.path.join(args.saida, "galeria.html"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def main():
    ap = argparse.ArgumentParser(description="Gera as ilustracoes do Pentakosmos pela API da OpenAI.")
    ap.add_argument("--lista", action="store_true", help="so mostra o que seria gerado (nao gasta nada)")
    ap.add_argument("--teste", type=int, metavar="N", help="gera so as N primeiras ilustracoes")
    ap.add_argument("--filtro", default="", help="so os arquivos que contem este texto (ex.: fogo, filosofo_)")
    ap.add_argument("--versoes", type=int, default=2, help="versoes de cada ilustracao, para escolher (padrao 2)")
    ap.add_argument("--modelo", default="gpt-image-2.5-flare",
                    help="modelo de imagem (padrao gpt-image-2.5-flare; o gpt-image-2.5-sunburst e o mais caprichado)")
    ap.add_argument("--qualidade", default="high", choices=["low", "medium", "high", "xhigh", "max", "auto"])
    ap.add_argument("--tamanho", default="1024x1536", help="LARGURAxALTURA, multiplos de 16 (padrao 1024x1536, vertical)")
    ap.add_argument("--formato", default="webp", choices=["webp", "png", "jpeg"])
    ap.add_argument("--compressao", type=int, default=90, help="0-100, para webp e jpeg (padrao 90)")
    ap.add_argument("--paralelo", type=int, default=3, help="pedidos ao mesmo tempo (padrao 3)")
    ap.add_argument("--max-dolares", type=float, default=25.0, help="para quando o gasto estimado passar disto (padrao 25)")
    ap.add_argument("--sem-expansao", action="store_true", help="ignora expansao/ilustracoes.csv")
    ap.add_argument("--prompts", action="append", help="outro arquivo CSV de prompts (pode repetir)")
    ap.add_argument("--saida", default=os.path.join(PROJETO, "build", "ilustracoes"))
    ap.add_argument("--preco-entrada", type=float, default=PRECO_ENTRADA_TEXTO, help="US$ por 1M tokens de texto")
    ap.add_argument("--preco-saida", type=float, default=PRECO_SAIDA_IMAGEM, help="US$ por 1M tokens de imagem")
    ap.add_argument("--url-base", default=os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1"))
    args = ap.parse_args()

    caminhos = args.prompts or [PROMPTS_BASE]
    if not args.prompts and not args.sem_expansao and os.path.exists(PROMPTS_EXPANSAO):
        caminhos.append(PROMPTS_EXPANSAO)
    with open(ESTILO, encoding="utf-8") as f:
        estilo = f.read()
    itens = [it for it in ler_prompts(caminhos) if args.filtro in it["arquivo"]]
    if args.teste:
        itens = itens[:args.teste]
    tarefas = [(it, v) for it in itens for v in range(1, args.versoes + 1)
               if not os.path.exists(caminho_saida(args, it, v))]

    print("Arquivos de prompts: " + ", ".join(os.path.relpath(c, PROJETO) for c in caminhos))
    print("%d ilustracoes x %d versoes = %d imagens; %d ja existem, faltam %d."
          % (len(itens), args.versoes, len(itens) * args.versoes, len(itens) * args.versoes - len(tarefas), len(tarefas)))
    print("Modelo %s, qualidade %s, %s, %s. Saida: %s"
          % (args.modelo, args.qualidade, args.tamanho, args.formato, args.saida))
    if args.lista:
        for it, v in tarefas:
            print("  " + os.path.relpath(caminho_saida(args, it, v), args.saida))
        return
    if not tarefas:
        os.makedirs(args.saida, exist_ok=True)
        escrever_galeria(args, itens)
        print("Nada a fazer. Galeria: " + os.path.join(args.saida, "galeria.html"))
        return

    chave = os.environ.get("OPENAI_API_KEY", "").strip()
    if not chave:
        chave = getpass.getpass("Chave da API da OpenAI (nao aparece ao digitar; nao e guardada): ").strip()
    if not chave:
        sys.exit("Sem chave, nada feito.")
    os.makedirs(args.saida, exist_ok=True)

    estado = {"gasto": 0.0, "feitas": 0, "erros": [], "reservado": 0.0}
    parar = threading.Event()

    def trabalho(it, v):
        with _trava:
            # reserva o custo medio antes de comecar, para nao passar do limite com pedidos em paralelo
            media = estado["gasto"] / max(1, estado["feitas"]) if estado["feitas"] else 0.0
            if parar.is_set() or estado["gasto"] + estado["reservado"] + media > args.max_dolares:
                if not parar.is_set():
                    print("Chegou ao limite de US$ %.2f (--max-dolares). Parando." % args.max_dolares)
                parar.set()
                return None
            estado["reservado"] += media
        try:
            return gerar_uma(chave, args, estilo, it, v, estado)
        finally:
            with _trava:
                estado["reservado"] -= media

    # a primeira imagem sozinha: confere a chave e mostra o custo por imagem antes de gastar mais
    destino, erro, gasto = trabalho(*tarefas[0])
    if erro:
        sys.exit("Falhou logo na primeira (%s): %s" % (os.path.basename(destino), erro))
    estado["feitas"] = 1
    print("1/%d  %s  (~US$ %.3f por imagem; total estimado ~US$ %.2f)"
          % (len(tarefas), os.path.relpath(destino, args.saida), gasto, gasto * len(tarefas)))

    try:
        with ThreadPoolExecutor(max_workers=max(1, args.paralelo)) as ex:
            futuros = {ex.submit(trabalho, it, v): (it, v) for it, v in tarefas[1:]}
            for fut in as_completed(futuros):
                r = fut.result()
                if r is None:
                    continue
                destino, erro, gasto = r
                with _trava:
                    estado["feitas"] += 1
                    n = estado["feitas"]
                    if erro:
                        estado["erros"].append((destino, erro))
                        print("%d/%d  ERRO %s: %s" % (n, len(tarefas), os.path.basename(destino), erro))
                        if "credito" in erro or "erro 401" in erro:
                            parar.set()
                    else:
                        print("%d/%d  %s   gasto ~US$ %.2f"
                              % (n, len(tarefas), os.path.relpath(destino, args.saida), estado["gasto"]))
    except KeyboardInterrupt:
        parar.set()
        print("\nInterrompido. Rode de novo para continuar de onde parou.")

    escrever_galeria(args, itens)
    print("\nGasto estimado nesta rodada: ~US$ %.2f (o valor exato fica no painel da OpenAI)." % estado["gasto"])
    if estado["erros"]:
        print("%d imagens falharam; rode de novo para tentar outra vez." % len(estado["erros"]))
        if any("erro 400" in e for _, e in estado["erros"]):
            print("Erros 400 costumam ser o filtro de seguranca recusando o prompt: suavize o texto daquela linha no CSV.")
    print("Galeria: " + os.path.join(args.saida, "galeria.html"))


if __name__ == "__main__":
    main()
