class_name RuleSet
extends RefCounted
## Conjunto de regras. Cada house rule e uma opcao independente.

var gems_mode := "classico"      # "classico" (4/5/7/8) ou "house" (4/6/7/8)
var gold_mode := "classico"      # "classico" (5 sempre) ou "house" (4/5/6/7)
var take2_min := 4               # pilha minima para pegar 2 iguais (4 ou 3)
var market5 := 4                 # cartas por nivel com 5 jogadores (4 ou 5)
var noble_mode := "exato"        # "exato" ou "flexivel" (requisito total -2)
var noble_points_mode := "fixo"  # "fixo" (3/3/3) ou "decrescente" (3/2/1)
var deck := "oficial"            # "oficial" ou "caio"
var hand_limit := 10             # 9, 10 ou 11
var target := 15                 # 12 a 18
var color_win := 0               # vitoria por especializacao: 0 = desligada; 9 a 12 pontos de cartas numa cor

const GEMS := {"classico": {2: 4, 3: 5, 4: 7, 5: 8}, "house": {2: 4, 3: 6, 4: 7, 5: 8}}
const GOLDS := {"classico": {2: 5, 3: 5, 4: 5, 5: 5}, "house": {2: 4, 3: 5, 4: 6, 5: 7}}
const KEYS := ["gems_mode", "gold_mode", "take2_min", "market5", "noble_mode",
	"noble_points_mode", "deck", "hand_limit", "target", "color_win"]


func gems_for(n: int) -> int:
	return GEMS[gems_mode][n]


func gold_for(n: int) -> int:
	return GOLDS[gold_mode][n]


func market_for(n: int) -> int:
	return market5 if n == 5 else 4


func noble_discount() -> int:
	return 2 if noble_mode == "flexivel" else 0


func noble_pts(k: int) -> int:
	## Pontos do (k+1)-esimo nobre do mesmo jogador.
	if noble_points_mode == "decrescente":
		return [3, 2, 1][min(k, 2)]
	return 3


func to_dict() -> Dictionary:
	var d := {}
	for k in KEYS:
		d[k] = get(k)
	return d


static func from_dict(d: Dictionary) -> RuleSet:
	var r := RuleSet.new()
	for k in KEYS:
		if d.has(k):
			r.set(k, d[k])
	r.hand_limit = clampi(int(r.hand_limit), 9, 11)
	r.target = clampi(int(r.target), 12, 18)
	r.take2_min = 3 if int(r.take2_min) == 3 else 4
	r.market5 = 5 if int(r.market5) == 5 else 4
	r.color_win = int(r.color_win)
	if r.color_win != 0:
		r.color_win = clampi(r.color_win, 9, 12)
	return r


func copy() -> RuleSet:
	return RuleSet.from_dict(to_dict())


func equals(o: RuleSet) -> bool:
	return to_dict() == o.to_dict()


# --- predefinicoes -----------------------------------------------------------
static func classic() -> RuleSet:
	return RuleSet.new()


static func house_full() -> RuleSet:
	var r := RuleSet.new()
	r.gems_mode = "house"
	r.gold_mode = "house"
	r.take2_min = 3
	r.market5 = 5
	r.noble_mode = "flexivel"
	r.noble_points_mode = "decrescente"
	r.deck = "caio"
	r.color_win = 10
	return r


static func builtin_presets() -> Array:
	## [nome, RuleSet]
	return [
		["Pentakosmos", house_full()],
		["Legacy", classic()],
	]


func summary() -> String:
	var parts: Array = []
	parts.append(L.f("Solids {v}", {"v": "4/6/7/8" if gems_mode == "house" else "4/5/7/8"}))
	parts.append(L.f("Spheres {v}", {"v": "4/5/6/7" if gold_mode == "house" else "5"}))
	parts.append(L.f("Take 2 with {n}+", {"n": take2_min}))
	parts.append(L.f("5p market: {n}", {"n": market5}))
	parts.append(L.f("Philosophers {a}, {b}", {"a": L.t("−2 any") if noble_mode == "flexivel" else L.t("exact"),
		"b": "3/2/1" if noble_points_mode == "decrescente" else L.t("3 pts")}))
	parts.append(L.t(Defs.DECK_NAMES[deck]))
	parts.append(L.f("Hand {h} · {t} points", {"h": hand_limit, "t": target}))
	if color_win > 0:
		parts.append(L.f("Specialization: {n} pts in one element", {"n": color_win}))
	return " · ".join(parts)
