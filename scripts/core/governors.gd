class_name Governors
extends RefCounted
## Governantes: cada um tem uma condicao para ser recebido, um custo (opcional), uma vantagem
## e uma mudanca na meta de pontos de quem o recebe. O motor entende os TIPOS abaixo; os
## governantes em si (nomes, numeros, titulos) vem de uma planilha (a da expansao, ou uma do jogador).

const GROUPS := ["composition", "tokens", "reserves", "position", "price"]
const GROUP_NAMES := {"composition": "By the cards", "tokens": "By the tokens",  # tr
	"reserves": "By the reserves", "position": "By the position", "price": "With a price"}  # tr

# Governantes do jogo base (os outros vem com a expansao)
const BASE := [
	{"name": "Pericles", "group": "composition", "cond": "advanced", "cond_v": 2, "cost": "none", "cost_v": 0,  # tr
		"adv": "none", "adv_v": 0, "target": -4, "title": "The Golden Age"},  # tr
	{"name": "Leonidas", "group": "position", "cond": "last_place", "cond_v": 6, "cost": "none", "cost_v": 0,  # tr
		"adv": "gain_points", "adv_v": 3, "target": -3, "title": "Thermopylae"},  # tr
	{"name": "Alexander the Great", "group": "composition", "cond": "advanced", "cond_v": 3, "cost": "none",  # tr
		"cost_v": 0, "adv": "advanced_bonus", "adv_v": 1, "target": 2, "title": "The known world"},  # tr
]

const CONDITIONS := ["advanced", "equal", "same_element", "no_tokens", "full_hand", "spheres",
	"no_reserve_cards", "reserves", "blind_bought", "last_place", "behind_leader", "streak",
	"near_leader_last", "points", "philosopher_no_advanced", "writers"]
const COSTS := ["none", "lose_points", "return_tokens", "return_spheres", "no_reserve", "return_philosopher"]
const ADVANTAGES := ["none", "gain_points", "gain_tokens", "specialization", "advanced_bonus", "see_hidden",
	"blind_choice", "wins_ties", "extra_turn", "extra_round", "confiscate", "writer_points"]

# Textos (um por tipo); {n} e o valor
const COND_TEXT := {
	"advanced": "{n} advanced cards",  # tr
	"equal": "Cards of the five elements in exactly equal numbers",  # tr
	"same_element": "{n} cards of the same element",  # tr
	"no_tokens": "End your turn with no tokens",  # tr
	"full_hand": "A full hand of tokens",  # tr
	"spheres": "{n} spheres in your hand",  # tr
	"no_reserve_cards": "{n} cards bought without ever reserving",  # tr
	"reserves": "{n} reserved cards",  # tr
	"blind_bought": "Buy a card you reserved face down",  # tr
	"last_place": "Be in last place with at least {n} cards",  # tr
	"behind_leader": "Cards of {n} or more elements and fewer points than the leader",  # tr
	"streak": "Buy a card in {n} turns in a row",  # tr
	"near_leader_last": "Be within {n} points of the leader when the last round begins",  # tr
	"points": "{n} points",  # tr
	"philosopher_no_advanced": "A philosopher and no advanced cards",  # tr
	"writers": "{n} writers",  # tr
}
const COST_TEXT := {
	"none": "",
	"lose_points": "Lose {n} points",  # tr
	"return_tokens": "Return {n} tokens of your choice",  # tr
	"return_spheres": "Return {n} spheres",  # tr
	"no_reserve": "You can never reserve again",  # tr
	"return_philosopher": "Your last philosopher returns to the table",  # tr
}
const ADV_TEXT := {
	"none": "",
	"gain_points": "+{n} points now",  # tr
	"gain_tokens": "Take {n} tokens of different elements",  # tr
	"specialization": "{n} points in one element already win by specialization",  # tr
	"advanced_bonus": "Each advanced card you own is worth +{n} points",  # tr
	"see_hidden": "See every hidden reserve and the top card of each pile",  # tr
	"blind_choice": "When you reserve face down, look at the top {n} cards and choose one",  # tr
	"wins_ties": "You win every tie at the end",  # tr
	"extra_turn": "Play an extra turn right away (once)",  # tr
	"extra_round": "If you do not win, the game gets one more round (once)",  # tr
	"confiscate": "Tokens your opponents return for going over the limit come to you",  # tr
	"writer_points": "Each writer you own is worth {n} points",  # tr
}


static func cond_text(gv: Dictionary) -> String:
	return L.f(COND_TEXT[gv["cond"]], {"n": gv["cond_v"]})


static func cost_text(gv: Dictionary) -> String:
	return L.f(COST_TEXT[gv["cost"]], {"n": gv["cost_v"]}) if gv["cost"] != "none" else ""


static func adv_text(gv: Dictionary) -> String:
	return L.f(ADV_TEXT[gv["adv"]], {"n": gv["adv_v"]}) if gv["adv"] != "none" else ""


static func target_text(gv: Dictionary, base: int) -> String:
	var t: int = maxi(1, base + int(gv["target"]))
	if gv["target"] == 0:
		return L.f("Goal stays at {n} points", {"n": t})
	return L.f("Win with {n} points", {"n": t})


# ---------------------------------------------------------------------------
# Condicoes
# ---------------------------------------------------------------------------
static func advanced_count(g: GameState, p: GameState.PlayerState) -> int:
	var k := 0
	for cid in p.owned:
		if g.cards[cid].level == 3:
			k += 1
	return k


