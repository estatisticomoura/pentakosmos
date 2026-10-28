class_name RuleSet
extends RefCounted
## Conjunto de regras. Cada regra e uma opcao independente.

var gems_mode := "classico"      # "classico" (4/5/7/8) ou "house" (4/6/7/8)
var gold_mode := "classico"      # "classico" (5 sempre) ou "house" (4/5/6/7)
var take2_min := 4               # pilha minima para pegar 2 iguais (4 ou 3)
var market5 := 4                 # cartas por grupo com 5 jogadores (4 ou 5)
var deck := "arcaico"            # id do deck: "caio" (Pentakosmos), "arcaico" ou "user:<nome>"
var philosophers := true         # filosofos na mesa
var phil_set := "classico"       # conjunto de filosofos
var noble_free := 0              # filosofos: quantas cartas do requisito podem faltar (0 = exato, ate 5)
var noble_points_mode := "fixo"  # "fixo" (3/3/3) ou "decrescente" (3/2/1)
var writers := true              # escritores na mesa (expansao)
var writer_set := "classico"
var writer_free := 0             # escritores: quantas cartas do requisito podem faltar (0 a 5)
var governors := false           # governantes (expansao)
var gov_set := "classico"
var gov_pick := "escolha"        # "escolha" (cada jogador escolhe, 30 s) ou "sorteio"
var gov_target := 19             # meta de quem nao tem governante, quando ha governantes
var hand_limit := 10             # 9, 10 ou 11
var target := 15                 # 1 a 100
var color_win := 0               # vitoria por especializacao: 0 = desligada; 9 a 12 pontos de cartas numa cor
var see_reserves := "rodada"     # reservas dos outros: "rodada" (ate a proxima vez de quem reservou) ou "sempre"
var time_ai := 0                 # segundos por jogada com um so humano (0 = sem limite)
var time_humans := 60            # segundos por jogada com dois ou mais humanos (0 = sem limite)

const GEMS := {"classico": {2: 4, 3: 5, 4: 7, 5: 8}, "house": {2: 4, 3: 6, 4: 7, 5: 8}}
const GOLDS := {"classico": {2: 5, 3: 5, 4: 5, 5: 5}, "house": {2: 4, 3: 5, 4: 6, 5: 7}}
const KEYS := ["gems_mode", "gold_mode", "take2_min", "market5", "deck", "philosophers", "phil_set",
	"noble_free", "noble_points_mode", "writers", "writer_set", "writer_free", "governors", "gov_set",
	"gov_pick", "gov_target", "hand_limit", "target", "color_win", "see_reserves", "time_ai", "time_humans"]
const TIME_KEYS := ["time_ai", "time_humans"]
const TIMES := [0, 20, 30, 45, 60, 90, 120]
const GOV_PICK_SECONDS := 30
# chaves que apontam para conteudo (decks e conjuntos) -> tipo de conteudo
const CONTENT_KEYS := {"deck": "decks", "phil_set": "philosophers", "writer_set": "writers", "gov_set": "governors"}


func gems_for(n: int) -> int:
	return GEMS[gems_mode][n]


func gold_for(n: int) -> int:
	return GOLDS[gold_mode][n]


func market_for(n: int) -> int:
	return market5 if n == 5 else 4


func noble_discount() -> int:
	return noble_free


func uses_philosophers() -> bool:
	return philosophers


func uses_writers() -> bool:
	return writers


func uses_governors() -> bool:
	return governors


