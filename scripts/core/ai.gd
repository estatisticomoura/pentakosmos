class_name AI
extends RefCounted
## IAs do jogo (portadas do simulador em Python e ampliadas).
## Politicas:
##   "guloso" = melhor relacao valor/esforco a cada turno (IA facil)
##   "plano"  = estrategista: planeja um caminho pelas cartas de nivel 2/3 e
##              pelos nobres, reserva cedo o alvo e reavalia o plano
## Recursos extras (perfil "tatica"):
##   negacao cirurgica  - bloqueia fichas/cartas de que um adversario precisa,
##                        quando isso custa pouco
##   busca no fim de jogo - simula continuacoes da partida para cada jogada candidata
## Parametros de cada jogador ficam em p.params (ver AIProfiles.DEFAULTS).

const GOLD := Defs.GOLD

# negacao cirurgica
const SURG_MIN_VALUE := 3
const SURG_RESERVE_VALUE := 4
# reserva defensiva: pontos minimos (carta + filosofo/escritor que ela traria) de uma carta
# que um adversario pode comprar na proxima vez, para valer tira-la do mercado
const DEFEND_VALUE := 3
# com a reserva defensiva, a coleta so e escolhida para negar fichas se bloquear isto
const DEFEND_TOKEN_BLOCK := 2.0
# busca no fim de jogo
const ENDGAME_MARGIN := 5      # ativa quando alguem esta a 5 pontos ou menos da meta
const ENDGAME_ROLLOUTS := 8    # simulacoes por jogada candidata
const ENDGAME_MAX_CANDS := 9


# ---------------------------------------------------------------------------
# Auxiliares comuns
# ---------------------------------------------------------------------------
static func turns_estimate(g: GameState, p: GameState.PlayerState, cost: Array) -> float:
	var short := [0, 0, 0, 0, 0]
	var total := 0
	for c in range(5):
		var s: int = cost[c] - p.bonus[c] - p.tokens[c]
		if s > 0:
			short[c] = s
			total += s
	if cost.size() > 5:
		total += cost[5]
	total -= p.tokens[GOLD]
	if total <= 0:
		return 0.0
	var pen: float = p.params["scarcity_pen"]
	var worst := 0.0
	var penalty := 0.0
	for c in range(5):
		var s: int = short[c]
		if s == 0:
			continue
		var rate := 2.0 if g.bank[c] >= g.rules.take2_min else 1.0
		worst = maxf(worst, s / rate)
		if s > g.bank[c]:
			penalty += pen * (s - g.bank[c])
	worst = maxf(0.0, worst - maxi(0, p.tokens[GOLD] - (cost[5] if cost.size() > 5 else 0)))
	return maxf(ceil(total / 3.0), ceil(worst)) + penalty


static func color_demand(g: GameState, p: GameState.PlayerState) -> Array:
	var dp: float = p.params["demand_pts"]
	var dr: float = p.params["demand_res"]
	var demand := [0.0, 0.0, 0.0, 0.0, 0.0]
	for e in g.market_cards():
		var cd: Defs.CardDef = g.cards[e[2]]
		for c in range(5):
			if cd.cost[c] > p.bonus[c]:
				demand[c] += 1.0 + dp * cd.points
	for cid in p.reserved:
		var cd: Defs.CardDef = g.cards[cid]
		for c in range(5):
			if cd.cost[c] > p.bonus[c]:
				demand[c] += dr + dp * cd.points
	return demand


static func card_value(g: GameState, p: GameState.PlayerState, cid: int, demand: Array, maxdemand: float) -> float:
	var P: Dictionary = p.params
	var cd: Defs.CardDef = g.cards[cid]
	var vec := g.card_gain(p, cid)
	var v := float(cd.points)
	var phase := maxf(0.0, 1.0 - float(p.points) / g.target_of(p))
	if maxdemand > 0:
		v += P["engine_w"] * phase * (P["demand_base"] * _sum(vec) + _dot(demand, vec) / maxdemand)
	var best := 0.0
	var rest := 0.0
	for nb in g.nobles:
		if not _helps(g.patron_req(nb), p.bonus, vec):
			continue
		var d := g.patron_distance(p.bonus, nb)
		if d <= 0:
			continue
		var val := float(g.patron_pts(p, nb)) / d
		if val > best:
			rest += best
			best = val
		else:
			rest += val
	return v + best + P["noble_rest"] * rest + color_bonus(g, p, cd)