static func meets(g: GameState, idx: int, gv: Dictionary) -> bool:
	var p: GameState.PlayerState = g.players[idx]
	var v: int = gv["cond_v"]
	match gv["cond"]:
		"advanced":
			return advanced_count(g, p) >= v
		"equal":
			var b0: int = p.bonus[0]
			if b0 < 1:
				return false
			for c in range(5):
				if p.bonus[c] != b0:
					return false
			return true
		"same_element":
			return p.bonus.max() >= v
		"no_tokens":
			return p.token_count() == 0
		"full_hand":
			return p.token_count() >= g.rules.hand_limit
		"spheres":
			return p.tokens[GameState.GOLD] >= v
		"no_reserve_cards":
			return p.cards >= v and p.reserves == 0
		"reserves":
			return p.reserved.size() >= v
		"blind_bought":
			return p.blind_bought
		"last_place":
			if p.cards < v:
				return false
			for q in g.players:
				if q.points < p.points:
					return false
			return true
		"behind_leader":
			var elems := 0
			for c in range(5):
				if p.bonus[c] > 0:
					elems += 1
			var lead := 0
			for q in g.players:
				lead = maxi(lead, q.points)
			return elems >= v and p.points < lead
		"streak":
			return p.buy_streak >= v
		"near_leader_last":
			if not g.end_triggered:
				return false
			var lead2 := 0
			for q in g.players:
				lead2 = maxi(lead2, q.points)
			return lead2 - p.points <= v
		"points":
			return p.points >= v
		"philosopher_no_advanced":
			return GameState.philosopher_count(p) >= 1 and advanced_count(g, p) == 0
		"writers":
			return p.nobles.size() - GameState.philosopher_count(p) >= v
	return false


static func can_pay(g: GameState, idx: int, gv: Dictionary) -> bool:
	## Custos que exigem ter algo: devolver um filosofo exige ter um.
	var p: GameState.PlayerState = g.players[idx]
	if gv["cost"] == "return_philosopher":
		return GameState.philosopher_count(p) >= 1
	return true


# ---------------------------------------------------------------------------
# Valor para a IA: quanto vale aceitar este governante agora (pontos aproximados)
# ---------------------------------------------------------------------------
static func value_for(g: GameState, idx: int, gv: Dictionary) -> float:
	var p: GameState.PlayerState = g.players[idx]
	var v: float = -float(gv["target"])
	var n: int = gv["adv_v"]
	match gv["adv"]:
		"gain_points":
			v += n
		"gain_tokens":
			v += 0.5 * mini(n, maxi(0, g.rules.hand_limit - p.token_count()))
		"specialization":
			v += 2.0 if g.rules.color_win == 0 else 1.0
		"advanced_bonus":
			v += n * (advanced_count(g, p) + 1)
		"see_hidden":
			v += 0.2
		"blind_choice":
			v += 0.4
		"wins_ties":
			v += 0.6
		"extra_turn":
			v += 2.0
		"extra_round":
			v += 1.0
		"confiscate":
			v += 1.0
		"writer_points":
			var w := p.nobles.size() - GameState.philosopher_count(p)
			v += (n - 1) * (w + 0.5)
	var c: int = gv["cost_v"]
	match gv["cost"]:
		"lose_points":
			v -= c
		"return_tokens":
			v -= 0.5 * mini(c, p.token_count())
		"return_spheres":
			v -= 0.8 * mini(c, p.tokens[GameState.GOLD])
		"no_reserve":
			v -= 1.5
		"return_philosopher":
			v -= p.last_philosopher_pts()
	return v


static func ease_of(g: GameState, gv: Dictionary) -> float:
	## Facilidade aproximada de cumprir a condicao (para a escolha da IA no inicio).
	var v: int = gv["cond_v"]
	match gv["cond"]:
		"advanced":
			return clampf(1.0 - 0.2 * v, 0.2, 0.9)
		"equal":
			return 0.25
		"same_element":
			return clampf(1.0 - 0.1 * v, 0.2, 0.8)
		"no_tokens":
			return 0.35
		"full_hand":
			return 0.8
		"spheres":
			return clampf(1.0 - 0.2 * v, 0.2, 0.8)
		"no_reserve_cards":
			return 0.45
		"reserves":
			return clampf(1.0 - 0.2 * v, 0.2, 0.8)
		"blind_bought":
			return 0.3
		"last_place":
			return 0.4
		"behind_leader":
			return 0.55
		"streak":
			return clampf(1.0 - 0.17 * v, 0.2, 0.8)
		"near_leader_last":
			return 0.45
		"points":
			return clampf(1.0 - 0.06 * v, 0.2, 0.95)
		"philosopher_no_advanced":
			return 0.4 if g.rules.uses_philosophers() else 0.0
		"writers":
			return clampf(0.7 - 0.2 * v, 0.1, 0.6) if g.rules.uses_writers() else 0.0
	return 0.3


static func ai_pick(g: GameState, idx: int, options: Array) -> int:
	## Indice (em g.governors) escolhido pela IA no inicio da partida.
	var best := -1
	var best_v := -1e9
	for gi in options:
		var gv: Dictionary = g.governors[gi]
		var v := (2.0 + value_for(g, idx, gv)) * ease_of(g, gv) + g.rng.randf() * 0.6
		if v > best_v:
			best_v = v
			best = gi
	return best
