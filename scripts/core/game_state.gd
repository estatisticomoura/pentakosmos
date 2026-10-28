class_name GameState
extends RefCounted
## Motor de regras. Nao depende da interface: a UI chama as acoes e le o estado.
## Cada acao gera eventos em `events` (a UI os consome para animar e registrar).
##
## O fim da vez e uma fila de passos ("card_gain", "limit", "nobles", "governors", "end"...).
## Um passo que precisa de uma decisao de um jogador humano muda `phase` e para; a resposta
## (discard, gain, choose_noble, choose_governor, choose_blind) retoma a fila.

const GOLD := Defs.GOLD


class PlayerState:
	extends RefCounted
	var name := ""
	var kind := "humano"  # "humano" ou um nivel/perfil de IA (ver AIProfiles)
	var tokens := [0, 0, 0, 0, 0, 0]
	var bonus := [0, 0, 0, 0, 0]
	var solids := [0, 0, 0, 0, 0]      # cartas de um solido so, por cor (o coringa exige ter alguma)
	var joker := {}                    # carta coringa -> cor escolhida
	var points := 0
	var reserved: Array = []
	var owned: Array = []
	var nobles: Array = []
	var patron_pts := {}               # filosofo/escritor -> pontos que deu
	var noble_points := 0
	var cards := 0
	var turns := 0
	var reserves := 0
	var discards := 0
	var hidden: Array = []  # reservas feitas as cegas (ocultas para os outros)
	var reserved_at := {}   # carta -> turno global em que foi reservada
	var color_pts := [0, 0, 0, 0, 0]  # pontos das cartas compradas, por cor de bonus
	var color_done := false            # ja cumpriu a vitoria por especializacao
	# governantes e efeitos
	var governor := -1                 # indice em GameState.governors (-1 = nenhum)
	var gov_choice := -1               # governante que escolheu no inicio
	var gov_refused: Array = []
	var buy_streak := 0
	var bought_turn := false
	var blind_bought := false
	var no_reserve := false
	var spec_n := 0                    # especializacao com menos pontos (governante)
	var adv_bonus := 0                 # pontos extras por carta avancada (governante)
	var writer_pts := 0                # pontos de cada escritor (governante; 0 = normal)
	var extra_turns := 0
	var extra_round_used := false
	# IA
	var policy := "plano"
	var params: Dictionary = {}
	var denial := -1.0
	var endgame := false
	var defend := false      # reserva defensiva (tira do mercado o que um adversario vai comprar)
	var plan = null
	var plan_round := -99
	var replans := 0
	var blocks := 0

	func clone() -> PlayerState:
		var q := PlayerState.new()
		for k in ["name", "kind", "points", "noble_points", "cards", "turns", "reserves", "discards",
				"color_done", "governor", "gov_choice", "buy_streak", "bought_turn", "blind_bought", "no_reserve",
				"spec_n", "adv_bonus", "writer_pts", "extra_turns", "extra_round_used", "policy", "params",
				"denial", "endgame", "defend", "plan_round"]:
			q.set(k, get(k))
		for k in ["tokens", "bonus", "solids", "joker", "reserved", "owned", "nobles", "patron_pts", "hidden",
				"reserved_at", "color_pts", "gov_refused"]:
			q.set(k, get(k).duplicate())
		q.plan = plan.duplicate(true) if plan != null else null
		return q

	func token_count() -> int:
		var s := 0
		for x in tokens:
			s += x
		return s

	func is_ai() -> bool:
		return kind != "humano"

	func last_philosopher_pts() -> int:
		for i in range(nobles.size() - 1, -1, -1):
			if not Defs.is_writer(nobles[i]):
				return int(patron_pts.get(nobles[i], 0))
		return 0