static func _sum(v: Array) -> int:
	return v[0] + v[1] + v[2] + v[3] + v[4]


static func _dot(a: Array, v: Array) -> float:
	var s := 0.0
	for c in range(5):
		s += a[c] * v[c]
	return s


static func _helps(req: Array, bonus: Array, vec: Array) -> bool:
	## A carta (bonus vec) ajuda a cumprir o requisito?
	for c in range(5):
		if vec[c] > 0 and req[c] > bonus[c]:
			return true
	return false


static func can_res(p: GameState.PlayerState) -> bool:
	return p.reserved.size() < 3 and not p.no_reserve


static func color_bonus(g: GameState, p: GameState.PlayerState, cd: Defs.CardDef) -> float:
	## Vitoria por especializacao: valor extra de uma carta com pontos, maior
	## quanto mais perto do limite ela deixa a cor dela.
	var cw := g.spec_threshold(p)
	var sc := g.spec_color_for(p, cd.id)
	if cw <= 0 or cd.points <= 0 or sc < 0:
		return 0.0
	var r := minf(1.0, float(p.color_pts[sc] + cd.points) / cw)
	return p.params["color_w"] * cd.points * r * r


static func wins_by_color(g: GameState, p: GameState.PlayerState, cd: Defs.CardDef) -> bool:
	var cw := g.spec_threshold(p)
	var sc := g.spec_color_for(p, cd.id)
	return cw > 0 and sc >= 0 and p.color_pts[sc] + cd.points >= cw


static func _candidates(g: GameState, p: GameState.PlayerState) -> Array:
	var out: Array = []
	for e in g.market_cards():
		out.append(["m", e[0], e[1], e[2]])
	for i in range(p.reserved.size()):
		out.append(["r", i, -1, p.reserved[i]])
	return out


static func _sort_scored(a: Array, b: Array) -> bool:
	return a[0] > b[0]


static func scored_cards(g: GameState, p: GameState.PlayerState) -> Array:
	## [[score, valor, origem, a, b, id, acessivel], ...] ordenado
	var demand := color_demand(g, p)
	var md: float = demand.max()
	var noise: float = p.params["noise"]
	var out: Array = []
	for c in _candidates(g, p):
		var cd: Defs.CardDef = g.cards[c[3]]
		var v := card_value(g, p, c[3], demand, md) * (1.0 + g.rng.randfn(0.0, noise))
		var t := turns_estimate(g, p, cd.cost)
		var afford := g.can_afford(p, c[3])
		out.append([v / (t + 1.0), v, c[0], c[1], c[2], c[3], afford])
	out.sort_custom(_sort_scored)
	return out


static func scored_for(g: GameState, p: GameState.PlayerState) -> Array:
	return scored_cards_plan(g, p, p.plan) if p.policy == "plano" else scored_cards(g, p)


static func pick_targets(g: GameState, p: GameState.PlayerState, k: int = 3) -> Array:
	var sc: Array = scored_cards_plan(g, p, p.plan) if p.plan != null else scored_cards(g, p)
	var out: Array = []
	for s in sc:
		if not s[6]:
			out.append(s[5])
			if out.size() >= k:
				break
	return out


static func token_utility(g: GameState, p: GameState.PlayerState, targets: Array, tokens: Array) -> float:
	var P: Dictionary = p.params
	var w := [1.0, P["tok_w2"], P["tok_w3"]]
	var u := 0.0
	for i in range(targets.size()):
		var cd: Defs.CardDef = g.cards[targets[i]]
		u -= w[i] * maxi(0, GameState.shortfall_of(p, cd.cost, tokens))
	return u + P["hoard"] * (tokens[0] + tokens[1] + tokens[2] + tokens[3] + tokens[4])


