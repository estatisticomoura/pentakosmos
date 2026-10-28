class_name RuleSet
extends RefCounted
## Conjunto de regras. Cada house rule e uma opcao independente.

var gems_mode := "classico"      # "classico" (4/5/7/8) ou "house" (4/6/7/8)
var gold_mode := "classico"      # "classico" (5 sempre) ou "house" (4/5/6/7)
var take2_min := 4               # pilha minima para pegar 2 iguais (4 ou 3)
var market5 := 4                 # cartas por grupo com 5 jogadores (4 ou 5)
var patrons := "ambos"           # quem pode vir: "ambos", "filosofos", "escritores" ou "nenhum"
var noble_free := 0              # filosofos: quantas cartas do requisito podem faltar (0 = exato, ate 5)
var noble_points_mode := "fixo"  # "fixo" (3/3/3) ou "decrescente" (3/2/1)
var writer_free := 0             # escritores: quantas cartas do requisito podem faltar (0 a 5)
var deck := "arcaico"            # "arcaico" ou "caio" (Pentakosmos)
var hand_limit := 10             # 9, 10 ou 11
var target := 15                 # 10 a 25
var color_win := 0               # vitoria por especializacao: 0 = desligada; 9 a 12 pontos de cartas numa cor
var time_ai := 0                 # segundos por jogada com um so humano (0 = sem limite)
var time_humans := 60            # segundos por jogada com dois ou mais humanos (0 = sem limite)

const GEMS := {"classico": {2: 4, 3: 5, 4: 7, 5: 8}, "house": {2: 4, 3: 6, 4: 7, 5: 8}}
const GOLDS := {"classico": {2: 5, 3: 5, 4: 5, 5: 5}, "house": {2: 4, 3: 5, 4: 6, 5: 7}}
const KEYS := ["gems_mode", "gold_mode", "take2_min", "market5", "patrons", "noble_free",
	"noble_points_mode", "writer_free", "deck", "hand_limit", "target", "color_win", "time_ai", "time_humans"]
const TIME_KEYS := ["time_ai", "time_humans"]
const TIMES := [0, 20, 30, 45, 60, 90, 120]
const PATRONS := ["ambos", "filosofos", "escritores", "nenhum"]


func gems_for(n: int) -> int:
	return GEMS[gems_mode][n]


func gold_for(n: int) -> int:
	return GOLDS[gold_mode][n]


func market_for(n: int) -> int:
	return market5 if n == 5 else 4


func noble_discount() -> int:
	return noble_free


func uses_philosophers() -> bool:
	return patrons == "ambos" or patrons == "filosofos"


func uses_writers() -> bool:
	return patrons == "ambos" or patrons == "escritores"


func noble_pts(k: int) -> int:
	## Pontos do (k+1)-esimo filosofo do mesmo jogador.
	if noble_points_mode == "decrescente":
		return [3, 2, 1][min(k, 2)]
	return 3


func turn_time(humans: int) -> int:
	## Segundos por jogada (0 = sem limite): "entre humanos" vale com 2 ou mais humanos.
	return time_humans if humans >= 2 else time_ai


func to_dict() -> Dictionary:
	var d := {}
	for k in KEYS:
		d[k] = get(k)
	return d


static func from_dict(d: Dictionary) -> RuleSet:
	var r := RuleSet.new()
	# versoes antigas: requisito "exato"/"flexivel", deck "oficial", sem escritores
	if d.has("noble_mode") and not d.has("noble_free"):
		r.noble_free = 2 if d["noble_mode"] == "flexivel" else 0
	if not d.has("patrons"):
		r.patrons = "filosofos"
	for k in KEYS:
		if d.has(k):
			r.set(k, d[k])
	if r.deck == "oficial" or not Defs.DECK_NAMES.has(r.deck):
		r.deck = "arcaico"
	if not PATRONS.has(r.patrons):
		r.patrons = "ambos"
	r.noble_free = clampi(int(r.noble_free), 0, 5)
	r.writer_free = clampi(int(r.writer_free), 0, 5)
	r.hand_limit = clampi(int(r.hand_limit), 9, 11)
	r.target = clampi(int(r.target), 10, 25)
	r.take2_min = 3 if int(r.take2_min) == 3 else 4
	r.market5 = 5 if int(r.market5) == 5 else 4
	r.color_win = int(r.color_win)
	if r.color_win != 0:
		r.color_win = clampi(r.color_win, 9, 12)
	r.time_ai = int(r.time_ai) if TIMES.has(int(r.time_ai)) else 0
	r.time_humans = int(r.time_humans) if TIMES.has(int(r.time_humans)) else 60
	return r


func copy() -> RuleSet:
	return RuleSet.from_dict(to_dict())


func equals(o: RuleSet) -> bool:
	return to_dict() == o.to_dict()


func same_game(o: RuleSet) -> bool:
	## Mesmas regras de jogo (ignora os cronometros).
	var a := to_dict()
	var b := o.to_dict()
	for k in TIME_KEYS:
		a.erase(k)
		b.erase(k)
	return a == b


# --- predefinicoes -----------------------------------------------------------
static func classic() -> RuleSet:
	## Arcaico: regras tradicionais, deck Arcaico, filosofos e escritores.
	return RuleSet.new()


static func house_full() -> RuleSet:
	var r := RuleSet.new()
	r.gems_mode = "house"
	r.gold_mode = "house"
	r.take2_min = 3
	r.market5 = 5
	r.patrons = "filosofos"
	r.noble_free = 2
	r.noble_points_mode = "decrescente"
	r.deck = "caio"
	r.color_win = 10
	return r


static func builtin_presets() -> Array:
	## [nome, RuleSet]
	return [
		["Pentakosmos", house_full()],
		["Archaic", classic()],  # tr
	]


static func free_label(k: int) -> String:
	return L.t("exact") if k == 0 else L.f("−{n} any", {"n": k})


func summary() -> String:
	var parts: Array = []
	parts.append(L.f("Solids {v}", {"v": "4/6/7/8" if gems_mode == "house" else "4/5/7/8"}))
	parts.append(L.f("Spheres {v}", {"v": "4/5/6/7" if gold_mode == "house" else "5"}))
	parts.append(L.f("Take 2 with {n}+", {"n": take2_min}))
	parts.append(L.f("5p market: {n}", {"n": market5}))
	if uses_philosophers():
		parts.append(L.f("Philosophers {a}, {b}", {"a": free_label(noble_free),
			"b": "3/2/1" if noble_points_mode == "decrescente" else L.t("3 pts")}))
	if uses_writers():
		parts.append(L.f("Writers {a}, 1 pt", {"a": free_label(writer_free)}))
	parts.append(L.t(Defs.DECK_NAMES[deck]))
	parts.append(L.f("Hand {h} · {t} points", {"h": hand_limit, "t": target}))
	if color_win > 0:
		parts.append(L.f("Specialization: {n} pts in one element", {"n": color_win}))
	return " · ".join(parts)
