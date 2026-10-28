class_name Defs
extends RefCounted
## Dados fixos do jogo: cores, cartas, filosofos, escritores e o gerador dos decks por formulas.

const GOLD := 5
const NCOLORS := 5

const COLOR_NAMES := ["white", "blue", "green", "red", "black", "gold"]  # nomes internos (arquivos de arte)
const COLOR_LABELS := ["Branco", "Azul", "Verde", "Vermelho", "Preto", "Ouro"]
# Visual: "solidos" (solidos platonicos, o principal) ou "poligonal" (o visual original, poligonos).
# Cores de exibicao de cada visual; COLORS/INK mudam com set_visual().
const COLORS_POLIGONAL := [
	Color(0.93, 0.93, 0.95),  # branco
	Color(0.20, 0.45, 0.90),  # azul
	Color(0.18, 0.66, 0.33),  # verde
	Color(0.85, 0.24, 0.24),  # vermelho
	Color(0.20, 0.20, 0.22),  # preto
	Color(1.0, 0.88, 0.32),   # estrela (coringa): amarelo claro, como a esfera
]
const COLORS_SOLIDOS := [
	Color(0.84, 0.89, 0.96),  # ar: octaedro
	Color(0.17, 0.46, 0.90),  # agua: icosaedro
	Color(0.20, 0.66, 0.42),  # eter: dodecaedro
	Color(0.90, 0.32, 0.18),  # fogo: tetraedro
	Color(0.25, 0.15, 0.08),  # terra: cubo (marrom bem escuro)
	Color(1.0, 0.88, 0.32),  # esfera (coringa): amarelo claro
]
const INK_POLIGONAL := [
	Color(0.10, 0.10, 0.12), Color(1, 1, 1), Color(1, 1, 1),
	Color(1, 1, 1), Color(1, 1, 1), Color(0.15, 0.10, 0.0),
]
const VISUALS := ["solidos", "poligonal"]
const VISUAL_NAMES := ["Platonic solids", "Polygonal"]  # tr
static var visual := "solidos"
static var COLORS: Array = COLORS_POLIGONAL.duplicate()
# Cor do texto sobre cada cor
static var INK: Array = INK_POLIGONAL.duplicate()


static func set_visual(v: String) -> void:
	visual = v if v in VISUALS else "solidos"
	COLORS = (COLORS_SOLIDOS if visual == "solidos" else COLORS_POLIGONAL).duplicate()
	INK = INK_POLIGONAL.duplicate()
	# o visual poligonal e o modo de economia de energia: no maximo 30 quadros por segundo;
	# com os solidos, o aparelho decide
	Engine.max_fps = 30 if visual == "poligonal" else 0

# Filosofos: requisito por cor (ar, agua, eter, fogo, terra). Pares de cores vizinhas no ciclo
# (4 + 4) e trios de cores consecutivas (3 + 3 + 3).
const NOBLES := [
	[0, 0, 4, 4, 0], [0, 0, 0, 4, 4], [0, 4, 4, 0, 0], [4, 4, 0, 0, 0], [4, 0, 0, 0, 4],
	[3, 0, 0, 3, 3], [0, 3, 3, 3, 0], [3, 3, 3, 0, 0], [0, 0, 3, 3, 3], [3, 3, 0, 0, 3],
]

# Escritores gregos: as combinacoes que os filosofos nao usam. Pares de cores que "pulam uma"
# no ciclo (3 + 3) e trios complementares (2 + 2 + 2). Cada escritor vale WRITER_PTS.
# No jogo base ha dois (um de cada tipo); os outros oito vem com a expansao.
const WRITERS := [[0, 3, 0, 3, 0], [2, 0, 2, 0, 2]]
const WRITER_NAMES := ["Homer", "Sophocles"]  # tr
const WRITER_ART := [2, 7]   # numero da arte em assets/writers/writer_<n>.png
const WRITER_BASE := 100     # ids >= 100 na mesa sao escritores
const WRITER_PTS := 1
const WRITERS_ON_TABLE := 2

# Adversarios da IA: personagens dos dialogos de Platao, do mais fraco ao mais forte.
const PERSONAS := {"facil": "Lysis", "normal": "Crito", "intermediaria": "Phaedrus",  # tr
	"dificil": "Theaetetus", "muito_dificil": "Timaeus"}  # tr

# Filosofos (antes "nobres"), na ordem de NOBLES; cada um combina com os elementos do seu requisito.
const PHILOSOPHERS := ["Anaxagoras", "Parmenides", "Thales", "Anaximenes", "Democritus",  # tr
	"Heraclitus", "Pythagoras", "Aristotle", "Plato", "Empedocles"]  # tr

static func is_writer(id: int) -> bool:
	return id >= WRITER_BASE


# Grupos de cartas (antes "niveis" 1, 2 e 3)
const LEVEL_NAMES := ["", "Basic cards", "Intermediate cards", "Advanced cards"]  # tr
const LEVEL_SHORT := ["", "Basic", "Intermediate", "Advanced"]  # tr