static func immediate_noble_pts(g: GameState, p: GameState.PlayerState, vec: Array) -> int:
	## Pontos de filosofo e de escritor que chegariam com o bonus `vec` a mais
	## (no maximo um de cada por vez).
	for c in range(5):
		p.bonus[c] += vec[c]
	var phil := 0
	var wri := 0
	for nb in g.nobles:
		if g.patron_distance(p.bonus, nb) == 0:
			if Defs.is_writer(nb):
				wri = g.patron_pts(p, nb)
			else:
				phil = g.patron_pts(p, nb)
	for c in range(5):
		p.bonus[c] -= vec[c]
	return phil + wri


static func opponent_threat(g: GameState, idx: int) -> Array:
	for j in range(g.n):
		if j == idx:
			continue
		var q: GameState.PlayerState = g.players[j]
		for e in g.market_cards():
			var cd: Defs.CardDef = g.cards[e[2]]
			if g.can_afford(q, e[2]):
				if q.points + cd.points + immediate_noble_pts(g, q, g.card_gain(q, e[2])) >= g.target_of(q) \
						or wins_by_color(g, q, cd):
					return [e[0], e[1]]
	return []


# ---------------------------------------------------------------------------
# Decisao principal
# ---------------------------------------------------------------------------
static func choose_action(g: GameState, idx: int) -> Array:
	var p: GameState.PlayerState = g.players[idx]
	var P: Dictionary = p.params
	var rules := g.rules
	var planner := p.policy == "plano"
	var plan = null
	var sc: Array
	if planner:
		plan = update_plan(g, p)
		sc = scored_cards_plan(g, p, plan)
	else:
		sc = scored_cards(g, p)

	# 1) vitoria imediata
	var best_total := -1
	var best_s = null
	for s in sc:
		if s[6]:
			var cd: Defs.CardDef = g.cards[s[5]]
			var total: int = p.points + cd.points + immediate_noble_pts(g, p, g.card_gain(p, s[5]))
			if wins_by_color(g, p, cd):
				total += 100  # vitoria por especializacao tem prioridade
			if total >= g.target_of(p) and total > best_total:
				best_total = total
				best_s = s
	if best_s != null:
		return _buy(best_s)

	# 1b) busca no fim de jogo
	if p.endgame and endgame_active(g):
		return search_action(g, idx, sc)

	# 2) bloquear vitoria iminente de adversario
	if can_res(p):
		var th := opponent_threat(g, idx)
		if not th.is_empty():
			var cid: int = g.market[th[0]][th[1]]
			if g.can_afford(p, cid):
				return ["buy", "m", th[0], th[1]]
			return ["reserve", th[0], th[1]]

	if sc.is_empty():
		var a0 := best_take(g, p, [], idx)
		return a0[0] if not a0[0].is_empty() else ["pass"]

	# 2b) estrategista: reserva cedo o alvo principal
	if planner and plan != null and p.turns <= int(P["plan_reserve_turns"]) and p.reserved.is_empty() and g.bank[GOLD] > 0 \
			and not p.no_reserve:
		var goal: int = plan["goals"][0]
		var gc: Defs.CardDef = g.cards[goal]
		for e in g.market_cards():
			if e[2] == goal and (gc.level == 3 or gc.points >= 2) and not g.can_afford(p, goal):
				return ["reserve", e[0], e[1]]

	var top_score: float = sc[0][0]
	# 3) compra
	var affordable: Array = sc.filter(func(s): return s[6])
	if not affordable.is_empty() and affordable[0][0] >= P["buy_ratio"] * top_score:
		return _buy(affordable[0])

	var targets: Array = []
	for s in sc:
		if not s[6]:
			targets.append(s[5])
			if targets.size() >= 3:
				break
	# 4) coleta (com negacao cirurgica, se o perfil tiver)
	var bt := best_take(g, p, targets, idx)
	var act: Array = bt[0]
	var gain: float = bt[1]
	var blocked: float = bt[2]
	if p.denial >= 0.0:
		# 4b) reserva para tirar do mercado uma carta valiosa que um adversario ja pode comprar
		if can_res(p):
			if p.defend:
				var dr := defend_target(g, idx, targets)
				if not dr.is_empty() and (gain < 1.5 + p.denial or targets.has(dr[2]) or dr[3] >= 6):
					return ["reserve", dr[0], dr[1]]
			else:
				var hr := hate_reserve_target(g, idx)
				if not hr.is_empty() and (gain < 1.0 + p.denial or targets.has(hr[2])):
					return ["reserve", hr[0], hr[1]]
		if blocked >= (DEFEND_TOKEN_BLOCK if p.defend else 0.01) and not act.is_empty():
			p.blocks += 1
			return act
	# 5) reserva para pegar ouro, quando coletar rende pouco
	var T = null
	for s in sc:
		if not s[6]:
			T = s
			break
	if T != null and T[2] == "m" and can_res(p):
		var gold_ok: bool = g.bank[GOLD] > 0 and p.token_count() < rules.hand_limit
		if gold_ok and (act.is_empty() or gain < P["gold_gain"]):
			return ["reserve", T[3], T[4]]
	if not act.is_empty() and gain > 0:
		return act
	if not affordable.is_empty():
		return _buy(affordable[0])
	if not act.is_empty():
		return act
	if T != null and T[2] == "m" and can_res(p):
		return ["reserve", T[3], T[4]]
	return ["pass"]