var rules: RuleSet
var n := 0
var rng := RandomNumberGenerator.new()
var cards: Array = []
var bank := [0, 0, 0, 0, 0, 0]
var decks := [[], [], [], []]   # indices 1..3
var market := [[], [], [], []]  # indices 1..3; -1 = vazio
var nobles: Array = []          # filosofos e escritores na mesa
var patrons := {}               # id -> {"name", "req", "pts", "art"} (filosofos 0.., escritores 100..)
var governors: Array = []       # o conjunto de governantes da partida
var gov_table: Array = []       # indices dos governantes em jogo
var gov_holder := {}            # indice do governante -> jogador
var players: Array = []
var current := 0
var round_no := 1
var end_triggered := false
var finished := false
var phase := "acao"             # "acao", "descarte", "ganho", "nobre", "governante", "cega", "escolha_gov", "fim"
var noble_options: Array = []   # filosofos (ou escritores) que o jogador pode escolher
var gov_options: Array = []     # governantes que o jogador pode receber agora
var blind_options: Array = []   # reserva as cegas com escolha: cartas do topo
var gain_n := 0                 # fase "ganho": quantas fichas (de elementos diferentes) pegar
var discard_to := 0             # fase "descarte": devolver ate ficar com isto
var extra_round_done := false
var _patron_stage := 0          # fim da vez: 0 = filosofos, 1 = escritores
var _steps: Array = []
var _pending_gain := 0
var _blind_lv := 0
var events: Array = []
var passes_in_round := 0
var max_rounds := 150
# estatisticas
var turns_total := 0
var empty_sum := 0


func setup(p_rules: RuleSet, configs: Array, seed: int = 0) -> void:
	## configs: lista de {"name": String, "kind": "humano"|"facil"|"normal"...}
	rules = p_rules
	n = configs.size()
	assert(n >= 2 and n <= 5)
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	cards = Content.load_deck(rules.deck)
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
	# filosofos (ids 0..) e escritores (ids 100..): n+1 filosofos e 2 escritores na mesa
	patrons = {}
	nobles = []
	if rules.uses_philosophers():
		var ph := Content.load_patrons("philosophers", rules.phil_set)
		var pool: Array = []
		for i in range(ph.size()):
			patrons[i] = ph[i]
			pool.append(i)
		_shuffle(pool)
		nobles.append_array(pool.slice(0, mini(n + 1, pool.size())))
	if rules.uses_writers():
		var wr := Content.load_patrons("writers", rules.writer_set)
		var wpool: Array = []
		for i in range(wr.size()):
			patrons[Defs.WRITER_BASE + i] = wr[i]
			wpool.append(Defs.WRITER_BASE + i)
		_shuffle(wpool)
		nobles.append_array(wpool.slice(0, Defs.WRITERS_ON_TABLE))
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
		p.defend = prof.get("defend", false)
		players.append(p)
	current = 0
	round_no = 1
	end_triggered = false
	finished = false
	events = []
	passes_in_round = 0
	_steps = []
	governors = []
	gov_table = []
	gov_holder = {}
	if rules.uses_governors():
		governors = Content.load_governors(rules.gov_set)
	if governors.is_empty():
		_start_turn()
		return
	# governantes em jogo: com poucos no conjunto, todos; com sorteio, um por jogador;
	# senao, cada jogador escolhe um (as IAs na hora, os humanos na fase "escolha_gov")
	if governors.size() <= n:
		gov_table = range(governors.size())
		_start_turn()
	elif rules.gov_pick == "sorteio":
		var pool2: Array = range(governors.size())
		_shuffle(pool2)
		for i in range(n):
			players[i].gov_choice = pool2[i]
		gov_table = pool2.slice(0, n)
		_start_turn()
	else:
		current = 0
		_next_gov_pick()


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ---------------------------------------------------------------------------
# Escolha dos governantes no inicio
# ---------------------------------------------------------------------------
func gov_available() -> Array:
	var taken := {}
	for p in players:
		if p.gov_choice >= 0:
			taken[p.gov_choice] = true
	var out: Array = []
	for i in range(governors.size()):
		if not taken.has(i):
			out.append(i)
	return out


