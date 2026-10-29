# Ilustrações em lote

`gerar_ilustracoes.py` gera as ilustrações do jogo pela API de imagens da OpenAI. Ele usa só o Python 3 que já vem no Debian, sem instalar nada.

## O que será gerado

| Arquivo de prompts | Conteúdo | Ilustrações |
|---|---|---|
| `prompts.csv` | 90 paisagens de cartas: 5 elementos × 3 níveis × 6 variações | 90 |
| `prompts.csv` | Filósofos (10), Homero, Sófocles, Péricles, Leônidas e Alexandre | 15 |
| `expansao/ilustracoes.csv` | Os 8 escritores e os 14 governantes da expansão | 22 |

Por padrão saem **2 versões de cada uma**, para você escolher a melhor. A identidade visual comum fica em `estilo.txt`, e cada linha dos CSVs descreve só a cena. Para mudar o estilo de tudo, edite o `estilo.txt`. Para mudar uma imagem, edite a linha dela no CSV. Os dois abrem num editor de texto ou numa planilha.

## Antes de começar

1. Crie uma conta em **platform.openai.com**. A API é cobrada à parte: a assinatura do ChatGPT não cobre a API. Coloque créditos e, em *Settings → Limits*, defina um limite mensal de gasto, como garantia extra.
2. Em *API keys*, crie uma chave. Ela começa com `sk-`. Guarde-a só com você.
3. Algumas contas precisam verificar a organização antes de usar os modelos de imagem. Se a primeira imagem der erro 403, é isso.

## Como rodar

Na pasta do projeto:

```
export OPENAI_API_KEY="sk-..."          # vale até fechar o terminal; se não fizer isso, o script pergunta a chave

python3 tools/ilustracoes/gerar_ilustracoes.py --lista              # mostra o que será gerado, sem gastar
python3 tools/ilustracoes/gerar_ilustracoes.py --teste 3            # só as 3 primeiras: para ver o estilo e o custo real
python3 tools/ilustracoes/gerar_ilustracoes.py --filtro personagens # só os retratos
python3 tools/ilustracoes/gerar_ilustracoes.py --filtro fogo        # só as cartas de fogo
python3 tools/ilustracoes/gerar_ilustracoes.py                      # tudo
```

- **Custo:** a primeira imagem sai sozinha, e o script mostra o custo por imagem e uma estimativa do total antes de continuar.
- **Limite de gasto:** o script para sozinho ao chegar a US$ 25 estimados. Mude com `--max-dolares 10`, por exemplo.
- **Interromper e retomar:** dá para interromper com Ctrl+C. Ao rodar de novo, ele continua de onde parou, porque imagens já geradas são puladas.
- **Para refazer uma imagem:** apague o arquivo dela e rode de novo.
- **Resultado:** tudo vai para `build/ilustracoes/`. Abra `build/ilustracoes/galeria.html` no navegador para ver as versões lado a lado, com o prompt de cada uma.
- **Registro:** `build/ilustracoes/registro.jsonl` guarda o uso e o custo estimado de cada imagem.

## Opções úteis

| Opção | Padrão | Para quê |
|---|---|---|
| `--versoes N` | 2 | Quantas versões de cada ilustração. |
| `--modelo` | `gpt-image-2.5-flare` | `gpt-image-2.5-sunburst` é o mais caprichado (e mais lento). |
| `--qualidade` | `high` | `low`, `medium`, `high`, `xhigh`, `max`. `low` é ótimo para testar o estilo gastando pouco. |
| `--tamanho` | `1024x1536` | Vertical, no formato de carta. |
| `--formato` | `webp` | `webp` (leve), `png` ou `jpeg`. |
| `--paralelo N` | 3 | Imagens geradas ao mesmo tempo. |
| `--sem-expansao` | — | Ignora os prompts da expansão. |

## Sugestão de roteiro

1. `--teste 5 --qualidade low`: confira o estilo na galeria, quase de graça.
2. Se precisar, ajuste `estilo.txt` e repita. Apague antes a pasta `build/ilustracoes`.
3. `--filtro personagens`: os retratos, que são os mais delicados.
4. O resto.
5. Escolha as melhores versões e me mande. Eu recorto, comprimo e coloco no jogo.

**Erro 400:** normalmente é o filtro de segurança recusando o texto de uma linha. Suavize a descrição (batalhas, por exemplo) e rode de novo.

**Direitos:** a OpenAI cede ao usuário os direitos sobre as imagens geradas, mas em vários países imagens feitas por IA não têm proteção de direito autoral. Nos créditos do jogo, vamos dizer que as ilustrações foram geradas com IA.