# Deck do Caio: (nivel, pv, C4, C2, A, C1, C3). Cada formula gera uma carta por cor.
const FORMULAS_CAIO := [
	[1, 0, 1, 1, 0, 1, 1], [1, 0, 1, 2, 1, 0, 0], [1, 0, 0, 0, 1, 2, 1], [1, 0, 0, 2, 0, 2, 0],
	[1, 0, 0, 2, 1, 0, 0], [1, 0, 2, 0, 0, 0, 2], [1, 0, 0, 0, 0, 3, 0], [1, 1, 0, 0, 4, 0, 0],
	[2, 1, 0, 3, 0, 2, 0], [2, 1, 3, 0, 0, 0, 3], [2, 2, 0, 0, 5, 0, 0], [2, 2, 0, 0, 3, 4, 0],
	[2, 2, 0, 4, 1, 2, 0], [2, 3, 0, 0, 6, 0, 0],
	[3, 3, 0, 5, 2, 2, 0], [3, 4, 0, 0, 5, 5, 0], [3, 4, 3, 6, 0, 0, 0], [3, 5, 0, 0, 0, 7, 3],
]
# Deck Arcaico: mesmo formato. Custos mais altos e mais espalhados pelos outros elementos.
const FORMULAS_ARCAICO := [
	[1, 0, 1, 1, 0, 1, 1], [1, 0, 0, 0, 0, 2, 1], [1, 0, 1, 2, 0, 1, 1], [1, 0, 2, 0, 0, 0, 2],
	[1, 0, 2, 0, 0, 1, 2], [1, 0, 0, 3, 0, 0, 0], [1, 0, 1, 1, 0, 0, 3], [1, 1, 0, 0, 0, 4, 0],
	[2, 1, 3, 0, 0, 2, 2], [2, 1, 0, 0, 2, 3, 3], [2, 2, 0, 1, 0, 4, 2], [2, 2, 0, 0, 0, 0, 5],
	[2, 2, 3, 0, 0, 5, 0], [2, 3, 0, 0, 6, 0, 0],
	[3, 3, 3, 3, 0, 5, 3], [3, 4, 0, 3, 3, 0, 6], [3, 4, 0, 0, 0, 0, 7], [3, 5, 7, 0, 3, 0, 0],
]
const OFFSETS := [-2, -1, 0, 1, 2]  # C4, C2, A, C1, C3 relativos a A no ciclo

const DECK_NAMES := {"arcaico": "Archaic deck", "caio": "Pentakosmos deck"}  # tr
# pasta da arte de cada deck: assets/cards/<pasta>/
const DECK_DIRS := {"arcaico": "arcaico", "caio": "pentakosmos"}


class CardDef:
	extends RefCounted
	var id: int
	var level: int                  # grupo: 1 basicas, 2 intermediarias, 3 avancadas
	var bonus: int                  # cor do bonus (0..4) quando kind == "single"; -1 nos outros casos
	var kind := "single"            # "single" (um solido), "none" (sem bonus), "multi" (varios), "joker" (coringa)
	var bonus_vec := [0, 0, 0, 0, 0]  # bonus de cada cor (para "single" e "multi")
	var points: int                 # pode ser negativo
	var cost: Array                 # 6 inteiros: 5 elementos + esferas (custo pago so com esferas)
	var effect := ""                # efeito ao comprar: "", "token", "two_tokens", "sphere", "extra_turn"
	var key: String                 # nome usado para arte em PNG, ex.: l2_blue_03
	var total: int

	func _init(p_id: int, p_level: int, p_bonus: int, p_points: int, p_cost: Array) -> void:
		id = p_id
		level = p_level
		bonus = p_bonus
		points = p_points
		cost = p_cost.duplicate()
		while cost.size() < 6:
			cost.append(0)
		if p_bonus >= 0:
			bonus_vec[p_bonus] = 1
		total = 0
		for x in cost:
			total += x

	func spec_color() -> int:
		## Cor em que a carta conta para a especializacao (so cartas de um solido).
		return bonus if kind == "single" else -1

	func display_color() -> int:
		## Cor da faixa da carta: a do bonus, ou a do maior bonus de uma carta multipla; -1 = neutra.
		if kind == "single":
			return bonus
		if kind == "multi":
			var best := 0
			for c in range(5):
				if bonus_vec[c] > bonus_vec[best]:
					best = c
			return best
		return -1


static func build_deck(name: String) -> Array:
	var raw: Array = []  # [nivel, bonus, pontos, custo]
	var formulas: Array = FORMULAS_CAIO if name == "caio" else FORMULAS_ARCAICO
	for f in formulas:
		for a in range(5):
			var cost := [0, 0, 0, 0, 0, 0]
			for k in range(5):
				cost[posmod(a + OFFSETS[k], 5)] += f[2 + k]
			raw.append([f[0], a, f[1], cost])
	var cards: Array = []
	var counters := {}
	for i in range(raw.size()):
		var r: Array = raw[i]
		var c := CardDef.new(i, r[0], r[1], r[2], r[3])
		var ck := "%d_%d" % [c.level, c.bonus]
		counters[ck] = counters.get(ck, 0) + 1
		c.key = "l%d_%s_%02d" % [c.level, COLOR_NAMES[c.bonus], counters[ck]]
		cards.append(c)
	return cards
