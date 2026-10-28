# Pentakosmos

*Um jogo de cartas de elementos, academias e filósofos, inspirado nos sólidos de Platão.*

**[English → README.md](README.md)**

![A mesa, com o visual dos sólidos platônicos](docs/images/table.png)

<p align="center"><img src="docs/images/solids.gif" width="408" alt="Sólidos platônicos girando devagar"></p>

Cada jogador dirige uma academia. Ao reunir os cinco elementos — **ar, água, éter, fogo e terra**, cada um representado por um sólido de Platão — e comprar as cartas de elemento que os encarnam, você traça o seu próprio caminho pelo cosmos. Cada carta comprada barateia as próximas, e os grandes filósofos da Grécia Antiga vêm ensinar na academia cujas cartas melhor refletem as suas ideias. A primeira academia a chegar a 15 pontos (ou a dominar um único elemento) encerra a partida.

- 2 a 5 jogadores, com amigos no mesmo aparelho ou contra adversários do computador.
- Dois conjuntos de regras — **Pentakosmos** (o padrão) e **Arcaico** — e cada regra pode ser mudada separadamente.
- Estatísticas de cada partida, com exportação em JSON e CSV.
- Adversários do computador treinados por algoritmo genético e ordenados por torneios.
- **Governantes** opcionais: cada jogador escolhe um no começo, e quem cumprir a condição primeiro leva.
- Regras em abas, com predefinições suas, e um modo de economia de bateria.
- **Expansão:** mais 14 governantes, mais 8 escritores e decks, conjuntos e predefinições editáveis em planilha (CSV) e compartilháveis.
- 38 idiomas.
- Livre e de código aberto (MIT). Linux, Windows, macOS e Android.

## Baixar e jogar

