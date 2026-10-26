class_name Defs
extends RefCounted
## Dados fixos do jogo: cores, cartas, nobres e o gerador do deck por formulas.

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
	Color(0.93, 0.74, 0.18),  # ouro
]
const COLORS_SOLIDOS := [
	Color(0.84, 0.89, 0.96),  # ar: octaedro
	Color(0.17, 0.46, 0.90),  # agua: icosaedro
	Color(0.20, 0.66, 0.42),  # eter: dodecaedro
	Color(0.90, 0.32, 0.18),  # fogo: tetraedro
	Color(0.25, 0.15, 0.08),  # terra: cubo (marrom bem escuro)
	Color(1.0, 0.82, 0.25),  # esfera (coringa)
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

# Deck oficial: nivel, bonus, pontos, custo (branco azul verde vermelho preto)
const OFFICIAL_CODES := "10000021 10001111 10001211 10002002 10002201 10003000 10031001 10100400 11000003 11000202 11001310 11010002 11010111 11010121 11010220 11100040 12000030 12001022 12002020 12011011 12011012 12013100 12021000 12100004 13002100 13010013 13011101 13020020 13020102 13021101 13030000 13140000 14000131 14000210 14000300 14011110 14012110 14020200 14022010 14104000 20100322 20123030 20200050 20200053 20200142 20360000 21102230 21102303 21205000 21220014 21253000 21306000 22123002 22130230 22200500 22205300 22242001 22300600 23103023 23120023 23200005 23214200 23230005 23300060 24130302 24132200 24200530 24201420 24250000 24300006 30303353 30400007 30430036 30530007 31330335 31463003 31470000 31573000 32353033 32407000 32436300 32507300 33335303 33400700 33403630 33500730 34333530 34400070 34400363 34500073"

# Nobres oficiais (requisito por cor)
const NOBLES := [
	[0, 0, 4, 4, 0], [0, 0, 0, 4, 4], [0, 4, 4, 0, 0], [4, 4, 0, 0, 0], [4, 0, 0, 0, 4],
	[3, 0, 0, 3, 3], [0, 3, 3, 3, 0], [3, 3, 3, 0, 0], [0, 0, 3, 3, 3], [3, 3, 0, 0, 3],
]

# Adversarios da IA: personagens dos dialogos de Platao, do mais fraco ao mais forte.
const PERSONAS := {"facil": "Lysis", "normal": "Crito", "intermediaria": "Phaedrus",  # tr
	"dificil": "Theaetetus", "muito_dificil": "Timaeus"}  # tr

# Filosofos (antes "nobres"), na ordem de NOBLES; cada um combina com os elementos do seu requisito.
const PHILOSOPHERS := ["Anaxagoras", "Parmenides", "Thales", "Anaximenes", "Democritus",  # tr
	"Heraclitus", "Pythagoras", "Aristotle", "Plato", "Empedocles"]  # tr

# Deck do Caio: (nivel, pv, C4, C2, A, C1, C3). Cada formula gera uma carta por cor.
const FORMULAS_CAIO := [
	[1, 0, 1, 1, 0, 1, 1], [1, 0, 1, 2, 1, 0, 0], [1, 0, 0, 0, 1, 2, 1], [1, 0, 0, 2, 0, 2, 0],
	[1, 0, 0, 2, 1, 0, 0], [1, 0, 2, 0, 0, 0, 2], [1, 0, 0, 0, 0, 3, 0], [1, 1, 0, 0, 4, 0, 0],
	[2, 1, 0, 3, 0, 2, 0], [2, 1, 3, 0, 0, 0, 3], [2, 2, 0, 0, 5, 0, 0], [2, 2, 0, 0, 3, 4, 0],
	[2, 2, 0, 4, 1, 2, 0], [2, 3, 0, 0, 6, 0, 0],
	[3, 3, 0, 5, 2, 2, 0], [3, 4, 0, 0, 5, 5, 0], [3, 4, 3, 6, 0, 0, 0], [3, 5, 0, 0, 0, 7, 3],
]
const OFFSETS := [-2, -1, 0, 1, 2]  # C4, C2, A, C1, C3 relativos a A no ciclo

const DECK_NAMES := {"oficial": "Legacy deck", "caio": "Pentakosmos deck"}  # tr
# pasta da arte de cada deck: assets/cards/<pasta>/
const DECK_DIRS := {"oficial": "legacy", "caio": "pentakosmos"}


class CardDef:
	extends RefCounted
	var id: int
	var level: int
	var bonus: int
	var points: int
	var cost: Array  # 5 inteiros
	var key: String  # nome usado para arte em PNG, ex.: n2_azul_03
	var total: int

	func _init(p_id: int, p_level: int, p_bonus: int, p_points: int, p_cost: Array) -> void:
		id = p_id
		level = p_level
		bonus = p_bonus
		points = p_points
		cost = p_cost
		total = 0
		for x in p_cost:
			total += x


static func build_deck(name: String) -> Array:
	var raw: Array = []  # [nivel, bonus, pontos, custo]
	if name == "caio":
		for f in FORMULAS_CAIO:
			for a in range(5):
				var cost := [0, 0, 0, 0, 0]
				for k in range(5):
					cost[posmod(a + OFFSETS[k], 5)] += f[2 + k]
				raw.append([f[0], a, f[1], cost])
	else:
		for code in OFFICIAL_CODES.split(" "):
			var d: Array = []
			for ch in code:
				d.append(int(ch))
			raw.append([d[0], d[1], d[2], [d[3], d[4], d[5], d[6], d[7]]])
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