static func _buy(s: Array) -> Array:
	if s[2] == "m":
		return ["buy", "m", s[3], s[4]]
	return ["buy", "r", s[3]]


static func take_options(g: GameState) -> Array:
	var avail: Array = []
	for c in range(5):
		if g.bank[c] > 0:
			avail.append(c)
	var options: Array = []
	var k := mini(3, avail.size())
	if k > 0:
		options.append_array(_combinations(avail, k))
	for c in range(5):
		if g.bank[c] >= g.rules.take2_min:
			options.append([c, c])
	return options


static func best_take(g: GameState, p: GameState.PlayerState, targets: Array, idx: int = -1) -> Array:
	## Retorna [acao, ganho proprio, valor bloqueado]. Acao vazia se nao ha coleta.
	var options := take_options(g)
	if options.is_empty():
		return [[], 0.0, 0.0]
	var threats: Array = opponent_threats(g, idx) if (p.denial >= 0.0 and idx >= 0) else []
	var base := token_utility(g, p, targets, p.tokens)
	var best: Array = []
	var best_u := -1e18
	var evaluated: Array = []
	var limit := g.rules.hand_limit
	var bank: Array = g.bank
	for opt in options:
		var t: Array = p.tokens.duplicate()
		for c in opt:
			t[c] += 1
			bank[c] -= 1
		var discarded: Array = []
		var tot := 0
		for x in t:
			tot += x
		while tot > limit:
			var bc := -1
			var bu := -1e18
			for c in range(5):
				if t[c] == 0:
					continue
				t[c] -= 1
				var u := token_utility(g, p, targets, t)
				t[c] += 1
				if u > bu:
					bu = u
					bc = c
			if bc < 0:
				bc = GOLD
			t[bc] -= 1
			bank[bc] += 1
			discarded.append(bc)
			tot -= 1
		var own := token_utility(g, p, targets, t)
		var blk := blocked_value(g, threats) if not threats.is_empty() else 0.0
		for c in opt:
			bank[c] += 1
		for c in discarded:
			bank[c] -= 1
		var u2 := own + g.rng.randf() * 1e-6
		evaluated.append([opt, own, blk])
		if u2 > best_u:
			best_u = u2
			best = opt
	if not threats.is_empty():
		# cirurgico: entre as coletas quase tao boas quanto a melhor, a que mais bloqueia
		var pick = null
		for e in evaluated:
			if e[1] >= best_u - p.denial - 1e-9 and e[2] > 0:
				if pick == null or e[2] > pick[2] or (e[2] == pick[2] and e[1] > pick[1]):
					pick = e
		if pick != null:
			return [["take", pick[0]], pick[1] - base, pick[2]]
	return [["take", best], best_u - base, 0.0]


