class_name GameState
extends RefCounted
## Motor de regras. Nao depende da interface: a UI chama as acoes e le o estado.
## Cada acao gera eventos em `events` (a UI os consome para animar e registrar).

const GOLD := Defs.GOLD


class PlayerState:
	extends RefCounted
	var name := ""
	var kind := "humano"  # "humano" ou um nivel/perfil de IA (ver AIProfiles)
	var tokens := [0, 0, 0, 0, 0, 0]
	var bonus := [0, 0, 0, 0, 0]
	var points := 0
	var reserved: Array = []
	var owned: Array = []
	var nobles: Array = []
	var noble_points := 0
	var cards := 0
	var turns := 0
	var reserves := 0
	var discards := 0
	var hidden: Array = []  # reservas feitas as cegas (ocultas para os outros)
	var reserved_at := {}   # carta -> turno global em que foi reservada
	var color_pts := [0, 0, 0, 0, 0]  # pontos das cartas compradas, por cor de bonus
	var color_done := false            # ja cumpriu a vitoria por especializacao
	# IA
	var policy := "plano"
	var params: Dictionary = {}
	var denial := -1.0
	var endgame := false
	var plan = null
	var plan_round := -99
	var replans := 0
	var blocks := 0

	func clone() -> PlayerState:
		var q := PlayerState.new()
		q.name = name
		q.kind = kind
		q.tokens = tokens.duplicate()
		q.bonus = bonus.duplicate()
		q.points = points
		q.reserved = reserved.duplicate()
		q.owned = owned.duplicate()
		q.nobles = nobles.duplicate()
		q.noble_points = noble_points
		q.cards = cards
		q.turns = turns
		q.hidden = hidden.duplicate()
		q.reserved_at = reserved_at.duplicate()
		q.color_pts = color_pts.duplicate()
		q.color_done = color_done
		q.policy = policy
		q.params = params
		q.denial = denial
		q.endgame = endgame
		q.plan = plan.duplicate(true) if plan != null else null
		q.plan_round = plan_round
		return q

	func token_count() -> int:
		var s := 0
		for x in tokens:
			s += x
		return s

	func is_ai() -> bool:
		return kind != "humano"


var rules: RuleSet
var n := 0
var rng := RandomNumberGenerator.new()
var cards: Array = []
var bank := [0, 0, 0, 0, 0, 0]
var decks := [[], [], [], []]   # indices 1..3
var market := [[], [], [], []]  # indices 1..3; -1 = vazio
var nobles: Array = []
var players: Array = []
var current := 0
var round_no := 1
var end_triggered := false
var finished := false
var phase := "acao"             # "acao", "descarte", "nobre", "fim"
var noble_options: Array = []
var events: Array = []
var passes_in_round := 0
var max_rounds := 150
# estatisticas
var turns_total := 0
var empty_sum := 0


func setup(p_rules: RuleSet, configs: Array, seed: int = 0) -> void:
	## configs: lista de {"name": String, "kind": "humano"|"facil"|"normal"}
	rules = p_rules
	n = configs.size()
	assert(n >= 2 and n <= 5)
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	cards = Defs.build_deck(rules.deck)
	var g := rules.gems_for(n)
	bank = [g, g, g, g, g, rules.gold_for(n)]
	decks = [[], [], [], []]
	for c in cards:
		decks[c.level].append(c.id)
	for lv in [1, 2, 3]:
		_shuffle(decks[lv])
	var m := rules.market_for(n)
	market = [[], [], [], []]
	for lv in [1, 2, 3]:
		for i in range(m):
			market[lv].append(decks[lv].pop_back() if not decks[lv].is_empty() else -1)
	var pool := range(Defs.NOBLES.size())
	_shuffle(pool)
	nobles = pool.slice(0, mini(n + 1, pool.size()))
	players = []
	for cfg in configs:
		var p := PlayerState.new()
		p.name = cfg.get("name", "Jogador")
		p.kind = cfg.get("kind", "humano")
		var prof := AIProfiles.profile("normal" if p.kind == "humano" else p.kind, rules)
		p.policy = prof["policy"]
		p.params = prof["params"]
		p.denial = prof["denial"]
		p.endgame = prof["endgame"]
		players.append(p)
	current = 0
	round_no = 1
	end_triggered = false
	finished = false
	events = []
	passes_in_round = 0
	_start_turn()


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------
func cur() -> PlayerState:
	return players[current]