func _next_gov_pick() -> void:
	while current < n:
		var p: PlayerState = players[current]
		if p.gov_choice < 0:
			if p.is_ai():
				p.gov_choice = Governors.ai_pick(self, current, gov_available())
				events.append({"t": "gov_pick", "p": current, "gov": p.gov_choice})
			else:
				phase = "escolha_gov"
				return
		current += 1
	gov_table = []
	for p in players:
		gov_table.append(p.gov_choice)
	current = 0
	_start_turn()


func pick_governor(gi: int) -> bool:
	## Fase "escolha_gov": o jogador da vez escolhe (gi = -1: sorteio).
	if phase != "escolha_gov":
		return false
	var av := gov_available()
	if gi < 0:
		gi = av[rng.randi_range(0, av.size() - 1)]
	if not av.has(gi):
		return false
	cur().gov_choice = gi
	events.append({"t": "gov_pick", "p": current, "gov": gi})
	current += 1
	phase = "acao"
	_next_gov_pick()
	return true


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
	## Fichas que faltam (esferas inclusive). O custo em esferas (posicao 5) so se paga com esferas.
	var t: Array = p.tokens if tokens == null else tokens
	var s := 0
	for c in range(5):
		var need: int = cost[c] - p.bonus[c] - t[c]
		if need > 0:
			s += need
	if cost.size() > 5:
		s += cost[5]
	return s - t[GOLD]


func joker_ok(p: PlayerState, cid: int) -> bool:
	## O bonus coringa so pode ser comprado por quem ja tem uma carta de um solido.
	return cards[cid].kind != "joker" or p.solids.max() > 0


func can_afford(p: PlayerState, cid: int) -> bool:
	return shortfall_of(p, cards[cid].cost) <= 0 and joker_ok(p, cid)


func joker_colors(p: PlayerState) -> Array:
	var out: Array = []
	for c in range(5):
		if p.solids[c] > 0:
			out.append(c)
	return out


func best_joker_color(p: PlayerState) -> int:
	## Escolha automatica do coringa: a cor em que o jogador tem mais pontos; no empate, mais cartas.
	var best := -1
	for c in joker_colors(p):
		if best < 0 or p.color_pts[c] > p.color_pts[best] or (p.color_pts[c] == p.color_pts[best] and p.bonus[c] > p.bonus[best]):
			best = c
	return best


func card_gain(p: PlayerState, cid: int, joker := -1) -> Array:
	## Bonus que a carta daria a p (vetor de 5).
	var cd: Defs.CardDef = cards[cid]
	if cd.kind == "joker":
		var v := [0, 0, 0, 0, 0]
		var j := joker if joker >= 0 else best_joker_color(p)
		if j >= 0:
			v[j] = 1
		return v
	return cd.bonus_vec


func spec_color_for(p: PlayerState, cid: int, joker := -1) -> int:
	var cd: Defs.CardDef = cards[cid]
	if cd.kind == "joker":
		return joker if joker >= 0 else best_joker_color(p)
	return cd.spec_color()


func best_color(p: PlayerState) -> int:
	var best := 0
	for c in range(5):
		if p.color_pts[c] > p.color_pts[best]:
			best = c
	return best


func has_adv(p: PlayerState, adv: String) -> bool:
	return p.governor >= 0 and governors[p.governor]["adv"] == adv


func holder_of(adv: String) -> int:
	for i in range(n):
		if has_adv(players[i], adv):
			return i
	return -1


func reserve_visible(owner: int, cid: int, viewer: int, mode := "") -> bool:
	## Uma carta reservada do mercado fica visivel para os outros ate a proxima vez de quem a
	## reservou (regra "rodada") ou sempre ("sempre"). Reservas as cegas so sao visiveis para o
	## dono (e para quem tem o governante que ve tudo).
	if owner == viewer:
		return true
	if viewer >= 0 and viewer < n and has_adv(players[viewer], "see_hidden"):
		return true
	var p: PlayerState = players[owner]
	if p.hidden.has(cid):
		return false
	if (mode if mode != "" else rules.see_reserves) == "sempre":
		return true
	return turns_total - int(p.reserved_at.get(cid, -999)) < n