static func _combinations(items: Array, k: int) -> Array:
	var out: Array = []
	_comb_rec(items, k, 0, [], out)
	return out


static func _comb_rec(items: Array, k: int, start: int, cur: Array, out: Array) -> void:
	if cur.size() == k:
		out.append(cur.duplicate())
		return
	for i in range(start, items.size()):
		cur.append(items[i])
		_comb_rec(items, k, i + 1, cur, out)
		cur.pop_back()


static func discard_choices(g: GameState, idx: int, k := -1) -> Array:
	## Cores a devolver (k fichas; -1 = o que passar do limite da mao), sem alterar o estado.
	var p: GameState.PlayerState = g.players[idx]
	var t: Array = p.tokens.duplicate()
	var out: Array = []
	var tot := 0
	for x in t:
		tot += x
	var goal: int = g.rules.hand_limit if k < 0 else tot - k
	while tot > goal and tot > 0:
		var targets := pick_targets(g, p, 3)
		var best_c := -1
		var best_u := -1e9
		for c in range(5):
			if t[c] == 0:
				continue
			t[c] -= 1
			var u := token_utility(g, p, targets, t)
			t[c] += 1
			if u > best_u:
				best_u = u
				best_c = c
		if best_c < 0:
			best_c = GOLD
			if t[GOLD] <= 0:
				break
		t[best_c] -= 1
		out.append(best_c)
		tot -= 1
	return out


static func gain_choice(g: GameState, idx: int, k: int) -> Array:
	## k fichas de elementos diferentes que mais ajudam (efeito de carta ou governante).
	var p: GameState.PlayerState = g.players[idx]
	var avail: Array = []
	for c in range(5):
		if g.bank[c] > 0:
			avail.append(c)
	k = mini(k, mini(avail.size(), g.gain_room(p)))
	if k <= 0:
		return []
	var targets := pick_targets(g, p, 3)
	var best: Array = []
	var best_u := -1e18
	for combo in _combinations(avail, k):
		var t: Array = p.tokens.duplicate()
		for c in combo:
			t[c] += 1
		var u := token_utility(g, p, targets, t) + g.rng.randf() * 1e-6
		if u > best_u:
			best_u = u
			best = combo
	return best


static func pick_governor(g: GameState, idx: int, options: Array) -> int:
	## Aceita o governante que vale mais (em pontos aproximados), se valer a pena; -1 = recusa.
	var best := -1
	var best_v := 0.0
	for gi in options:
		var v := Governors.value_for(g, idx, g.governors[gi])
		if v > best_v:
			best_v = v
			best = gi
	return best


static func pick_blind(g: GameState, idx: int, options: Array) -> int:
	var p: GameState.PlayerState = g.players[idx]
	var best: int = options[0]
	var best_v := -1e18
	for cid in options:
		var v := goal_score(g, p, cid)
		if v > best_v:
			best_v = v
			best = cid
	return best


static func pick_noble(g: GameState, idx: int, options: Array) -> int:
	## Escolhe o nobre que mais negaria aos adversarios.
	var best: int = options[0]
	var best_d := 1 << 30
	for nb in options:
		var d := 1 << 30
		for j in range(g.n):
			if j != idx:
				d = mini(d, g.patron_distance(g.players[j].bonus, nb))
		if d < best_d:
			best_d = d
			best = nb
	return best


# ---------------------------------------------------------------------------
# Estrategista
# ---------------------------------------------------------------------------
static func effort(p: GameState.PlayerState, cost: Array) -> int:
	var s: int = cost[5] if cost.size() > 5 else 0
	for c in range(5):
		if cost[c] > p.bonus[c]:
			s += cost[c] - p.bonus[c]
	return s


static func goal_score(g: GameState, p: GameState.PlayerState, cid: int) -> float:
	var P: Dictionary = p.params
	var cd: Defs.CardDef = g.cards[cid]
	var s: float = (cd.points + color_bonus(g, p, cd) + P["goal_pts_off"]) / (effort(p, cd.cost) + P["goal_effort_off"])
	return s * P["goal_reserved"] if p.reserved.has(cid) else s