func card(cid: int) -> Defs.CardDef:
	return cards[cid]


func market_cards() -> Array:
	## [[nivel, posicao, id], ...]
	var out: Array = []
	for lv in [1, 2, 3]:
		for slot in range(market[lv].size()):
			var cid: int = market[lv][slot]
			if cid >= 0:
				out.append([lv, slot, cid])
	return out


static func shortfall_of(p: PlayerState, cost: Array, tokens = null) -> int:
	var t: Array = p.tokens if tokens == null else tokens
	var s := 0
	for c in range(5):
		var need: int = cost[c] - p.bonus[c] - t[c]
		if need > 0:
			s += need
	return s - t[GOLD]


func can_afford(p: PlayerState, cid: int) -> bool:
	return shortfall_of(p, cards[cid].cost) <= 0


func best_color(p: PlayerState) -> int:
	var best := 0
	for c in range(5):
		if p.color_pts[c] > p.color_pts[best]:
			best = c
	return best


func reserve_visible(owner: int, cid: int, viewer: int, mode: String = "rodada") -> bool:
	## Uma carta reservada do mercado fica visivel para os outros ate a proxima
	## vez de quem a reservou (mode "rodada") ou sempre (mode "sempre").
	## Reservas as cegas so sao visiveis para o dono.
	if owner == viewer:
		return true
	var p: PlayerState = players[owner]
	if p.hidden.has(cid):
		return false
	if mode == "sempre":
		return true
	return turns_total - int(p.reserved_at.get(cid, -999)) < n


func meets_color(p: PlayerState) -> bool:
	## Vitoria por especializacao: pontos de cartas numa mesma cor >= limite.
	return rules.color_win > 0 and p.color_pts[best_color(p)] >= rules.color_win


func noble_distance(bonus: Array, req: Array) -> int:
	## Cartas que faltam para receber o nobre (considera a regra flexivel).
	if rules.noble_discount() == 0:
		var s := 0
		for c in range(5):
			if req[c] > bonus[c]:
				s += req[c] - bonus[c]
		return s
	var total := 0
	var have := 0
	for c in range(5):
		total += req[c]
		have += mini(bonus[c], req[c])
	return maxi(0, total - rules.noble_discount() - have)


func available_colors() -> int:
	var k := 0
	for c in range(5):
		if bank[c] > 0:
			k += 1
	return k


func valid_take(colors: Array) -> bool:
	if colors.is_empty() or colors.size() > 3:
		return false
	for c in colors:
		if c < 0 or c >= 5:
			return false
	if colors.size() == 2 and colors[0] == colors[1]:
		return bank[colors[0]] >= rules.take2_min
	var seen := {}
	for c in colors:
		if seen.has(c) or bank[c] <= 0:
			return false
		seen[c] = true
	# 1, 2 ou 3 cores diferentes: pegar menos e opcao do jogador
	return true


func can_take_two(c: int) -> bool:
	return bank[c] >= rules.take2_min


func can_reserve() -> bool:
	return cur().reserved.size() < 3


func has_any_action() -> bool:
	var p := cur()
	if available_colors() > 0:
		return true
	if p.reserved.size() < 3:
		for lv in [1, 2, 3]:
			if not decks[lv].is_empty() or market[lv].any(func(x): return x >= 0):
				return true
	for e in market_cards():
		if can_afford(p, e[2]):
			return true
	for cid in p.reserved:
		if can_afford(p, cid):
			return true
	return false


# ---------------------------------------------------------------------------
# Acoes do jogador da vez (retornam true se a acao foi aceita)
# ---------------------------------------------------------------------------
func act_take(colors: Array) -> bool:
	if phase != "acao" or not valid_take(colors):
		return false
	var p := cur()
	for c in colors:
		bank[c] -= 1
		p.tokens[c] += 1
	events.append({"t": "take", "p": current, "colors": colors.duplicate()})
	_after_action()
	return true


func act_buy_market(lv: int, slot: int) -> bool:
	if phase != "acao":
		return false
	var cid: int = market[lv][slot]
	if cid < 0 or not can_afford(cur(), cid):
		return false
	var paid := _pay_and_gain(cur(), cid)
	_refill(lv, slot)
	events.append({"t": "buy", "p": current, "card": cid, "src": "m", "lv": lv, "slot": slot, "paid": paid})
	_after_action()
	return true