func spec_threshold(p: PlayerState) -> int:
	var t := rules.color_win
	if p.spec_n > 0:
		t = p.spec_n if t <= 0 else mini(t, p.spec_n)
	return t


func meets_color(p: PlayerState) -> bool:
	## Vitoria por especializacao: pontos de cartas numa mesma cor >= limite.
	var t := spec_threshold(p)
	return t > 0 and p.color_pts[best_color(p)] >= t


func target_of(p: PlayerState) -> int:
	## Meta de pontos deste jogador (a do governante, se tiver um).
	var t := rules.base_target()
	if p.governor >= 0:
		t += int(governors[p.governor]["target"])
	return maxi(1, t)


func reached(p: PlayerState) -> bool:
	return p.points >= target_of(p) or meets_color(p)


func patron_req(id: int) -> Array:
	return patrons[id]["req"] if patrons.has(id) else [0, 0, 0, 0, 0]


func patron_name(id: int) -> String:
	return patrons[id]["name"] if patrons.has(id) else "?"


func patron_art(id: int) -> int:
	return int(patrons[id].get("art", 0)) if patrons.has(id) else 0


func patron_distance(bonus: Array, id: int) -> int:
	## Cartas que faltam para receber o filosofo ou escritor `id`.
	return noble_distance(bonus, patron_req(id), rules.writer_free if Defs.is_writer(id) else rules.noble_free)


func patron_pts(p: PlayerState, id: int) -> int:
	## Pontos que o filosofo/escritor daria agora a p (filosofos: 3 ou 3/2/1; escritores: o da planilha).
	if Defs.is_writer(id):
		if p.writer_pts > 0:
			return p.writer_pts
		return int(patrons[id]["pts"]) if patrons.has(id) else Defs.WRITER_PTS
	return rules.noble_pts(philosopher_count(p))


static func philosopher_count(p: PlayerState) -> int:
	var k := 0
	for id in p.nobles:
		if not Defs.is_writer(id):
			k += 1
	return k


func noble_distance(bonus: Array, req: Array, free := -1) -> int:
	## Cartas que faltam para cumprir o requisito, com `free` cartas livres
	## (-1 = desconto dos filosofos).
	var disc: int = rules.noble_discount() if free < 0 else free
	if disc == 0:
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
	return maxi(0, total - disc - have)


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
	return cur().reserved.size() < 3 and not cur().no_reserve


func has_any_action() -> bool:
	var p := cur()
	if available_colors() > 0:
		return true
	if p.reserved.size() < 3 and not p.no_reserve:
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


func gain_room(p: PlayerState) -> int:
	return maxi(0, rules.hand_limit - p.token_count())


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


func act_buy_market(lv: int, slot: int, joker := -1) -> bool:
	if phase != "acao":
		return false
	var cid: int = market[lv][slot]
	if cid < 0 or not can_afford(cur(), cid):
		return false
	var paid := _pay_and_gain(cur(), cid, joker)
	_refill(lv, slot)
	events.append({"t": "buy", "p": current, "card": cid, "src": "m", "lv": lv, "slot": slot, "paid": paid})
	_after_action()
	return true