static func build_plan(g: GameState, p: GameState.PlayerState, goals = null):
	var P: Dictionary = p.params
	if goals == null:
		var cands: Array = []
		for e in g.market_cards():
			if g.cards[e[2]].level >= 2:
				cands.append(e[2])
		cands.append_array(p.reserved)
		if cands.is_empty():
			return null
		var scored: Array = []
		for i in range(cands.size()):
			scored.append([goal_score(g, p, cands[i]), i, cands[i]])
		scored.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		goals = []
		for s in scored.slice(0, 3):
			goals.append(s[2])
	if goals.is_empty():
		return null
	var gscore := 0.0
	for gid in goals:
		gscore += goal_score(g, p, gid)
	var w := [0.0, 0.0, 0.0, 0.0, 0.0]
	for rank in range(goals.size()):
		var kk: float = [1.0, 0.6, 0.35][mini(rank, 2)]
		var cost: Array = g.cards[goals[rank]].cost
		for c in range(5):
			if cost[c] > p.bonus[c]:
				w[c] += kk * (cost[c] - p.bonus[c])
	var tot: float = w[0] + w[1] + w[2] + w[3] + w[4]
	if tot == 0:
		tot = 1.0
	var best_nb := -1
	var best_ns := 0.0
	for nb in g.nobles:
		var req: Array = g.patron_req(nb)
		var d := g.patron_distance(p.bonus, nb)
		var nxt := g.patron_pts(p, nb)
		var overlap := 0.0
		for c in range(5):
			if req[c] > 0:
				overlap += w[c]
		overlap /= tot
		var ns := nxt * (0.5 + overlap) / (d + 2.0)
		if ns > best_ns:
			best_ns = ns
			best_nb = nb
	if best_nb >= 0:
		var req2: Array = g.patron_req(best_nb)
		var nw: float = P["plan_noble_w"]
		for c in range(5):
			if req2[c] > p.bonus[c]:
				w[c] += nw * (req2[c] - p.bonus[c])
	var tot2: float = w[0] + w[1] + w[2] + w[3] + w[4]
	if tot2 > 0:
		for c in range(5):
			w[c] /= tot2
	else:
		w = [0.2, 0.2, 0.2, 0.2, 0.2]
	return {"goals": goals.duplicate(), "w": w, "noble": best_nb, "gscore": gscore}


static func update_plan(g: GameState, p: GameState.PlayerState):
	var P: Dictionary = p.params
	var available := {}
	for e in g.market_cards():
		available[e[2]] = true
	for cid in p.reserved:
		available[cid] = true
	var cur = p.plan
	var alive_goals: Array = []
	var main_alive := false
	if cur != null:
		for gid in cur["goals"]:
			if available.has(gid):
				alive_goals.append(gid)
		main_alive = available.has(cur["goals"][0])
	if cur != null and main_alive and p.turns - p.plan_round < int(P["plan_every"]):
		var upd = build_plan(g, p, alive_goals)
		p.plan = upd if upd != null else cur
		return p.plan
	var fresh = build_plan(g, p)
	var kept = build_plan(g, p, alive_goals) if main_alive else null
	if kept != null and (fresh == null or fresh["gscore"] <= P["plan_switch"] * kept["gscore"]):
		p.plan = kept
	else:
		if cur != null and fresh != null:
			p.replans += 1
		p.plan = fresh
	p.plan_round = p.turns
	return p.plan


static func card_value_plan(g: GameState, p: GameState.PlayerState, cid: int, plan, demand: Array, maxdemand: float) -> float:
	var P: Dictionary = p.params
	var cd: Defs.CardDef = g.cards[cid]
	var vec := g.card_gain(p, cid)
	var v := float(cd.points)
	var phase := maxf(0.0, 1.0 - float(p.points) / g.target_of(p))
	var w: Array = plan["w"] if plan != null else [0.2, 0.2, 0.2, 0.2, 0.2]
	var ew: float = P["engine_w"]
	v += ew * phase * (P["plan_base_engine"] * _sum(vec) + P["plan_color_w"] * _dot(w, vec))
	if maxdemand > 0:
		v += P["plan_demand_w"] * ew * phase * _dot(demand, vec) / maxdemand
	var other: float = P["plan_noble_other"]
	for nb in g.nobles:
		if not _helps(g.patron_req(nb), p.bonus, vec):
			continue
		var d := g.patron_distance(p.bonus, nb)
		if d <= 0:
			continue
		v += (1.0 if plan != null and nb == plan["noble"] else other) * g.patron_pts(p, nb) / d
	if plan != null and plan["goals"].has(cid):
		var gb: float = P["plan_goal_bonus"]
		v += gb if cid == plan["goals"][0] else 0.5 * gb
	return v + color_bonus(g, p, cd)