func act_buy_reserved(i: int) -> bool:
	if phase != "acao":
		return false
	var p := cur()
	if i < 0 or i >= p.reserved.size():
		return false
	var cid: int = p.reserved[i]
	if not can_afford(p, cid):
		return false
	p.reserved.remove_at(i)
	p.hidden.erase(cid)
	p.reserved_at.erase(cid)
	var paid := _pay_and_gain(p, cid)
	events.append({"t": "buy", "p": current, "card": cid, "src": "r", "idx": i, "paid": paid})
	_after_action()
	return true


func act_reserve(lv: int, slot: int) -> bool:
	## slot = -1 reserva a carta do topo do baralho (as cegas)
	if phase != "acao" or not can_reserve():
		return false
	var p := cur()
	var cid := -1
	if slot < 0:
		if decks[lv].is_empty():
			return false
		cid = decks[lv].pop_back()
	else:
		cid = market[lv][slot]
		if cid < 0:
			return false
		_refill(lv, slot)
	p.reserved.append(cid)
	p.reserved_at[cid] = turns_total
	if slot < 0:
		p.hidden.append(cid)
	p.reserves += 1
	var got_gold := false
	if bank[GOLD] > 0:
		bank[GOLD] -= 1
		p.tokens[GOLD] += 1
		got_gold = true
	events.append({"t": "reserve", "p": current, "card": cid, "lv": lv, "slot": slot,
		"blind": slot < 0, "gold": got_gold})
	_after_action()
	return true


func act_pass() -> bool:
	if phase != "acao":
		return false
	passes_in_round += 1
	events.append({"t": "pass", "p": current})
	_after_action()
	return true


func discard(color: int) -> bool:
	## Usado na fase de descarte (jogador humano acima do limite de mao).
	if phase != "descarte":
		return false
	var p := cur()
	if p.tokens[color] <= 0:
		return false
	p.tokens[color] -= 1
	bank[color] += 1
	p.discards += 1
	events.append({"t": "discard", "p": current, "color": color})
	if p.token_count() <= rules.hand_limit:
		phase = "acao"
		_check_nobles()
	return true


func choose_noble(nb: int) -> bool:
	if phase != "nobre" or not noble_options.has(nb):
		return false
	_claim_noble(current, nb)
	noble_options = []
	phase = "acao"
	_end_turn()
	return true


func apply_ai_action(act: Array) -> void:
	match act[0]:
		"buy":
			if act[1] == "m":
				act_buy_market(act[2], act[3])
			else:
				act_buy_reserved(act[2])
		"take":
			act_take(act[1])
		"reserve":
			act_reserve(act[1], act[2])
		_:
			act_pass()


# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------
func _pay_and_gain(p: PlayerState, cid: int) -> Array:
	var cd: Defs.CardDef = cards[cid]
	var paid := [0, 0, 0, 0, 0, 0]
	var gold_needed := 0
	for c in range(5):
		var need: int = cd.cost[c] - p.bonus[c]
		if need <= 0:
			continue
		var use: int = mini(need, p.tokens[c])
		p.tokens[c] -= use
		bank[c] += use
		paid[c] = use
		gold_needed += need - use
	p.tokens[GOLD] -= gold_needed
	bank[GOLD] += gold_needed
	paid[GOLD] = gold_needed
	p.bonus[cd.bonus] += 1
	p.points += cd.points
	p.color_pts[cd.bonus] += cd.points
	p.cards += 1
	p.owned.append(cid)
	return paid


func _refill(lv: int, slot: int) -> void:
	market[lv][slot] = decks[lv].pop_back() if not decks[lv].is_empty() else -1


func _after_action() -> void:
	var p := cur()
	if p.token_count() > rules.hand_limit:
		if p.is_ai():
			for c in AI.discard_choices(self, current):
				p.tokens[c] -= 1
				bank[c] += 1
				p.discards += 1
				events.append({"t": "discard", "p": current, "color": c})
		else:
			phase = "descarte"
			return
	_check_nobles()


func _check_nobles() -> void:
	var p := cur()
	var ok: Array = []
	for nb in nobles:
		if noble_distance(p.bonus, Defs.NOBLES[nb]) == 0:
			ok.append(nb)
	if ok.is_empty():
		_end_turn()
		return
	if ok.size() == 1:
		_claim_noble(current, ok[0])
		_end_turn()
		return
	if p.is_ai():
		_claim_noble(current, AI.pick_noble(self, current, ok))
		_end_turn()
		return
	phase = "nobre"
	noble_options = ok