func act_buy_reserved(i: int, joker := -1) -> bool:
	if phase != "acao":
		return false
	var p := cur()
	if i < 0 or i >= p.reserved.size():
		return false
	var cid: int = p.reserved[i]
	if not can_afford(p, cid):
		return false
	p.reserved.remove_at(i)
	if p.hidden.has(cid):
		p.blind_bought = true
	p.hidden.erase(cid)
	p.reserved_at.erase(cid)
	var paid := _pay_and_gain(p, cid, joker)
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
		var k: int = 0
		if has_adv(p, "blind_choice"):
			k = mini(int(governors[p.governor]["adv_v"]), decks[lv].size())
		if k >= 2:
			# governante: olha as k cartas do topo e escolhe uma
			blind_options = []
			for i in range(k):
				blind_options.append(decks[lv][decks[lv].size() - 1 - i])
			_blind_lv = lv
			if p.is_ai():
				choose_blind(AI.pick_blind(self, current, blind_options))
			else:
				phase = "cega"
			return true
		cid = decks[lv].pop_back()
	else:
		cid = market[lv][slot]
		if cid < 0:
			return false
		_refill(lv, slot)
	_finish_reserve(cid, lv, slot)
	return true


func choose_blind(cid: int) -> bool:
	if not blind_options.has(cid):
		return false
	decks[_blind_lv].erase(cid)
	blind_options = []
	phase = "acao"
	_finish_reserve(cid, _blind_lv, -1)
	return true


func _finish_reserve(cid: int, lv: int, slot: int) -> void:
	var p := cur()
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


func act_pass() -> bool:
	if phase != "acao":
		return false
	passes_in_round += 1
	events.append({"t": "pass", "p": current})
	_after_action()
	return true


func discard(color: int) -> bool:
	## Fase "descarte": devolver fichas (acima do limite da mao, ou o custo de um governante).
	if phase != "descarte":
		return false
	var p := cur()
	if p.tokens[color] <= 0:
		return false
	_return_token(current, color)
	if p.token_count() <= discard_to:
		phase = "acao"
		_advance()
	return true


func gain(colors: Array) -> bool:
	## Fase "ganho" (efeito de carta ou governante): pegar ate gain_n fichas de elementos
	## diferentes (uma lista vazia dispensa o ganho).
	if phase != "ganho" or colors.size() > gain_n:
		return false
	var seen := {}
	for c in colors:
		if c < 0 or c > 4 or bank[c] <= 0 or seen.has(c):
			return false
		seen[c] = true
	_apply_gain(current, colors)
	phase = "acao"
	_advance()
	return true


func choose_noble(nb: int) -> bool:
	if phase != "nobre" or not noble_options.has(nb):
		return false
	_claim_noble(current, nb)
	noble_options = []
	phase = "acao"
	_patron_stage = 1 if not Defs.is_writer(nb) else 2
	_steps.push_front("nobles")
	_advance()
	return true


func choose_governor(gi: int) -> bool:
	## Fase "governante": gi = indice do governante aceito, ou -1 para recusar.
	if phase != "governante":
		return false
	if gi >= 0 and not gov_options.has(gi):
		return false
	var p := cur()
	if gi < 0:
		for x in gov_options:
			if not p.gov_refused.has(x):
				p.gov_refused.append(x)
	gov_options = []
	phase = "acao"
	if gi >= 0:
		_claim_governor(current, gi)
	_advance()
	return true


func can_claim_governor(gi: int) -> bool:
	## Um governante recusado antes pode ser pedido de novo (tocando nele), na sua vez.
	var p := cur()
	return phase == "acao" and not p.is_ai() and p.governor < 0 and gov_table.has(gi) \
		and not gov_holder.has(gi) and Governors.meets(self, current, governors[gi]) \
		and Governors.can_pay(self, current, governors[gi])


func claim_governor_now(gi: int) -> bool:
	if not can_claim_governor(gi):
		return false
	_claim_governor(current, gi)
	if not _steps.is_empty():
		_advance()
	return true