func base_target() -> int:
	## Meta de quem nao tem governante.
	return gov_target if uses_governors() else target


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
	# versoes antigas: requisito "exato"/"flexivel", deck "oficial", "patrons" num texto so
	if d.has("noble_mode") and not d.has("noble_free"):
		r.noble_free = 2 if d["noble_mode"] == "flexivel" else 0
	if d.has("patrons") and not d.has("philosophers"):
		var pt: String = str(d["patrons"])
		r.philosophers = pt in ["ambos", "filosofos"]
		r.writers = pt in ["ambos", "escritores"]
	elif not d.has("philosophers"):
		r.philosophers = true
		r.writers = false
	for k in KEYS:
		if d.has(k):
			r.set(k, d[k])
	for k in ["philosophers", "writers", "governors"]:
		var v = r.get(k)
		r.set(k, v == true or str(v).to_lower() in ["true", "1", "sim", "yes"])
	for k in CONTENT_KEYS:
		r.set(k, str(r.get(k)))
	if r.deck == "oficial" or not Content.exists("decks", r.deck):
		r.deck = "arcaico" if r.deck == "oficial" else "caio"
	if not Content.exists("philosophers", r.phil_set):
		r.phil_set = "classico"
	if not Content.exists("writers", r.writer_set):
		r.writer_set = "classico"
	if not Content.exists("governors", r.gov_set):
		r.gov_set = "classico"
	r.gov_pick = "sorteio" if str(r.gov_pick) == "sorteio" else "escolha"
	r.gov_target = clampi(int(r.gov_target), 1, 100)
	r.noble_free = clampi(int(r.noble_free), 0, 5)
	r.writer_free = clampi(int(r.writer_free), 0, 5)
	r.noble_points_mode = "decrescente" if str(r.noble_points_mode) == "decrescente" else "fixo"
	r.gems_mode = "house" if str(r.gems_mode) == "house" else "classico"
	r.gold_mode = "house" if str(r.gold_mode) == "house" else "classico"
	r.hand_limit = clampi(int(r.hand_limit), 9, 11)
	r.target = clampi(int(r.target), 1, 100)
	r.take2_min = 3 if int(r.take2_min) == 3 else 4
	r.market5 = 5 if int(r.market5) == 5 else 4
	r.color_win = int(r.color_win)
	if r.color_win != 0:
		r.color_win = clampi(r.color_win, 9, 12)
	r.see_reserves = "sempre" if str(r.see_reserves) == "sempre" else "rodada"
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
	r.writers = false
	r.noble_free = 2
	r.noble_points_mode = "decrescente"
	r.deck = "caio"
	r.color_win = 10
	return r


static func house_governors() -> RuleSet:
	## Pentakosmos com escritores e governantes.
	var r := house_full()
	r.writers = true
	r.writer_free = 1
	r.governors = true
	return r


static func builtin_presets() -> Array:
	## [nome, RuleSet]
	return [
		["Pentakosmos", house_full()],
		["Pentakosmos + governors", house_governors()],  # tr
		["Archaic", classic()],  # tr
	]


static func free_label(k: int) -> String:
	return L.t("exact") if k == 0 else L.f("−{n} any", {"n": k})


# --- quanto cada regra foge do habitual (0 = normal, 1 = muito) ----------------
func deviation(key: String) -> float:
	## Usado no destaque vermelho do menu de regras (e, depois, no convite de partida em rede).
	match key:
		"target":
			return _range_dev(target, 12, 18, 10)
		"gov_target":
			return _range_dev(gov_target, 16, 21, 10)
		"hand_limit":
			return 0.0 if hand_limit == 10 else 0.35
		"noble_free", "writer_free":
			var v: int = get(key)
			return 0.0 if v <= 2 else 0.25 * (v - 2)
		"deck", "phil_set", "writer_set", "gov_set":
			var v2: String = get(key)
			return 0.45 if v2.begins_with(Content.USER) else 0.0
		"see_reserves":
			return 0.3 if see_reserves == "sempre" else 0.0
	return 0.0


static func _range_dev(v: int, lo: int, hi: int, span: float) -> float:
	if v < lo:
		return clampf((lo - v) / span, 0.15, 1.0)
	if v > hi:
		return clampf((v - hi) / span, 0.15, 1.0)
	return 0.0


func unusual_count() -> int:
	var k := 0
	for key in KEYS:
		if deviation(key) > 0.0:
			k += 1
	return k


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
		parts.append(L.f("Writers {a}", {"a": free_label(writer_free)}))
	if uses_governors():
		parts.append(L.f("Governors ({how}), goal without one {n}", {"n": gov_target,
			"how": L.t("drawn") if gov_pick == "sorteio" else L.t("chosen")}))
	parts.append(Content.name_of("decks", deck))
	parts.append(L.f("Hand {h} · {t} points", {"h": hand_limit, "t": target}))
	if color_win > 0:
		parts.append(L.f("Specialization: {n} pts in one element", {"n": color_win}))
	if see_reserves == "sempre":
		parts.append(L.t("Reserves always visible"))
	return " · ".join(parts)