As versões prontas ficam na página [Releases](https://github.com/estatisticomoura/pentakosmos/releases).

- **Linux:** descompacte e rode `chmod +x pentakosmos.x86_64 && ./pentakosmos.x86_64`.
- **Windows:** descompacte e abra `Pentakosmos.exe`. O Windows pode avisar que o programa não é assinado; clique em "Mais informações" e depois em "Executar assim mesmo".
- **Android (7.0 ou mais novo):** baixe o `pentakosmos.apk` no celular e abra. O Android vai pedir para permitir a instalação de apps daquela origem (o navegador ou o gerenciador de arquivos); permita uma vez. O jogo roda na horizontal, com uma mesa feita para o toque: os botões de ação ficam numa coluna à esquerda, a barra de cima lista o que os adversários fizeram desde a sua última jogada, e tudo fica maior. Toque numa carta para selecioná-la e ver os detalhes, toque de novo para comprar; toque num filósofo para ver o requisito. A disposição também pode ser escolhida em *Opções*: automática, computador ou toque.

As regras estão explicadas dentro do jogo, em **Como jogar**. A história de como o jogo foi feito está em **Processo criativo** (e também em [docs/PROCESSO_CRIATIVO.md](docs/PROCESSO_CRIATIVO.md)).

| | |
|---|---|
| ![Tela inicial](docs/images/menu.png) | ![Como jogar](docs/images/rules.png) |

No celular (horizontal, 20:9):

![Mesa num celular 20:9](docs/images/phone.png)

## As regras em resumo

No seu turno, faça uma coisa:

- **Pegar fichas:** 1, 2 ou 3 fichas de elementos diferentes, ou 2 do mesmo elemento de uma pilha grande o bastante.
- **Reservar uma carta** do mercado (ou às cegas, do topo de uma pilha) e ganhar uma **esfera**, o coringa.
- **Comprar uma carta.** Cada carta que você tem é um desconto permanente de 1 no seu elemento.

No fim do turno, um **filósofo** entra na sua academia se as suas cartas atendem ao requisito dele (no modo Arcaico, também um **escritor**). A última rodada começa quando alguém chega a 15 pontos ou, nas regras Pentakosmos, soma 10 pontos de cartas de um único elemento (a **vitória por especialização**).

| Regra | Pentakosmos | Arcaico |
|---|---|---|
| Fichas de elemento por pilha (2/3/4/5 jogadores) | 4/6/7/8 | 4/5/7/8 |
| Esferas (coringas) | 4/5/6/7 | 5 |
| Pegar 2 do mesmo elemento de uma pilha com | 3 ou mais | 4 ou mais |
| Mercado com 5 jogadores | 5 cartas por grupo | 4 cartas por grupo |
| Requisito dos filósofos | total −2, elementos livres | exato |
| Pontos dos filósofos | 3, depois 2, depois 1 | 3 cada |
| Escritores | não | 2 na mesa, requisito exato, 1 ponto cada |
| Deck | Pentakosmos (fórmulas) | Arcaico (fórmulas) |
| Vitória por especialização | 10 pontos num elemento | desligada |
| Limite de fichas · pontos para vencer | 10 · 15 (ajustáveis) | 10 · 15 (ajustáveis) |
| Tempo por jogada (contra IAs · entre pessoas) | sem limite · 60 s (ajustáveis) | sem limite · 60 s (ajustáveis) |

As cartas vêm em três grupos — **básicas**, **intermediárias** e **avançadas** —, e o verso de cada uma mostra uma estrela com 1, 2 ou 3 planetas.

**Escritores.** Os escritores (Homero e Sófocles no jogo base; a expansão traz Safo, Hesíodo, Píndaro, Heródoto, Ésquilo, Aristófanes, Tucídides e Eurípides) pedem cartas nas combinações de elementos que os filósofos não usam: 3 + 3 de dois elementos, ou 2 + 2 + 2 de três. Cada um vale 1 ponto e não entra na sequência 3 / 2 / 1 dos filósofos; no mesmo turno podem chegar um filósofo e um escritor. Nas regras, caixas de seleção ligam ou desligam filósofos, escritores e governantes.

**Governantes (opcional).** Com eles ligados, a meta de quem não tem governante sobe (19 pontos, por padrão). No começo, cada jogador escolhe um governante em 30 segundos (há um botão de escolha aleatória, e o tempo esgotado sorteia), ou a regra manda sortear. Escolher não dá exclusividade: no fim da vez, quem cumprir primeiro a condição de um governante da mesa pode recebê-lo ou recusar. Cada governante tem uma condição, às vezes um custo, às vezes uma vantagem, e muda a meta de quem o recebe — Péricles pede 2 cartas avançadas e faz você vencer com 15. Cada jogador tem no máximo um, e quem chegou à própria meta vence quem não chegou. O jogo base traz Péricles, Leônidas e Alexandre.

**Menu de regras.** As regras ficam em abas. Cada opção fora do padrão da predefinição ganha um degradê vermelho, e há botões para restaurar a aba ou tudo. Os pontos para vencer vão de 1 a 100, e "Ver reservas" agora é uma regra.

### Ajudas na mesa

- **Cartas do mercado e suas reservas:** passe o mouse (ou toque) para ver quantas fichas faltam, elemento por elemento, só com os elementos e também contando as esferas que você tem.
- **Baralhos:** quantas cartas restam e quantas já saíram.
- **Filósofos:** o número no alto, à esquerda, é quanto aquele filósofo daria a você agora; o número no canto, quantas cartas ainda faltam. Passe o mouse para ver a explicação.
- **Reservas e academia dos outros jogadores:** passe o mouse (ou toque) nas minicartas e no louro (filósofos) ou na pena (escritores) do painel. Uma reserva do mercado fica visível até a próxima vez de quem reservou (a regra "Ver reservas" tem a opção "Sempre visíveis"); reservas às cegas ficam ocultas.
- **Cronômetros:** acima do botão Menu, a rodada, o tempo da partida e, quando há limite, o anel com o tempo que resta da jogada.
- **Pontos por elemento:** com a vitória por especialização ligada, cada elemento do painel mostra um selo com os pontos de cartas daquele elemento.

### Visual e bateria

Em Opções e no menu de pausa ficam o tamanho do texto e o visual: **Sólidos platônicos** (o principal) — ar = octaedro, água = icosaedro, éter = dodecaedro, fogo = tetraedro, terra = cubo e a esfera dourada como coringa; nas fichas, os sólidos giram devagar, com uma luz que passa sobre eles — ou **Poligonal**, o primeiro visual do jogo, com polígonos coloridos. O Poligonal também é o **modo de economia de bateria**: o jogo passa a 30 quadros por segundo.

## Jogo base e expansão

O jogo base é completo: os decks Pentakosmos e Arcaico, os filósofos, 2 escritores e 3 governantes, e todas as regras. A **expansão** acrescenta 14 governantes e 8 escritores e libera a tela **Personalizar**: decks, conjuntos de filósofos, escritores e governantes e predefinições de regras viram arquivos CSV, que se editam numa planilha, se duplicam, se exportam e se importam. Os decks e conjuntos que vêm com o jogo ficam travados; para mudá-los, duplique. O formato está em [docs/CONTEUDO_PERSONALIZADO.md](docs/CONTEUDO_PERSONALIZADO.md).

Os dados da expansão não ficam neste repositório: o jogo os procura na pasta `expansao/` (com o arquivo `expansao.txt`). Sem ela, o jogo funciona normalmente como jogo base.

## O deck Pentakosmos

As 90 cartas de elemento são geradas por **18 fórmulas**. Cada fórmula define o grupo, os pontos e o custo de uma carta em relação ao seu próprio elemento, seguindo o ciclo ar → água → éter → fogo → terra → ar. Aplicada aos cinco elementos, cada fórmula gera cinco cartas espelhadas, e nenhum elemento é favorecido. As fórmulas estão em `scripts/core/defs.gd` (`FORMULAS_CAIO`) e explicadas em [docs/PROCESSO_CRIATIVO.md](docs/PROCESSO_CRIATIVO.md).

O **deck Arcaico** também tem 90 cartas geradas por 18 fórmulas (`FORMULAS_ARCAICO`), com os mesmos custos médios por grupo (4,12 / 6,83 / 10,75), mas com moldes próprios, em outras posições do ciclo.

## Estatísticas

Cada partida com pelo menos um jogador humano é registrada: as regras completas, o deck, a duração, as cartas compradas por grupo e elemento, os pontos por elemento, filósofos e escritores, e o tempo médio por jogada. A tela **Estatísticas** filtra por jogador, período (de 1 semana a todo o tempo) e regras, e exporta tudo em JSON (que pode ser importado em outro aparelho, sem duplicar partidas) ou em CSV, para planilhas.

## Adversários do computador

Têm nomes de personagens dos diálogos de Platão, do mais brando ao mais forte: **Lísis**, **Críton**, **Fedro**, **Teeteto** e **Timeu**.

- **Lísis** joga pelo ganho imediato.
- **Críton** é um estrategista: escolhe um caminho (cartas de nível mais alto e um filósofo), reserva cedo e revê o plano.
- **Fedro, Teeteto e Timeu** são três candidatos ordenados por um torneio:
  - *evoluído:* o estrategista com 24 parâmetros ajustados por algoritmo genético;
  - *tático:* o estrategista com negação "cirúrgica" e uma busca no fim de jogo que simula o resto da partida sorteando as cartas ocultas (sem nunca espiar);
  - *misto:* o tático com os parâmetros do evoluído.

Nos torneios atuais, Timeu é o misto, Teeteto o tático e Fedro o evoluído. Há treinos separados para as regras Pentakosmos, as regras do modo Arcaico e qualquer outra combinação.

### Treinar de novo

Na pasta do projeto, com o Godot 4.7.2 e o Python 3 instalados:

```
python3 tools/evoluir.py              # algoritmo genético, treino geral (~40 min com 16 núcleos)
python3 tools/torneio.py              # torneio: decide quem é Fedro, Teeteto e Timeu
python3 tools/evoluir.py --modo house     # treino especializado nas regras Pentakosmos
python3 tools/torneio.py --modo house
python3 tools/evoluir.py --modo classico  # treino especializado nas regras do modo Arcaico
python3 tools/torneio.py --modo classico
```

- O algoritmo genético usa 16 indivíduos por geração, 1.000 partidas por indivíduo e 30 gerações, com elitismo, seleção por torneio, cruzamento e mutação decrescente. As regras de cada partida são sorteadas (número de jogadores, variantes, limite de mão, meta), e o campeão é validado em partidas que nunca viu.
- Os resultados vão para `data/ia_evoluida*.json` e `data/niveis*.json` (`house` = Pentakosmos, `classico` = Arcaico). O jogo usa os arquivos especializados quando as regras são exatamente as de uma predefinição, e os gerais nos outros casos.
- `--continuar` retoma uma execução interrompida. Se o Godot foi instalado por Flatpak, acrescente `--godot "flatpak run org.godotengine.Godot"`.

## Gerar a partir do código

1. Instale o **Godot 4.7.2** ([godotengine.org](https://godotengine.org), ou `flatpak install flathub org.godotengine.Godot`).
2. Abra o editor, clique em **Importar** e escolha o `project.godot`. Aperte F5 para jogar.
3. Para incluir a expansão, copie a pasta `expansao/` para a raiz do projeto antes de exportar (sem ela, sai o jogo base).
4. Para exportar: *Editor → Gerenciar modelos de exportação → Baixar e instalar*; depois *Projeto → Exportar* e escolha **Linux**, **Windows**, **macOS** ou **Android**. Pela linha de comando:
   ```
   godot --headless --path . --export-release "Linux" build/linux/pentakosmos.x86_64
   godot --headless --path . --export-release "Windows" build/windows/Pentakosmos.exe
   godot --headless --path . --export-release "macOS" build/mac/Pentakosmos.zip
   ```
   O build de macOS é um app universal (Intel e Apple Silicon) com assinatura ad-hoc, sem notarização: no Mac, descompacte e, na primeira vez, clique com o botão direito em *Pentakosmos.app* → *Abrir* (ou permita em *Ajustes do Sistema → Privacidade e Segurança*).
5. O Android precisa também do JDK 17 (`sudo apt install openjdk-17-jdk`) e do Android SDK (Platform-Tools, Build-Tools e Command-line Tools), indicado em *Editor → Configurações do editor → Exportar → Android*. O preset exporta um APK sem assinatura; assine com a sua chave (use sempre a mesma, senão o celular recusa a atualização):
   ```
   godot --headless --path . --export-release "Android" build/android/unsigned.apk
   python3 tools/assinar_apk.py nova-chave ~/pentakosmos-chave.pem    # só uma vez
   python3 tools/assinar_apk.py assinar ~/pentakosmos-chave.pem build/android/unsigned.apk build/android/pentakosmos.apk
   ```
   Para instalar pelo cabo: `adb install build/android/pentakosmos.apk`.

## Idiomas

Na primeira vez, o jogo usa o idioma do aparelho, se o tiver, e senão o inglês; o botão *Idioma* da tela inicial tem 38 idiomas: inglês, português, as 24 línguas oficiais da União Europeia e mais albanês, bielorrusso, bósnio, catalão, islandês, luxemburguês, macedônio, montenegrino, norueguês, romanche, russo, sérvio, turco e ucraniano.

- Os textos ficam em inglês no código (`L.t("...")`, `L.f("...", {...})`, em `scripts/core/lang.gd`). Cada tradução é `data/lang/<código>.json`: `{"texto em inglês": "tradução"}`. O que faltar aparece em inglês.
- Os textos longos (regras e processo criativo) ficam em `data/texts/<página>_<código>.txt`; por enquanto há versões em inglês e português.
- `python3 tools/idiomas.py` mostra o que falta em cada idioma e confere os `{marcadores}`. `python3 tools/idiomas.py --modelo xx` cria ou completa o arquivo de um idioma novo.
- As traduções foram rascunhadas com ajuda de IA. **Correções de falantes nativos são muito bem-vindas** — veja [CONTRIBUTING.md](CONTRIBUTING.md).

## Arte e som

Tudo é desenhado em código, e o jogo roda sem nenhuma imagem. Para usar arte própria, coloque PNGs em:

- `assets/cards/pentakosmos/` e `assets/cards/arcaico/` — um arquivo por carta (os nomes estão em `assets/cards/CARD_LIST.csv`) e `back_l1.png` … `back_l3.png` para os versos;
- `assets/philosophers/philosopher_1.png` … `philosopher_10.png` e `assets/writers/writer_1.png` … `writer_10.png`.

O ícone (um dodecaedro negro com arestas douradas) é gerado por `python3 tools/gerar_icone.py` em `assets/icon/`.

A faixa com o elemento, os pontos e os custos é desenhada por cima da arte; se as suas cartas já trouxerem essas informações, mude `DRAW_INFO_OVER_ART` para `false` em `scripts/ui/card_view.gd`. Efeitos sonoros: `assets/sfx/<nome>.ogg` (têm prioridade sobre os `.wav` gerados); `python3 tools/gerar_sons.py` gera de novo os efeitos provisórios.

### Música

19 peças clássicas, criadas para o jogo a partir de composições em domínio público — nenhuma gravação comercial é usada. As partituras vêm do [Mutopia Project](https://www.mutopiaproject.org); as peças de piano são tocadas com o [Salamander Grand Piano](https://archive.org/details/SalamanderGrandPianoV3) (um piano de cauda real gravado nota a nota, de Alexander Holm, CC BY 3.0), e as orquestrais com o [VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE) (instrumentos de orquestra reais, da Versilian Studios, CC0). As partituras viraram interpretações com a melodia cantando sobre o acompanhamento, pedal natural, rubato suave e reverberação de sala; Grieg, Holst e Handel ganharam arranjos para orquestra.

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
docs/           processo criativo, formato do conteúdo personalizado, imagens
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