func timeout() -> void:
	## O tempo da vez acabou: passa a vez (nas escolhas, o jogo escolhe pelo jogador).
	match phase:
		"acao":
			act_pass()
		"descarte":
			for c in AI.discard_choices(self, current, cur().token_count() - discard_to):
				discard(c)
				if phase != "descarte":
					break
		"ganho":
			gain(AI.gain_choice(self, current, gain_n))
		"nobre":
			choose_noble(AI.pick_noble(self, current, noble_options))
		"governante":
			choose_governor(AI.pick_governor(self, current, gov_options))
		"cega":
			choose_blind(AI.pick_blind(self, current, blind_options))
		"escolha_gov":
			pick_governor(-1)


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
func _pay_and_gain(p: PlayerState, cid: int, joker := -1) -> Array:
	var cd: Defs.CardDef = cards[cid]
	var paid := [0, 0, 0, 0, 0, 0]
	var gold_needed: int = cd.cost[5]
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
	if cd.kind == "joker":
		if joker < 0 or p.solids[joker] <= 0:
			joker = best_joker_color(p)
		p.joker[cid] = joker
	var gv := card_gain(p, cid, joker)
	for c in range(5):
		p.bonus[c] += gv[c]
	if cd.kind == "single":
		p.solids[cd.bonus] += 1
	var pts := cd.points
	if cd.level == 3:
		pts += p.adv_bonus
	p.points += pts
	var sc := spec_color_for(p, cid, joker)
	if sc >= 0:
		p.color_pts[sc] += cd.points
	p.cards += 1
	p.owned.append(cid)
	if not p.bought_turn:
		p.bought_turn = true
		p.buy_streak += 1
	# efeito da carta
	match cd.effect:
		"token":
			_pending_gain = 1
		"two_tokens":
			_pending_gain = 2
		"sphere":
			if bank[GOLD] > 0 and gain_room(p) > 0:
				bank[GOLD] -= 1
				p.tokens[GOLD] += 1
				events.append({"t": "effect", "p": current, "effect": "sphere"})
		"extra_turn":
			p.extra_turns += 1
			events.append({"t": "effect", "p": current, "effect": "extra_turn"})
	return paid


func _refill(lv: int, slot: int) -> void:
	market[lv][slot] = decks[lv].pop_back() if not decks[lv].is_empty() else -1


func _return_token(idx: int, color: int) -> void:
	## Devolve uma ficha; com o governante que confisca, ela vai para quem o tem (se couber).
	var p: PlayerState = players[idx]
	p.tokens[color] -= 1
	p.discards += 1
	var h := holder_of("confiscate")
	if h >= 0 and h != idx and gain_room(players[h]) > 0:
		players[h].tokens[color] += 1
		events.append({"t": "discard", "p": idx, "color": color, "to": h})
	else:
		bank[color] += 1
		events.append({"t": "discard", "p": idx, "color": color})


func _apply_gain(idx: int, colors: Array) -> void:
	var p: PlayerState = players[idx]
	for c in colors:
		if bank[c] > 0 and gain_room(p) > 0:
			bank[c] -= 1
			p.tokens[c] += 1
	if not colors.is_empty():
		events.append({"t": "gain", "p": idx, "colors": colors.duplicate()})


func _after_action() -> void:
	_steps = ["card_gain", "limit", "nobles", "governors", "end"]
	_advance()


func _advance() -> void:
	## Executa os passos do fim da vez ate o fim ou ate um passo esperar uma escolha.
	while not _steps.is_empty():
		var st: String = _steps.pop_front()
		if _run_step(st):
			return


func _run_step(st: String) -> bool:
	## true = o passo espera uma decisao do jogador (fase mudou).
	var p := cur()
	var parts := st.split(":")
	match parts[0]:
		"card_gain", "gain":
			var k: int = _pending_gain if parts[0] == "card_gain" else int(parts[1])
			if parts[0] == "card_gain":
				_pending_gain = 0
			var avail := available_colors()
			k = mini(k, mini(gain_room(p), avail))
			if k <= 0:
				return false
			if p.is_ai():
				_apply_gain(current, AI.gain_choice(self, current, k))
				return false
			gain_n = k
			phase = "ganho"
			return true
		"limit":
			return _discard_to(p.token_count() - rules.hand_limit)
		"return":
			return _discard_to(mini(int(parts[1]), p.token_count()))
		"nobles":
			return _check_nobles()
		"governors":
			return _check_governors()
		"end":
			_end_turn()
			return true
	return false


