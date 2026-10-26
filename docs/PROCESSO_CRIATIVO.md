# Como nasceu o Pentakosmos

Tudo começou na mesa, com um jogo de cartas de que eu gostava muito e um punhado de regras que eu vivia mudando com os amigos. Quantas fichas deveria haver com três jogadores? E se os filósofos pedissem um pouco menos, mas premiassem mais o primeiro do que o último? E se a partida com cinco jogadores tivesse um mercado maior? Essas perguntas eram divertidas, mas eu queria respostas que fossem mais do que palpites.

## Regras postas à prova
Então sentei com o Claude, um assistente de inteligência artificial, e transformamos cada ideia em um experimento. Escrevemos um simulador e deixamos o meu próprio computador jogar dezenas de milhares de partidas, comparando cada variante com as regras tradicionais, para dois, três, quatro e cinco jogadores: quanto as partidas duravam, com que frequência alguém precisava descartar fichas, quanto o primeiro jogador era favorecido. Quando algo nos surpreendia, íamos mais fundo — e quando um resultado contrariava a minha intuição, os números davam a palavra final. Muitas das regras do modo Pentakosmos sobreviveram a esse processo: a quantidade de fichas por número de jogadores, pegar duas iguais de uma pilha com três, o mercado maior para cinco, os filósofos flexíveis que valem 3, 2 e 1 pontos.

## Um deck feito de fórmulas
Depois veio a parte de que mais me orgulho, e que eu desenhei sozinho: o deck. Em vez de desenhar 90 cartas uma a uma, escrevi 18 fórmulas. Cada fórmula descreve uma carta em relação ao seu próprio elemento — o nível, os pontos e quanto ela custa nos elementos que vêm antes e depois dele num ciclo fixo (ar, água, éter, fogo, terra). Aplicada aos cinco elementos, cada fórmula gera cinco cartas que são espelhos perfeitos umas das outras. O deck é equilibrado por construção: nenhum elemento é mais forte do que outro, e toda carta tem um motivo para existir. As simulações mostraram depois como ele se comportava diante do deck tradicional e me ajudaram a afiná-lo.

## Das planilhas para um jogo de verdade
Com as regras firmes, quis que qualquer pessoa pudesse jogá-las — no Linux, no Windows e no Android, de graça. O Claude e eu construímos o jogo no Godot, com cada regra disponível como opção no menu. Eu queria adversários à altura, então criamos vários tipos de inteligência artificial e os deixamos evoluir: um algoritmo genético ajustou a estratégia deles ao longo de centenas de milhares de partidas no meu computador, e um torneio decidiu qual merecia cada lugar. No caminho surgiu uma ideia nova — a vitória por especialização, para quem domina um único elemento — e os adversários aprenderam a buscá-la e a impedi-la.

## Os cinco sólidos
Por fim, o jogo encontrou a sua própria alma. No Timeu, Platão associa os elementos aos cinco sólidos regulares: o fogo ao tetraedro, o ar ao octaedro, a água ao icosaedro, a terra ao cubo, e o dodecaedro ao próprio cosmos. As fichas viraram sólidos girando devagar, o coringa virou uma esfera dourada, os visitantes de cada academia viraram os filósofos que primeiro perguntaram do que o mundo é feito, e os adversários do computador emprestaram os nomes das pessoas que conversam nos diálogos de Platão. O nome veio naturalmente: **Pentakosmos**, o cosmos dos cinco.

## Livre, para todos
Fiz este jogo pelo prazer de fazê-lo: de testar uma ideia, ver os números confirmarem (ou não) e ver um detalhe se encaixar. Esse prazer é para ser compartilhado. O Pentakosmos é gratuito e de código aberto, sob a licença MIT: você pode jogá-lo, estudá-lo, traduzi-lo, modificá-lo, criar a sua própria versão e até vendê-la — só peço que mencione de onde ele partiu.