static func scored_cards_plan(g: GameState, p: GameState.PlayerState, plan) -> Array:
	var demand := color_demand(g, p)
	var md: float = demand.max()
	var noise: float = p.params["noise"]
	var out: Array = []
	for c in _candidates(g, p):
		var cd: Defs.CardDef = g.cards[c[3]]
		var v := card_value_plan(g, p, c[3], plan, demand, md) * (1.0 + g.rng.randfn(0.0, noise))
		var t := turns_estimate(g, p, cd.cost)
		var afford := g.can_afford(p, c[3])
		out.append([v / (t + 1.0), v, c[0], c[1], c[2], c[3], afford])
	out.sort_custom(_sort_scored)
	return out


# ---------------------------------------------------------------------------
# Negacao cirurgica
# ---------------------------------------------------------------------------
static func threat_value(g: GameState, q: GameState.PlayerState, cid: int) -> int:
	var cd: Defs.CardDef = g.cards[cid]
	var v: int = cd.points + immediate_noble_pts(g, q, g.card_gain(q, cid))
	if q.points + v >= g.target_of(q) or wins_by_color(g, q, cd):
		v += 10
	return v


static func reach(g: GameState, q: GameState.PlayerState, cost: Array, bank: Array) -> int:
	## 0 = ja pode comprar; 1 = pode comprar depois de UMA coleta; 2 = mais longe.
	var d := [0, 0, 0, 0, 0]
	var tot := 0
	for c in range(5):
		d[c] = maxi(0, cost[c] - q.bonus[c] - q.tokens[c])
		tot += d[c]
	var gold: int = q.tokens[GOLD]
	if cost.size() > 5:
		gold -= cost[5]
	if tot <= gold:
		return 0
	var k := 0
	var need := 0
	for c in range(5):
		if d[c] == 0:
			continue
		if bank[c] >= 1:
			k += 1
			need += d[c] - 1
		else:
			need += d[c]
	need += maxi(0, k - 3)
	if need <= gold:
		return 1
	for x in range(5):
		if d[x] > 0 and bank[x] >= g.rules.take2_min:
			if tot - mini(2, d[x]) <= gold:
				return 1
	return 2


static func opponent_threats(g: GameState, idx: int) -> Array:
	var out: Array = []
	for j in range(g.n):
		if j == idx:
			continue
		var q: GameState.PlayerState = g.players[j]
		var ready := 0
		var near: Array = []
		var cands: Array = []
		for e in g.market_cards():
			cands.append(e[2])
		cands.append_array(q.reserved)
		for cid in cands:
			var r := reach(g, q, g.cards[cid].cost, g.bank)
			if r == 2:
				continue
			var v := threat_value(g, q, cid)
			if r == 0:
				ready = maxi(ready, v)
			elif v >= SURG_MIN_VALUE:
				near.append([g.cards[cid].cost, v])
		if not near.is_empty():
			out.append([q, ready, near])
	return out


static func blocked_value(g: GameState, threats: Array) -> float:
	var total := 0.0
	for t in threats:
		var q: GameState.PlayerState = t[0]
		var ready: int = t[1]
		var before := ready
		var after := ready
		for nv in t[2]:
			before = maxi(before, nv[1])
			if reach(g, q, nv[0], g.bank) <= 1:
				after = maxi(after, nv[1])
		total += before - after
	return total