func _discard_to(k: int) -> bool:
	## Devolver k fichas (IA: na hora; humano: fase "descarte").
	if k <= 0:
		return false
	var p := cur()
	if p.is_ai():
		for c in AI.discard_choices(self, current, k):
			_return_token(current, c)
		return false
	discard_to = p.token_count() - k
	phase = "descarte"
	return true


func _check_nobles() -> bool:
	## Fim da vez: pode chegar um filosofo e tambem um escritor.
	var p := cur()
	while _patron_stage <= 1:
		var want_writer := _patron_stage == 1
		var ok: Array = []
		for nb in nobles:
			if Defs.is_writer(nb) == want_writer and patron_distance(p.bonus, nb) == 0:
				ok.append(nb)
		if ok.size() == 1:
			_claim_noble(current, ok[0])
		elif ok.size() > 1:
			if p.is_ai():
				_claim_noble(current, AI.pick_noble(self, current, ok))
			else:
				phase = "nobre"
				noble_options = ok
				return true
		_patron_stage += 1
	_patron_stage = 0
	return false


func _claim_noble(idx: int, nb: int) -> void:
	var p: PlayerState = players[idx]
	nobles.erase(nb)
	var pts := patron_pts(p, nb)
	p.nobles.append(nb)
	p.patron_pts[nb] = pts
	p.points += pts
	p.noble_points += pts
	events.append({"t": "noble", "p": idx, "noble": nb, "pts": pts, "writer": Defs.is_writer(nb)})


func _check_governors() -> bool:
	var p := cur()
	if gov_table.is_empty() or p.governor >= 0:
		return false
	var opts: Array = []
	for gi in gov_table:
		if gov_holder.has(gi) or p.gov_refused.has(gi):
			continue
		if Governors.meets(self, current, governors[gi]) and Governors.can_pay(self, current, governors[gi]):
			opts.append(gi)
	if opts.is_empty():
		return false
	if p.is_ai():
		var gi := AI.pick_governor(self, current, opts)
		if gi >= 0:
			_claim_governor(current, gi)
		return false
	gov_options = opts
	phase = "governante"
	return true


func _claim_governor(idx: int, gi: int) -> void:
	## Recebe o governante: aplica o custo e a vantagem. Devolver ou pegar fichas entram na fila.
	var p: PlayerState = players[idx]
	var gv: Dictionary = governors[gi]
	p.governor = gi
	gov_holder[gi] = idx
	var queue: Array = []
	match gv["cost"]:
		"lose_points":
			p.points -= int(gv["cost_v"])
		"return_tokens":
			queue.append("return:%d" % int(gv["cost_v"]))
		"return_spheres":
			var k := mini(int(gv["cost_v"]), p.tokens[GOLD])
			for i in range(k):
				_return_token(idx, GOLD)
		"no_reserve":
			p.no_reserve = true
		"return_philosopher":
			for i in range(p.nobles.size() - 1, -1, -1):
				var id: int = p.nobles[i]
				if not Defs.is_writer(id):
					var pts := int(p.patron_pts.get(id, 0))
					p.nobles.remove_at(i)
					p.patron_pts.erase(id)
					p.points -= pts
					p.noble_points -= pts
					nobles.append(id)
					events.append({"t": "noble_back", "p": idx, "noble": id, "pts": pts})
					break
	var v: int = gv["adv_v"]
	match gv["adv"]:
		"gain_points":
			p.points += v
		"gain_tokens":
			queue.append("gain:%d" % v)
		"specialization":
			p.spec_n = v
		"advanced_bonus":
			p.adv_bonus = v
			p.points += v * Governors.advanced_count(self, p)
		"extra_turn":
			p.extra_turns += 1
		"writer_points":
			for id in p.nobles:
				if Defs.is_writer(id):
					p.points += v - int(p.patron_pts.get(id, 0))
					p.noble_points += v - int(p.patron_pts.get(id, 0))
					p.patron_pts[id] = v
			p.writer_pts = v
	events.append({"t": "governor", "p": idx, "gov": gi})
	for i in range(queue.size() - 1, -1, -1):
		_steps.push_front(queue[i])