Se você tiver uma ideia, encontrar um erro, quiser melhorar uma tradução ou só quiser me contar sobre uma partida, vou adorar saber:
- Conversas e sugestões: [github.com/estatisticomoura/pentakosmos/discussions](https://github.com/estatisticomoura/pentakosmos/discussions)
- Erros: [github.com/estatisticomoura/pentakosmos/issues](https://github.com/estatisticomoura/pentakosmos/issues)

Bom jogo!
— Caio Moura


---

## Apêndice: as fórmulas do deck Pentakosmos

Cada carta de elemento tem nível, pontos e custo. No deck Pentakosmos, o custo é escrito em relação ao próprio elemento da carta, usando o ciclo **ar → água → éter → fogo → terra → ar**: "−2" é o elemento duas posições antes do elemento da carta no ciclo, "próprio" é o elemento da carta, "+1" o seguinte, e assim por diante. Cada uma das 18 fórmulas é aplicada aos cinco elementos, gerando 90 cartas.

| # | Nível | Pontos | −2 | −1 | próprio | +1 | +2 | Custo total |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 0 | 1 | 1 | · | 1 | 1 | 4 |
| 2 | 1 | 0 | 1 | 2 | 1 | · | · | 4 |
| 3 | 1 | 0 | · | · | 1 | 2 | 1 | 4 |
| 4 | 1 | 0 | · | 2 | · | 2 | · | 4 |
| 5 | 1 | 0 | · | 2 | 1 | · | · | 3 |
| 6 | 1 | 0 | 2 | · | · | · | 2 | 4 |
| 7 | 1 | 0 | · | · | · | 3 | · | 3 |
| 8 | 1 | 1 | · | · | 4 | · | · | 4 |
| 9 | 2 | 1 | · | 3 | · | 2 | · | 5 |
| 10 | 2 | 1 | 3 | · | · | · | 3 | 6 |
| 11 | 2 | 2 | · | · | 5 | · | · | 5 |
| 12 | 2 | 2 | · | · | 3 | 4 | · | 7 |
| 13 | 2 | 2 | · | 4 | 1 | 2 | · | 7 |
| 14 | 2 | 3 | · | · | 6 | · | · | 6 |
| 15 | 3 | 3 | · | 5 | 2 | 2 | · | 9 |
| 16 | 3 | 4 | · | · | 5 | 5 | · | 10 |
| 17 | 3 | 4 | 3 | 6 | · | · | · | 9 |
| 18 | 3 | 5 | · | · | · | 7 | 3 | 10 |

Exemplo: a fórmula 9 para uma carta de **fogo** (nível 2, 1 ponto) custa 3 de éter (−1) e 2 de terra (+1).

As fórmulas ficam em `scripts/core/defs.gd` (`FORMULAS_CAIO` e `OFFSETS`); qualquer pessoa pode criar uma variante mudando uma única tabela.

## Apêndice: alguns números

- O motor do jogo foi conferido com o simulador original em Python: com 2.000 partidas por configuração, a duração média e o número de filósofos coincidiram dentro da margem de erro (por exemplo, 22,32 contra 22,26 rodadas nas partidas Pentakosmos com três jogadores).
- **Vitória por especialização.** Com o limite em 10 pontos num elemento, entre 9% e 12% das partidas entre adversários do computador terminam por especialização, e a regra muda o vencedor em cerca de 3% de todas as partidas: ela acrescenta um segundo caminho para a vitória sem dominar o jogo.
- **Algoritmo genético.** Medido como vitórias acima da parcela esperada contra o estrategista (Críton): o campeão geral chegou a +5,75 pontos percentuais; o campeão treinado só com as regras Pentakosmos (incluindo a especialização) chegou a +8,2, ou seja, 4,8 pontos a mais que o geral nas mesmas partidas; o campeão das regras Legacy chegou a +6,5.
- **Torneio** (regras Pentakosmos, milhares de partidas): misto +10,8, tático +4,7, evoluído −10,6 pontos percentuais acima do esperado nos confrontos diretos. Contra estrategistas, o adversário misto vence 30,8 pontos acima da sua parcela esperada.
