# Pentakosmos

*Um jogo de cartas de elementos, academias e filósofos, inspirado nos sólidos de Platão.*

**[English → README.md](README.md)**

![A mesa, com o visual dos sólidos platônicos](docs/images/table.png)

<p align="center"><img src="docs/images/solids.gif" width="408" alt="Sólidos platônicos girando devagar"></p>

Cada jogador dirige uma academia. Ao reunir os cinco elementos — **ar, água, éter, fogo e terra**, cada um representado por um sólido de Platão — e comprar as cartas de elemento que os encarnam, você traça o seu próprio caminho pelo cosmos. Cada carta comprada barateia as próximas, e os grandes filósofos da Grécia Antiga vêm ensinar na academia cujas cartas melhor refletem as suas ideias. A primeira academia a chegar a 15 pontos (ou a dominar um único elemento) encerra a partida.

- 2 a 5 jogadores, com amigos no mesmo aparelho ou contra adversários do computador.
- Dois conjuntos de regras — **Pentakosmos** (o padrão) e **Legacy** — e cada regra pode ser mudada separadamente.
- Adversários do computador treinados por algoritmo genético e ordenados por torneios.
- 38 idiomas.
- Livre e de código aberto (MIT). Linux, Windows e Android.

## Baixar e jogar

As versões prontas ficam na página [Releases](https://github.com/estatisticomoura/pentakosmos/releases).

- **Linux:** descompacte e rode `chmod +x pentakosmos.x86_64 && ./pentakosmos.x86_64`.
- **Windows:** descompacte e abra `Pentakosmos.exe`. O Windows pode avisar que o programa não é assinado; clique em "Mais informações" e depois em "Executar assim mesmo".
- **Android (7.0 ou mais novo):** baixe o `pentakosmos.apk` no celular e abra. O Android vai pedir para permitir a instalação de apps daquela origem (o navegador ou o gerenciador de arquivos); permita uma vez. O jogo roda na horizontal, com uma mesa feita para o toque: os botões de ação ficam numa coluna à esquerda, a barra de cima lista o que os adversários fizeram desde a sua última jogada, e tudo fica maior. Toque numa carta para selecioná-la e ver os detalhes, toque de novo para comprar; toque num filósofo para ver o requisito. A disposição também pode ser escolhida no menu (ao lado de *Visual*): automática, computador ou toque.

As regras estão explicadas dentro do jogo, em **Como jogar**. A história de como o jogo foi feito está em **Processo criativo** (e também em [docs/PROCESSO_CRIATIVO.md](docs/PROCESSO_CRIATIVO.md)).

| | |
|---|---|
| ![Tela inicial](docs/images/menu.png) | ![Como jogar](docs/images/rules.png) |

No celular (horizontal, 20:9):

![Mesa num celular 20:9](docs/images/phone.png)

## As regras em resumo

No seu turno, faça uma coisa:

- **Pegar fichas:** 1, 2 ou 3 fichas de elementos diferentes, ou 2 do mesmo elemento de uma pilha grande o bastante.
- **Reservar uma carta** do mercado (ou às cegas, do topo de um baralho) e ganhar uma **esfera**, o coringa.
- **Comprar uma carta.** Cada carta que você tem é um desconto permanente de 1 no seu elemento.

No fim do turno, um **filósofo** entra na sua academia se as suas cartas atendem ao requisito dele. A última rodada começa quando alguém chega a 15 pontos ou, nas regras Pentakosmos, soma 10 pontos de cartas de um único elemento (a **vitória por especialização**).

| Regra | Pentakosmos | Legacy |
|---|---|---|
| Fichas de elemento por pilha (2/3/4/5 jogadores) | 4/6/7/8 | 4/5/7/8 |
| Esferas (coringas) | 4/5/6/7 | 5 |
| Pegar 2 do mesmo elemento de uma pilha com | 3 ou mais | 4 ou mais |
| Mercado com 5 jogadores | 5 cartas por nível | 4 cartas por nível |
| Requisito dos filósofos | total −2, elementos livres | exato |
| Pontos dos filósofos | 3, depois 2, depois 1 | 3 cada |
| Deck | Pentakosmos (fórmulas) | Legacy |
| Vitória por especialização | 10 pontos num elemento | desligada |
| Limite de fichas · pontos para vencer | 10 · 15 (ajustáveis) | 10 · 15 (ajustáveis) |

### Ajudas na mesa

- **Cartas do mercado e suas reservas:** passe o mouse (ou toque) para ver quantas fichas faltam, elemento por elemento, só com os elementos e também contando as esferas que você tem.
- **Baralhos:** quantas cartas restam e quantas já saíram.
- **Filósofos:** o número no alto, à esquerda, é quanto aquele filósofo daria a você agora; o número no canto, quantas cartas ainda faltam. Passe o mouse para ver a explicação.
- **Reservas e filósofos dos outros jogadores:** passe o mouse nas minicartas e nos selos do painel. Uma reserva do mercado fica visível até a próxima vez de quem reservou (no menu de pausa há a opção "Sempre visíveis"); reservas às cegas ficam ocultas.
- **Pontos por elemento:** com a vitória por especialização ligada, cada elemento do painel mostra um selo com os pontos de cartas daquele elemento.

### Visual

Na tela inicial, em "Visual": **Sólidos platônicos** (o principal) — ar = octaedro, água = icosaedro, éter = dodecaedro, fogo = tetraedro, terra = cubo e a esfera dourada como coringa; nas fichas, os sólidos giram devagar, com uma luz que passa sobre eles — ou **Poligonal**, o primeiro visual do jogo, com polígonos coloridos.

## O deck Pentakosmos

As 90 cartas de elemento são geradas por **18 fórmulas**. Cada fórmula define o nível, os pontos e o custo de uma carta em relação ao seu próprio elemento, seguindo o ciclo ar → água → éter → fogo → terra → ar. Aplicada aos cinco elementos, cada fórmula gera cinco cartas espelhadas, e nenhum elemento é favorecido. As fórmulas estão em `scripts/core/defs.gd` (`FORMULAS_CAIO`) e explicadas em [docs/PROCESSO_CRIATIVO.md](docs/PROCESSO_CRIATIVO.md).

## Adversários do computador

Têm nomes de personagens dos diálogos de Platão, do mais brando ao mais forte: **Lísis**, **Críton**, **Fedro**, **Teeteto** e **Timeu**.

- **Lísis** joga pelo ganho imediato.
- **Críton** é um estrategista: escolhe um caminho (cartas de nível mais alto e um filósofo), reserva cedo e revê o plano.
- **Fedro, Teeteto e Timeu** são três candidatos ordenados por um torneio:
  - *evoluído:* o estrategista com 24 parâmetros ajustados por algoritmo genético;
  - *tático:* o estrategista com negação "cirúrgica" e uma busca no fim de jogo que simula o resto da partida sorteando as cartas ocultas (sem nunca espiar);
  - *misto:* o tático com os parâmetros do evoluído.

Nos torneios atuais, Timeu é o misto, Teeteto o tático e Fedro o evoluído. Há treinos separados para as regras Pentakosmos, as regras Legacy e qualquer outra combinação.

### Treinar de novo

Na pasta do projeto, com o Godot 4.7.2 e o Python 3 instalados:

```
python3 tools/evoluir.py              # algoritmo genético, treino geral (~40 min com 16 núcleos)
python3 tools/torneio.py              # torneio: decide quem é Fedro, Teeteto e Timeu
python3 tools/evoluir.py --modo house     # treino especializado nas regras Pentakosmos
python3 tools/torneio.py --modo house
python3 tools/evoluir.py --modo classico  # treino especializado nas regras Legacy
python3 tools/torneio.py --modo classico
```

- O algoritmo genético usa 16 indivíduos por geração, 1.000 partidas por indivíduo e 30 gerações, com elitismo, seleção por torneio, cruzamento e mutação decrescente. As regras de cada partida são sorteadas (número de jogadores, variantes, limite de mão, meta), e o campeão é validado em partidas que nunca viu.
- Os resultados vão para `data/ia_evoluida*.json` e `data/niveis*.json` (`house` = Pentakosmos, `classico` = Legacy). O jogo usa os arquivos especializados quando as regras são exatamente as de uma predefinição, e os gerais nos outros casos.
- `--continuar` retoma uma execução interrompida. Se o Godot foi instalado por Flatpak, acrescente `--godot "flatpak run org.godotengine.Godot"`.

## Gerar a partir do código

1. Instale o **Godot 4.7.2** ([godotengine.org](https://godotengine.org), ou `flatpak install flathub org.godotengine.Godot`).
2. Abra o editor, clique em **Importar** e escolha o `project.godot`. Aperte F5 para jogar.
3. Para exportar: *Editor → Gerenciar modelos de exportação → Baixar e instalar*; depois *Projeto → Exportar* e escolha **Linux**, **Windows** ou **Android**. Pela linha de comando:
   ```
   godot --headless --path . --export-release "Linux" build/linux/pentakosmos.x86_64
   godot --headless --path . --export-release "Windows" build/windows/Pentakosmos.exe
   ```
4. O Android precisa também do JDK 17 (`sudo apt install openjdk-17-jdk`) e do Android SDK (Platform-Tools, Build-Tools e Command-line Tools), indicado em *Editor → Configurações do editor → Exportar → Android*. O preset exporta um APK sem assinatura; assine com a sua chave (use sempre a mesma, senão o celular recusa a atualização):
   ```
   godot --headless --path . --export-release "Android" build/android/unsigned.apk
   python3 tools/assinar_apk.py nova-chave ~/pentakosmos-chave.pem    # só uma vez
   python3 tools/assinar_apk.py assinar ~/pentakosmos-chave.pem build/android/unsigned.apk build/android/pentakosmos.apk
   ```
   Para instalar pelo cabo: `adb install build/android/pentakosmos.apk`.

## Idiomas

O jogo abre em inglês; o seletor "Language" da tela inicial tem 38 idiomas: inglês, português, as 24 línguas oficiais da União Europeia e mais albanês, bielorrusso, bósnio, catalão, islandês, luxemburguês, macedônio, montenegrino, norueguês, romanche, russo, sérvio, turco e ucraniano.

- Os textos ficam em inglês no código (`L.t("...")`, `L.f("...", {...})`, em `scripts/core/lang.gd`). Cada tradução é `data/lang/<código>.json`: `{"texto em inglês": "tradução"}`. O que faltar aparece em inglês.
- Os textos longos (regras e processo criativo) ficam em `data/texts/<página>_<código>.txt`; por enquanto há versões em inglês e português.
- `python3 tools/idiomas.py` mostra o que falta em cada idioma e confere os `{marcadores}`. `python3 tools/idiomas.py --modelo xx` cria ou completa o arquivo de um idioma novo.
- As traduções foram rascunhadas com ajuda de IA. **Correções de falantes nativos são muito bem-vindas** — veja [CONTRIBUTING.md](CONTRIBUTING.md).

## Arte e som

Tudo é desenhado em código, e o jogo roda sem nenhuma imagem. Para usar arte própria, coloque PNGs em:

- `assets/cards/pentakosmos/` e `assets/cards/legacy/` — um arquivo por carta (os nomes estão em `assets/cards/CARD_LIST.csv`) e `back_l1.png` … `back_l3.png` para os versos;
- `assets/philosophers/philosopher_1.png` … `philosopher_10.png`.

O ícone (um dodecaedro negro com arestas douradas) é gerado por `python3 tools/gerar_icone.py` em `assets/icon/`.

A faixa com o elemento, os pontos e os custos é desenhada por cima da arte; se as suas cartas já trouxerem essas informações, mude `DRAW_INFO_OVER_ART` para `false` em `scripts/ui/card_view.gd`. Efeitos sonoros: `assets/sfx/<nome>.ogg` (têm prioridade sobre os `.wav` gerados); `python3 tools/gerar_sons.py` gera de novo os efeitos provisórios.

### Música

19 peças clássicas, criadas para o jogo a partir de composições em domínio público — nenhuma gravação comercial é usada. As partituras vêm do [Mutopia Project](https://www.mutopiaproject.org); as peças de piano são tocadas com o [Salamander Grand Piano](https://archive.org/details/SalamanderGrandPianoV3) (um piano de cauda real gravado nota a nota, de Alexander Holm, CC BY 3.0), e as orquestrais com o [VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE) (instrumentos de orquestra reais, da Versilian Studios, CC0). As partituras viraram interpretações com a melodia cantando sobre o acompanhamento, pedal natural, rubato suave e reverberação de sala; Grieg, Holst, Handel e Strauss ganharam arranjos para orquestra.

No menu inicial (e no menu de pausa) o jogador escolhe a playlist — **Calma**, **Animada**, **Todas** ou uma peça só. Durante a partida, o pequeno tocador ao lado do botão Menu volta para a peça anterior, pausa ou pula para a próxima; o nome de cada peça aparece quando ela começa.

| Elemento | Peça |
|---|---|
| Ar | Bach, *Air* (Suíte Orquestral nº 3) |
| Água | Debussy, *Arabesque nº 1* |
| Fogo | Handel, *La Réjouissance* (Música para os Reais Fogos de Artifício) |
| Terra | Grieg, *Na Gruta do Rei da Montanha*; Mussorgsky, *Uma Noite no Monte Calvo* |
| Éter | Holst, *Thaxted* (o tema de "Júpiter"); Debussy, *Clair de lune* |
| Esfera | Johann Strauss II, *O Danúbio Azul* |

Também: as três *Gymnopédies* e as três *Gnossiennes* de Satie, a *Ária das Variações Goldberg*, o *Prelúdio em Dó* e a *Tocata e Fuga em ré menor* de Bach, o *Noturno op. 9 nº 2* de Chopin e o *Verão* de Vivaldi. Os créditos e licenças completos estão no jogo (Processo criativo → Música) e em `data/music.json`. `python3 tools/musica/gerar_musica.py` gera de novo todas as faixas a partir das partituras.

## Estrutura

```
scripts/core/   regras, motor do jogo, IA, idiomas (sem interface)
scripts/ui/     telas, cartas, fichas, filósofos, painéis, tema visual
data/           resultados do treino das IAs, traduções (lang/) e textos longos (texts/)
assets/         arte, sons e música opcionais
tools/          algoritmo genético, torneio, conferência de traduções, gerador de sons
tests/          simulações sem interface e testes da interface
docs/           processo criativo e imagens
```

Testes, a partir da pasta do projeto:

```
godot --headless --path . --script res://tests/sim_test.gd -- house 3 normal 500
godot --headless --path . res://tests/ui_smoke.tscn -- 4 house
```

## Contribuir e falar comigo

Ideias, perguntas e histórias das suas partidas: **[Discussions](https://github.com/estatisticomoura/pentakosmos/discussions)**. Erros: **[Issues](https://github.com/estatisticomoura/pentakosmos/issues)**. Pull requests são bem-vindos; veja [CONTRIBUTING.md](CONTRIBUTING.md).

## Licença e créditos

- Código: [licença MIT](LICENSE) — use, modifique, compartilhe e até venda; só mantenha o aviso de copyright.
- Textos, sons e imagens em `data/texts/`, `assets/` e `docs/`: [CC BY 4.0](LICENSE-ASSETS.md).
- Criado por **Caio Moura Quina** ([estatisticomoura](https://github.com/estatisticomoura)), com o Claude (Anthropic) como parceiro de programação.
- Feito com o [Godot Engine](https://godotengine.org).