func _start_turn() -> void:
	phase = "acao"
	cur().turns += 1
	cur().bought_turn = false


func _end_turn() -> void:
	turns_total += 1
	for c in range(5):
		if bank[c] == 0:
			empty_sum += 1
	var p := cur()
	if not p.bought_turn:
		p.buy_streak = 0
	if meets_color(p) and not p.color_done:
		p.color_done = true
		events.append({"t": "color", "p": current, "color": best_color(p), "pts": p.color_pts[best_color(p)]})
	if reached(p) and not end_triggered:
		end_triggered = true
		events.append({"t": "last_round", "p": current, "reason": "cor" if meets_color(p) else "pontos"})
	if p.extra_turns > 0 and not finished:
		p.extra_turns -= 1
		events.append({"t": "extra_turn", "p": current})
		_start_turn()
		return
	current += 1
	if current >= n:
		current = 0
		var all_passed := passes_in_round >= n
		passes_in_round = 0
		if end_triggered and not all_passed and not extra_round_done and _extra_round_wanted():
			extra_round_done = true
			events.append({"t": "extra_round", "p": holder_of("extra_round")})
			round_no += 1
			_start_turn()
			return
		if end_triggered or all_passed or round_no >= max_rounds:
			_finish()
			return
		round_no += 1
	_start_turn()


func _extra_round_wanted() -> bool:
	var h := holder_of("extra_round")
	return h >= 0 and not winners().has(h)


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
	g.patrons = patrons
	g.governors = governors
	g.gov_table = gov_table.duplicate()
	g.gov_holder = gov_holder.duplicate()
	g.extra_round_done = extra_round_done
	g.turns_total = turns_total
	g.players = []
	var normal := AIProfiles.profile("normal", rules)
	for p in players:
		var q: PlayerState = p.clone()
		if q.kind == "humano":
			q.kind = "normal"
		q.endgame = false
		q.denial = -1.0
		q.defend = false
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


func _tier(p: PlayerState) -> int:
	## 0 = cumpriu a especializacao; 1 = chegou a propria meta; 2 = nenhum dos dois.
	if meets_color(p):
		return 0
	if p.points >= target_of(p):
		return 1
	return 2


func ranking() -> Array:
	## Indices dos jogadores do 1o ao ultimo: quem cumpriu a especializacao, depois quem chegou a
	## propria meta, depois os demais; em cada grupo, mais pontos; no empate, quem tem o governante
	## que vence empates e, por fim, menos cartas compradas.
	var idx := range(n)
	idx.sort_custom(func(a, b):
		var pa: PlayerState = players[a]
		var pb: PlayerState = players[b]
		var ta := _tier(pa)
		var tb := _tier(pb)
		if ta != tb:
			return ta < tb
		if pa.points != pb.points:
			return pa.points > pb.points
		var wa := has_adv(pa, "wins_ties")
		var wb := has_adv(pb, "wins_ties")
		if wa != wb:
			return wa
		return pa.cards < pb.cards)
	return idx


func winners() -> Array:
	var r := ranking()
	var best: PlayerState = players[r[0]]
	if has_adv(best, "wins_ties"):
		return [r[0]]
	var out: Array = []
	for i in r:
		var p: PlayerState = players[i]
		if p.points == best.points and _tier(p) == _tier(best) and p.cards == best.cards:
			out.append(i)
	return out