static func defend_target(g: GameState, idx: int, my_targets: Array) -> Array:
	## Carta do mercado que um adversario ja pode comprar na proxima vez e que lhe daria muitos
	## pontos (carta + o filosofo ou escritor que ela traria). [linha, coluna, id, valor] ou [].
	## Em empate, prefere a que tambem serve a este jogador.
	var best: Array = []
	var best_v := -1.0
	for j in range(g.n):
		if j == idx:
			continue
		var q: GameState.PlayerState = g.players[j]
		for e in g.market_cards():
			if g.can_afford(q, e[2]):
				var v := threat_value(g, q, e[2])
				if v < DEFEND_VALUE:
					continue
				var score := float(v) + (0.5 if my_targets.has(e[2]) else 0.0)
				if score > best_v:
					best_v = score
					best = [e[0], e[1], e[2], v]
	return best


static func hate_reserve_target(g: GameState, idx: int) -> Array:
	var best: Array = []
	var best_v := -1
	for j in range(g.n):
		if j == idx:
			continue
		var q: GameState.PlayerState = g.players[j]
		for e in g.market_cards():
			if g.can_afford(q, e[2]):
				var v := threat_value(g, q, e[2])
				if v >= SURG_RESERVE_VALUE and v > best_v:
					best_v = v
					best = [e[0], e[1], e[2]]
	return best


# ---------------------------------------------------------------------------
# Busca no fim de jogo (Monte Carlo com amostragem das cartas ocultas)
# ---------------------------------------------------------------------------
static func endgame_active(g: GameState) -> bool:
	var mx := -999
	for q in g.players:
		mx = maxi(mx, q.points - g.target_of(q))
		var t := g.spec_threshold(q)
		if t > 0 and q.color_pts.max() >= t - 4:
			return true
	return mx >= -ENDGAME_MARGIN


static func candidate_actions(g: GameState, idx: int, sc: Array) -> Array:
	var p: GameState.PlayerState = g.players[idx]
	var out: Array = []
	for s in sc:
		if s[6]:
			out.append(_buy(s))
	var targets: Array = []
	var res_cands: Array = []
	for s in sc:
		if not s[6]:
			if targets.size() < 3:
				targets.append(s[5])
			if s[2] == "m" and res_cands.size() < 2:
				res_cands.append(["reserve", s[3], s[4]])
	# melhores coletas
	var scored_takes: Array = []
	for opt in take_options(g):
		var t: Array = p.tokens.duplicate()
		for c in opt:
			t[c] += 1
		scored_takes.append([token_utility(g, p, targets, t), opt])
	scored_takes.sort_custom(func(a, b): return a[0] > b[0])
	for i in range(mini(3, scored_takes.size())):
		out.append(["take", scored_takes[i][1]])
	if can_res(p):
		out.append_array(res_cands)
		var th := opponent_threat(g, idx)
		if not th.is_empty():
			out.append(["reserve", th[0], th[1]])
	if out.is_empty():
		out.append(["pass"])
	return out.slice(0, ENDGAME_MAX_CANDS)


static func search_action(g: GameState, idx: int, sc: Array) -> Array:
	var cands := candidate_actions(g, idx, sc)
	if cands.size() == 1:
		return cands[0]
	var base_seed := g.rng.randi()
	var best: Array = cands[0]
	var best_v := -1e18
	for a in cands:
		var total := 0.0
		for r in range(ENDGAME_ROLLOUTS):
			var sim := g.clone_for_search(idx, base_seed + r * 7919)
			sim.apply_ai_action(a)
			var guard := 0
			while not sim.finished and guard < 400:
				sim.apply_ai_action(choose_action(sim, sim.current))
				guard += 1
			total += _score(sim, idx)
		if total > best_v:
			best_v = total
			best = a
	return best


static func _score(sim: GameState, idx: int) -> float:
	var w := sim.winners()
	var v := 1.0 / w.size() if w.has(idx) else 0.0
	var mine: int = sim.players[idx].points
	var other := 0
	for j in range(sim.n):
		if j != idx:
			other = maxi(other, sim.players[j].points)
	return v + 0.02 * clampi(mine - other, -10, 10)