func _claim_noble(idx: int, nb: int) -> void:
	var p: PlayerState = players[idx]
	nobles.erase(nb)
	var pts := rules.noble_pts(p.nobles.size())
	p.nobles.append(nb)
	p.points += pts
	p.noble_points += pts
	events.append({"t": "noble", "p": idx, "noble": nb, "pts": pts})


func _start_turn() -> void:
	phase = "acao"
	cur().turns += 1


func _end_turn() -> void:
	turns_total += 1
	for c in range(5):
		if bank[c] == 0:
			empty_sum += 1
	var p := cur()
	if meets_color(p) and not p.color_done:
		p.color_done = true
		events.append({"t": "color", "p": current, "color": best_color(p), "pts": p.color_pts[best_color(p)]})
	if (p.points >= rules.target or meets_color(p)) and not end_triggered:
		end_triggered = true
		events.append({"t": "last_round", "p": current, "reason": "cor" if meets_color(p) else "pontos"})
	current += 1
	if current >= n:
		current = 0
		var all_passed := passes_in_round >= n
		passes_in_round = 0
		if end_triggered or all_passed or round_no >= max_rounds:
			_finish()
			return
		round_no += 1
	_start_turn()


func _finish() -> void:
	finished = true
	phase = "fim"
	events.append({"t": "end"})


# ---------------------------------------------------------------------------
# Copias para busca (IA)
# ---------------------------------------------------------------------------
func clone_for_search(observer: int, seed: int) -> GameState:
	## Copia do estado para simulacoes. Todos os jogadores passam a jogar como a
	## IA estrategista (sem busca), e o que o observador nao conhece (ordem dos
	## baralhos e reservas as cegas dos adversarios) e sorteado de novo.
	var g := GameState.new()
	g.rules = rules
	g.n = n
	g.rng.seed = seed
	g.cards = cards
	g.bank = bank.duplicate()
	g.decks = [[], decks[1].duplicate(), decks[2].duplicate(), decks[3].duplicate()]
	g.market = [[], market[1].duplicate(), market[2].duplicate(), market[3].duplicate()]
	g.nobles = nobles.duplicate()
	g.players = []
	var normal := AIProfiles.profile("normal", rules)
	for p in players:
		var q: PlayerState = p.clone()
		if q.kind == "humano":
			q.kind = "normal"
		q.endgame = false
		q.denial = -1.0
		if q.params.is_empty():
			q.params = normal["params"]
		g.players.append(q)
	g.current = current
	g.round_no = round_no
	g.end_triggered = end_triggered
	g.finished = finished
	g.phase = "acao"
	g.passes_in_round = passes_in_round
	g.max_rounds = max_rounds
	# determinizacao
	for lv in [1, 2, 3]:
		var pool: Array = g.decks[lv].duplicate()
		var slots: Array = []
		for j in range(n):
			if j == observer:
				continue
			var q: PlayerState = g.players[j]
			for k in range(q.reserved.size()):
				var cid: int = q.reserved[k]
				if q.hidden.has(cid) and cards[cid].level == lv:
					pool.append(cid)
					slots.append([j, k])
		g._shuffle(pool)
		for s in slots:
			var q2: PlayerState = g.players[s[0]]
			var old: int = q2.reserved[s[1]]
			var nw: int = pool.pop_back()
			q2.reserved[s[1]] = nw
			q2.hidden.erase(old)
			q2.hidden.append(nw)
		g.decks[lv] = pool
	return g


func ranking() -> Array:
	## Indices dos jogadores do 1o ao ultimo. Quem cumpriu a vitoria por
	## especializacao vem antes; depois pontos (desc) e cartas compradas (asc).
	var idx := range(n)
	idx.sort_custom(func(a, b):
		var pa: PlayerState = players[a]
		var pb: PlayerState = players[b]
		var ca := meets_color(pa)
		var cb := meets_color(pb)
		if ca != cb:
			return ca
		if pa.points != pb.points:
			return pa.points > pb.points
		return pa.cards < pb.cards)
	return idx


func winners() -> Array:
	var r := ranking()
	var best: PlayerState = players[r[0]]
	var out: Array = []
	for i in r:
		var p: PlayerState = players[i]
		if p.points == best.points and p.cards == best.cards and meets_color(p) == meets_color(best):
			out.append(i)
	return out
