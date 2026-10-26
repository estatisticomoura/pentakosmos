class_name GameScreen
extends Control
## Mesa de jogo: mercado, nobres, banco de fichas, paineis dos jogadores,
## reservas, acoes e animacoes.

signal back_to_menu
signal restart

const MARKET_X := 12
const MARKET_Y := 132
const COL_W := 118
const ROW_H := 160
const BANK_X := 734
const PANEL_X := 824
const PANEL_W := 448

var g: GameState
var viewer := 0            # jogador humano cujas reservas/afordabilidade sao mostradas
var ai_delay := 0.6
var _busy := false
var _alive := true

var sel_tokens: Array = []
var sel_card := {}         # {"src": "m"/"r"/"deck", "lv":, "slot":, "idx":}

var _market_views := [[], [], [], []]
var _deck_views := [null, null, null, null]
var _token_views: Array = []
var _panels: Array = []
var _reserve_views: Array = []
var _noble_box: Control
var _noble_views: Array = []
var _round_label: Label
var _log_label: Label
var _hint: Label
var _reserve_title: Label
var _btn_take: Button
var _btn_buy: Button
var _btn_reserve: Button
var _btn_clear: Button
var _btn_pass: Button
var _tray: Control
var _fx: Control
var _overlay: Control = null
var _peek: Control = null
var _peek_src := []            # [painel, zona]
var reveal_mode := "rodada"    # reservas dos adversarios: "rodada" ou "sempre"
var _overlay_kind := ""
var _info: Control = null      # dica de carta, baralho ou nobre
var _info_src: Control = null
var _banner: Label


func _init() -> void:
	size = Vector2(1280, 720)


func _exit_tree() -> void:
	_alive = false


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------
func start(rules: RuleSet, players: Array) -> void:
	g = GameState.new()
	g.setup(rules, players)
	ai_delay = Store.get_value("game", "ai_delay", 0.6)
	reveal_mode = Store.get_value("game", "reserva_visivel", "rodada")
	viewer = 0
	for i in range(g.n):
		if not g.players[i].is_ai():
			viewer = i
			break
	_build()
	refresh()
	_continue()


func _build() -> void:
	# barra superior
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.35)
	top.size = Vector2(1280, 34)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_round_label = UITheme.label("", 16, UITheme.GOLD)
	_round_label.position = Vector2(12, 6)
	add_child(_round_label)
	_log_label = UITheme.label("", 15, UITheme.TEXT)
	_log_label.position = Vector2(470, 7)
	_log_label.size = Vector2(700, 22)
	_log_label.clip_text = true
	add_child(_log_label)
	var menu := UITheme.button(L.t("Menu"), 15, Vector2(80, 28))
	menu.position = Vector2(1190, 3)
	menu.pressed.connect(_show_pause)
	add_child(menu)

	# nobres
	_noble_box = Control.new()
	_noble_box.position = Vector2(12, 40)
	add_child(_noble_box)

	# mercado (nivel 3 em cima)
	var m := g.rules.market_for(g.n)
	for lv in [3, 2, 1]:
		var row: int = 3 - lv
		var y: int = MARKET_Y + row * ROW_H
		var dv := CardView.new()
		dv.position = Vector2(MARKET_X, y)
		dv.src = "deck"
		dv.lv = lv
		dv.pressed.connect(_on_card_pressed)
		dv.hover_changed.connect(_on_card_hover)
		add_child(dv)
		_deck_views[lv] = dv
		_market_views[lv] = []
		for s in range(m):
			var cv := CardView.new()
			cv.position = Vector2(MARKET_X + (s + 1) * COL_W, y)
			cv.src = "m"
			cv.lv = lv
			cv.slot = s
			cv.pressed.connect(_on_card_pressed)
			cv.hover_changed.connect(_on_card_hover)
			add_child(cv)
			_market_views[lv].append(cv)

	# banco
	for c in range(6):
		var tv := TokenView.new()
		tv.position = Vector2(BANK_X, 128 + c * 76)
		tv.color_idx = c
		tv.pressed.connect(_on_token_pressed)
		add_child(tv)
		_token_views.append(tv)

	# paineis dos jogadores
	var h := clampf((454.0 - 6.0 * (g.n - 1)) / g.n, 84.0, 112.0)
	for i in range(g.n):
		var pp := PlayerPanel.new()
		pp.g = g
		pp.idx = i
		pp.position = Vector2(PANEL_X, 40 + i * (h + 6))
		pp.size = Vector2(PANEL_W, h)
		pp.zone_hover.connect(_on_zone_hover)
		pp.zone_tap.connect(_on_zone_tap)
		add_child(pp)
		_panels.append(pp)

	# reservas do jogador observado
	_reserve_title = UITheme.label("", 15, UITheme.MUTED)
	_reserve_title.position = Vector2(PANEL_X + 4, 504)
	add_child(_reserve_title)
	for i in range(3):
		var rv := CardView.new()
		rv.position = Vector2(PANEL_X + 8 + i * 124, 530)
		rv.src = "r"
		rv.slot = i
		rv.pressed.connect(_on_card_pressed)
		rv.hover_changed.connect(_on_card_hover)
		add_child(rv)
		_reserve_views.append(rv)
	var meta := UITheme.label("", 14, UITheme.MUTED)
	meta.name = "Meta"
	meta.position = Vector2(PANEL_X + 380, 540)
	meta.size = Vector2(70, 120)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(meta)

	# acoes
	_hint = UITheme.label("", 15, UITheme.MUTED)
	_hint.position = Vector2(12, 614)
	_hint.size = Vector2(800, 22)
	_hint.clip_text = true
	add_child(_hint)
	_tray = Control.new()
	_tray.position = Vector2(12, 642)
	_tray.size = Vector2(250, 66)
	_tray.draw.connect(_draw_tray)
	_tray.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray.gui_input.connect(_on_tray_input)
	add_child(_tray)
	var bar := HBoxContainer.new()
	bar.position = Vector2(270, 648)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	_btn_take = UITheme.button(L.t("Take"), 19, Vector2(118, 56))
	_btn_take.pressed.connect(_on_take)
	_btn_buy = UITheme.button(L.t("Buy"), 19, Vector2(118, 56))
	_btn_buy.pressed.connect(_on_buy)
	_btn_reserve = UITheme.button(L.t("Reserve"), 19, Vector2(118, 56))
	_btn_reserve.pressed.connect(_on_reserve)
	_btn_clear = UITheme.button(L.t("Clear"), 17, Vector2(96, 56))
	_btn_clear.pressed.connect(_clear_selection.bind(true))
	_btn_pass = UITheme.button(L.t("Pass"), 17, Vector2(96, 56))
	_btn_pass.pressed.connect(_on_pass)
	for b in [_btn_take, _btn_buy, _btn_reserve, _btn_clear, _btn_pass]:
		bar.add_child(b)

	# camada de efeitos
	_fx = Control.new()
	_fx.size = size
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_banner = UITheme.label("", 34, UITheme.GOLD)
	_banner.size = Vector2(1280, 60)
	_banner.position = Vector2(0, 300)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


# ---------------------------------------------------------------------------
# Atualizacao da tela
# ---------------------------------------------------------------------------
func _human_turn() -> bool:
	return g != null and not g.finished and not g.cur().is_ai() and g.current == viewer and g.phase == "acao"


func refresh() -> void:
	var p: GameState.PlayerState = g.cur()
	var vp: GameState.PlayerState = g.players[viewer]
	var human := _human_turn()
	var who := L.f("Your turn, {name}", {"name": p.name}) if human else L.f("Turn: {name}", {"name": p.name})
	if g.finished:
		_round_label.text = L.f("Round {n} · Game over", {"n": g.round_no})
	else:
		_round_label.text = L.f("Round {n} · {who}", {"n": g.round_no, "who": who}) + (L.t(" · last round!") if g.end_triggered else "")
	# nobres
	for v in _noble_views:
		v.queue_free()
	_noble_views = []
	# pontos que cada filosofo daria ao jogador observado agora (3, depois 2, depois 1)
	var pts_txt := str(g.rules.noble_pts(vp.nobles.size()))
	for i in range(g.nobles.size()):
		var nv := NobleView.new()
		nv.position = Vector2(i * 100, 0)
		nv.setup(g.nobles[i], pts_txt, g.rules.noble_mode == "flexivel",
			g.noble_distance(vp.bonus, Defs.NOBLES[g.nobles[i]]))
		nv.hover_changed.connect(_on_noble_hover)
		nv.pressed.connect(_on_noble_tap)
		_noble_box.add_child(nv)
		_noble_views.append(nv)
	# mercado
	for lv in [1, 2, 3]:
		var dv: CardView = _deck_views[lv]
		if g.decks[lv].is_empty():
			dv.set_empty()
		else:
			dv.set_back(lv, g.decks[lv].size(), g.rules.deck)
		dv.set_selected(sel_card.get("src", "") == "deck" and sel_card.get("lv", 0) == lv)
		for s in range(_market_views[lv].size()):
			var cv: CardView = _market_views[lv][s]
			var cid: int = g.market[lv][s]
			if cid < 0:
				cv.set_empty()
			else:
				if cv.card == null or cv.card.id != cid:
					cv.set_card(g.cards[cid], g.rules.deck)
					cv.modulate.a = 0.0
					create_tween().tween_property(cv, "modulate:a", 1.0, 0.35)
			cv.affordable = human and cid >= 0 and g.can_afford(vp, cid)
			cv.set_selected(sel_card.get("src", "") == "m" and sel_card.get("lv", 0) == lv and sel_card.get("slot", -1) == s)
	# banco
	for c in range(6):
		var picked := sel_tokens.count(c)
		_token_views[c].setup(c, g.bank[c], picked, human and c != Defs.GOLD)
	# paineis
	for i in range(g.n):
		_panels[i].is_current = (i == g.current and not g.finished)
		_panels[i].viewer = viewer
		_panels[i].reveal_mode = reveal_mode
		_panels[i].queue_redraw()
	if _peek != null and not _peek_src.is_empty():
		_show_peek(_peek_src[0], _peek_src[1])
	if _info != null and is_instance_valid(_info_src) and not (_info_src is NobleView):
		_show_card_info(_info_src)
	# reservas
	_reserve_title.text = L.f("Reserves: {name} ({n}/3)", {"name": vp.name, "n": vp.reserved.size()})
	for i in range(3):
		var rv: CardView = _reserve_views[i]
		if i < vp.reserved.size():
			rv.set_card(g.cards[vp.reserved[i]], g.rules.deck)
			rv.affordable = human and g.can_afford(vp, vp.reserved[i])
		else:
			rv.set_empty()
			rv.affordable = false
		rv.set_selected(sel_card.get("src", "") == "r" and sel_card.get("idx", -1) == i)
	var meta: Label = get_node("Meta")
	meta.text = L.f("Goal\n{pts} pts\n\nHand\n{n} tokens", {"pts": g.rules.target, "n": g.rules.hand_limit})
	_update_buttons()
	_tray.queue_redraw()


func _update_buttons() -> void:
	var human := _human_turn()
	_btn_take.disabled = not (human and g.valid_take(sel_tokens))
	var can_buy := false
	var can_res := false
	if human and not sel_card.is_empty():
		var vp: GameState.PlayerState = g.players[viewer]
		match sel_card["src"]:
			"m":
				var cid: int = g.market[sel_card["lv"]][sel_card["slot"]]
				can_buy = cid >= 0 and g.can_afford(vp, cid)
				can_res = cid >= 0 and g.can_reserve()
			"deck":
				can_res = g.can_reserve() and not g.decks[sel_card["lv"]].is_empty()
			"r":
				var i: int = sel_card["idx"]
				can_buy = i < vp.reserved.size() and g.can_afford(vp, vp.reserved[i])
	_btn_buy.disabled = not can_buy
	_btn_reserve.disabled = not can_res
	_btn_clear.disabled = not human or (sel_tokens.is_empty() and sel_card.is_empty())
	_btn_pass.visible = human and not g.has_any_action()
	_hint.text = _hint_text()


func _hint_text() -> String:
	if g.finished:
		return L.t("Game over.")
	if not _human_turn():
		return L.f("{name} is thinking...", {"name": g.cur().name}) if g.cur().is_ai() else ""
	if not sel_tokens.is_empty():
		if g.valid_take(sel_tokens):
			var full: bool = sel_tokens.size() == 3 or (sel_tokens.size() == 2 and sel_tokens[0] == sel_tokens[1])
			if full:
				return L.t("Tap Take to confirm (tap the tray to undo).")
			return L.t("Tap Take to take only these, or pick more elements (up to 3 different).")
		return L.f("Pick up to 3 different elements, or 2 of the same element from a pile of {n}+.", {"n": g.rules.take2_min})
	if not sel_card.is_empty():
		if sel_card["src"] == "deck":
			return L.f("Reserve the top card of level {lv} face down (you gain 1 {gold}).", {"lv": sel_card["lv"], "gold": L.color(Defs.GOLD)})
		return L.t("Tap the card again to buy it quickly, or use the buttons.")
	return L.t("Take tokens, buy an element card (green seal = affordable) or reserve one.")


func _draw_tray() -> void:
	GemDraw.rounded(_tray, Rect2(Vector2.ZERO, _tray.size), Color(0, 0, 0, 0.3), 10, Color(1, 1, 1, 0.1), 1)
	if sel_tokens.is_empty():
		GemDraw.ctext(_tray, L.t("chosen tokens"), _tray.size / 2.0, 13, Color(1, 1, 1, 0.3))
		return
	for i in range(sel_tokens.size()):
		GemDraw.draw_chip(_tray, sel_tokens[i], Vector2(40 + i * 70, _tray.size.y / 2.0), 24)


# ---------------------------------------------------------------------------
# Entrada do jogador
# ---------------------------------------------------------------------------
func _on_token_pressed(tv: TokenView) -> void:
	if not _human_turn() or tv.color_idx == Defs.GOLD:
		if tv.color_idx == Defs.GOLD and _human_turn():
			_hint.text = L.f("You only get {gold} by reserving a card.", {"gold": L.color(Defs.GOLD)})
			Audio.play("error")
		return
	var c := tv.color_idx
	sel_card = {}
	if sel_tokens.has(c):
		if sel_tokens.size() == 1 and g.can_take_two(c):
			sel_tokens.append(c)
		else:
			sel_tokens.erase(c)
	elif sel_tokens.size() == 2 and sel_tokens[0] == sel_tokens[1]:
		sel_tokens = [c]
	elif sel_tokens.size() < 3 and g.bank[c] > 0:
		sel_tokens.append(c)
	else:
		Audio.play("error")
		return
	Audio.play("select")
	refresh()


func _on_tray_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not sel_tokens.is_empty():
		var i := int((event.position.x - 10) / 70.0)
		if i >= 0 and i < sel_tokens.size():
			sel_tokens.remove_at(i)
			Audio.play("discard")
			refresh()


func _on_card_pressed(cv: CardView) -> void:
	if not _human_turn():
		return
	var new_sel := {}
	match cv.src:
		"m":
			new_sel = {"src": "m", "lv": cv.lv, "slot": cv.slot}
		"deck":
			new_sel = {"src": "deck", "lv": cv.lv}
		"r":
			if cv.slot >= g.players[viewer].reserved.size():
				return
			new_sel = {"src": "r", "idx": cv.slot}
	# segundo toque na mesma carta: compra rapida
	if sel_card == new_sel and new_sel["src"] != "deck":
		if not _btn_buy.disabled:
			_on_buy()
		else:
			Audio.play("error")
		return
	sel_tokens = []
	sel_card = new_sel
	Audio.play("select")
	refresh()
	_show_card_info(cv)


func _clear_selection(play_sound := false) -> void:
	sel_tokens = []
	sel_card = {}
	if play_sound:
		Audio.play("discard")
	if g != null:
		refresh()


func _on_take() -> void:
	if g.act_take(sel_tokens):
		_clear_selection()
		_continue()
	else:
		Audio.play("error")


func _on_buy() -> void:
	var ok := false
	if sel_card.get("src", "") == "m":
		ok = g.act_buy_market(sel_card["lv"], sel_card["slot"])
	elif sel_card.get("src", "") == "r":
		ok = g.act_buy_reserved(sel_card["idx"])
	if ok:
		_clear_selection()
		_continue()
	else:
		Audio.play("error")


func _on_reserve() -> void:
	var ok := false
	if sel_card.get("src", "") == "m":
		ok = g.act_reserve(sel_card["lv"], sel_card["slot"])
	elif sel_card.get("src", "") == "deck":
		ok = g.act_reserve(sel_card["lv"], -1)
	if ok:
		_clear_selection()
		_continue()
	else:
		Audio.play("error")


func _on_pass() -> void:
	if g.act_pass():
		_clear_selection()
		_continue()


# ---------------------------------------------------------------------------
# Fluxo do jogo
# ---------------------------------------------------------------------------
func _humans() -> int:
	var k := 0
	for p in g.players:
		if not p.is_ai():
			k += 1
	return k


func _continue() -> void:
	if _busy:
		return
	_busy = true
	while _alive:
		await _drain_events()
		if not _alive:
			return
		refresh()
		if g.finished:
			_show_game_over()
			break
		var p: GameState.PlayerState = g.cur()
		if p.is_ai():
			await get_tree().create_timer(ai_delay).timeout
			# espera enquanto o menu de pausa estiver aberto
			while _alive and _overlay_kind == "Pausa":
				await get_tree().create_timer(0.2).timeout
			if not _alive:
				return
			g.apply_ai_action(AI.choose_action(g, g.current))
			continue
		if _humans() > 1 and viewer != g.current:
			await _hotseat(g.current)
			if not _alive:
				return
		viewer = g.current
		refresh()
		if g.phase == "descarte":
			_show_discard()
		elif g.phase == "nobre":
			_show_noble_choice()
		else:
			Audio.play("turn")
		break
	_busy = false


func _drain_events() -> void:
	while not g.events.is_empty():
		var evs: Array = g.events
		g.events = []
		for e in evs:
			var wait := _animate_event(e)
			if wait > 0.0:
				await get_tree().create_timer(wait).timeout
				if not _alive:
					return


func _animate_event(e: Dictionary) -> float:
	var t: String = e["t"]
	var pi: int = e.get("p", 0)
	var pname: String = g.players[pi].name if pi < g.n else ""
	var panel: PlayerPanel = _panels[pi] if pi < _panels.size() else null
	match t:
		"take":
			for k in range(e["colors"].size()):
				var c: int = e["colors"][k]
				_fly_chip(c, _center_of(_token_views[c]), _panel_point(panel, panel.token_pos(c)), k * 0.09,
					func(): _land_token(panel, c))
			_log(L.f("{name} took {colors}.", {"name": pname, "colors": L.colors(e["colors"])}))
			Audio.play("token", 0.06, -4.0)
			return 0.7
		"buy":
			var cd: Defs.CardDef = g.cards[e["card"]]
			var from := Rect2()
			if e["src"] == "m":
				from = _rect_of(_market_views[e["lv"]][e["slot"]])
			elif pi == viewer and e["idx"] < _reserve_views.size():
				from = _rect_of(_reserve_views[e["idx"]])
			else:
				from = Rect2(_panel_point(panel, Vector2(PANEL_W / 2.0, 20)) - CardView.BASE_SIZE / 2.0, CardView.BASE_SIZE)
			var bc: int = cd.bonus
			_fly_card(cd, from, _panel_point(panel, panel.bonus_pos(bc)), 1,
				func(): _land_card(panel, bc))
			var paid: Array = e["paid"]
			var k2 := 0
			for c in range(6):
				for j in range(paid[c]):
					var tv: TokenView = _token_views[c]
					_fly_chip(c, _panel_point(panel, panel.token_pos(c)), _center_of(tv), 0.25 + 0.06 * k2,
						func(): Audio.play("chip", 0.1, -12.0))
					k2 += 1
			_log(L.f("{name} bought a level {lv} card ({color}){pts}.", {"name": pname, "lv": cd.level,
				"color": L.color(cd.bonus), "pts": (" +%d" % cd.points) if cd.points > 0 else ""}))
			Audio.play("buy", 0.04, -3.0)
			return 0.9
		"reserve":
			var cd2: Defs.CardDef = g.cards[e["card"]]
			var from2: Rect2 = _rect_of(_deck_views[e["lv"]]) if e["blind"] else _rect_of(_market_views[e["lv"]][e["slot"]])
			var to: Vector2 = _rect_of(_reserve_views[mini(g.players[pi].reserved.size() - 1, 2)]).get_center() if pi == viewer \
				else _panel_point(panel, Vector2(PANEL_W / 2.0, 20))
			_fly_card(null if e["blind"] else cd2, from2, to, e["lv"], func(): panel.pulse("r"))
			if e["gold"]:
				_fly_chip(Defs.GOLD, _center_of(_token_views[Defs.GOLD]), _panel_point(panel, panel.token_pos(Defs.GOLD)), 0.3,
					func(): _land_token(panel, Defs.GOLD))
			if e["blind"]:
				_log(L.f("{name} reserved a level {lv} card face down.", {"name": pname, "lv": e["lv"]}))
			else:
				_log(L.f("{name} reserved a level {lv} card ({color}){pts}. Hover over their reserves to see it again.", {"name": pname,
					"lv": cd2.level, "color": L.color(cd2.bonus), "pts": (" +%d" % cd2.points) if cd2.points > 0 else ""}))
			Audio.play("reserve", 0.04, -4.0)
			return 0.85
		"discard":
			var c3: int = e["color"]
			_fly_chip(c3, _panel_point(panel, panel.token_pos(c3)), _center_of(_token_views[c3]), 0.0)
			Audio.play("discard", 0.06, -6.0)
			return 0.12
		"noble":
			var phil := L.t(Defs.PHILOSOPHERS[e["noble"]])
			_log(L.f("{name}: {phil} joins the academy (+{pts})!", {"name": pname, "phil": phil, "pts": e["pts"]}))
			_show_banner(L.f("{name}: {phil} joins the academy (+{pts})!", {"name": pname, "phil": phil, "pts": e["pts"]}))
			for nv in _noble_views:
				if nv.noble == e["noble"]:
					var tw := create_tween().set_parallel()
					tw.tween_property(nv, "global_position", _panel_point(panel, Vector2(PANEL_W - 120, 0)) + global_position, 0.6) \
						.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
					tw.tween_property(nv, "scale", Vector2(0.4, 0.4), 0.6)
			Audio.play("noble")
			return 0.9
		"color":
			_show_banner(L.f("{name}: {pts} points in {color}!", {"name": pname, "pts": e["pts"], "color": L.color(e["color"])}))
			_log(L.f("{name} achieved the specialization victory ({pts} points in {color}).", {"name": pname, "pts": e["pts"], "color": L.color(e["color"])}))
			Audio.play("noble")
			return 1.0
		"last_round":
			_show_banner(L.t("Last round!"))
			if e.get("reason", "pontos") == "cor":
				_log(L.f("{name} reached the specialization victory: last round!", {"name": pname}))
			else:
				_log(L.f("{name} reached {pts} points: last round!", {"name": pname, "pts": g.players[pi].points}))
			Audio.play("turn")
			return 0.8
		"pass":
			_log(L.f("{name} passed.", {"name": pname}))
			return 0.2
	return 0.0


func _log(s: String) -> void:
	_log_label.text = s


func _show_banner(s: String) -> void:
	_banner.text = s
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.1)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


# --- geometria e efeitos -----------------------------------------------------
func _rect_of(c: Control) -> Rect2:
	var gr := c.get_global_rect()
	return Rect2(get_global_transform().affine_inverse() * gr.position, gr.size / c.scale)


func _center_of(c: Control) -> Vector2:
	return _rect_of(c).get_center()


func _panel_point(panel: PlayerPanel, local: Vector2) -> Vector2:
	if panel == null:
		return Vector2(PANEL_X, 60)
	return panel.position + local


func _land_token(panel: PlayerPanel, c: int) -> void:
	panel.pulse("t%d" % c)
	Audio.play("chip", 0.08, -8.0)


func _land_card(panel: PlayerPanel, c: int) -> void:
	panel.pulse("b%d" % c)
	Audio.play("chip", 0.05, -6.0)


func _fly_card(cd: Defs.CardDef, from: Rect2, to_center: Vector2, back_level := 1, on_land := Callable()) -> void:
	## Carta voando em arco ate o destino, encolhendo; ao chegar, chama on_land.
	var v := CardView.new()
	v.interactive = false
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cd != null:
		v.set_card(cd, g.rules.deck)
	else:
		v.set_back(back_level, -1, g.rules.deck)
	v.pivot_offset = Vector2.ZERO
	_fx.add_child(v)
	var p0 := from.position
	var end_scale := 0.22
	var p2 := to_center - CardView.BASE_SIZE * end_scale / 2.0
	var p1 := (p0 + p2) / 2.0 + Vector2(0, -110)
	var dur := 0.7
	var step := func(t: float) -> void:
		var u := ease(t, -2.0)  # acelera e desacelera
		v.position = p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
		var sc := lerpf(1.0, end_scale, ease(t, 1.6))
		v.scale = Vector2(sc, sc)
		v.modulate.a = 1.0 if t < 0.85 else (1.0 - t) / 0.15
	var land := func() -> void:
		if on_land.is_valid():
			on_land.call()
		v.queue_free()
	var tw := v.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)
	tw.tween_callback(land)


func _fly_chip(c: int, from: Vector2, to: Vector2, delay: float, on_land := Callable()) -> void:
	## Ficha voando em arco; ao chegar, chama on_land.
	var ctl := Control.new()
	ctl.size = Vector2(32, 32)
	ctl.pivot_offset = Vector2(16, 16)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.draw.connect(func(): GemDraw.draw_chip(ctl, c, Vector2(16, 16), 14))
	ctl.modulate.a = 0.0
	ctl.position = from - ctl.size / 2.0
	_fx.add_child(ctl)
	var p0 := from - ctl.size / 2.0
	var p2 := to - ctl.size / 2.0
	var p1 := (p0 + p2) / 2.0 + Vector2(0, -50)
	var step := func(t: float) -> void:
		var u := ease(t, -1.8)
		ctl.position = p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
		ctl.rotation = t * TAU * 0.5
	var land := func() -> void:
		if on_land.is_valid():
			on_land.call()
	var tw := ctl.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(ctl, "modulate:a", 1.0, 0.04)
	tw.tween_method(step, 0.0, 1.0, 0.45)
	tw.tween_callback(land)
	tw.tween_property(ctl, "modulate:a", 0.0, 0.08)
	tw.tween_callback(ctl.queue_free)


# ---------------------------------------------------------------------------
# Consulta rapida: reservas e nobres de um jogador (mouse por cima ou toque)
# ---------------------------------------------------------------------------
func _on_zone_hover(panel: PlayerPanel, zone: String) -> void:
	if zone == "":
		_hide_peek()
	else:
		_show_peek(panel, zone)


func _on_zone_tap(panel: PlayerPanel, zone: String) -> void:
	if _peek != null and _peek_src == [panel, zone]:
		_hide_peek()
	else:
		_show_peek(panel, zone)


func _hide_peek() -> void:
	if _peek != null:
		_peek.queue_free()
	_peek = null
	_peek_src = []


func _show_peek(panel: PlayerPanel, zone: String) -> void:
	if _peek != null:
		_peek.queue_free()
	var p: GameState.PlayerState = g.players[panel.idx]
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if zone == "reservas":
		v.add_child(UITheme.label(L.f("Reserves: {name}", {"name": p.name}), 16, UITheme.GOLD))
		var any_hidden := false
		for cid in p.reserved:
			var cv := CardView.new()
			cv.interactive = false
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if g.reserve_visible(panel.idx, cid, viewer, reveal_mode):
				cv.set_card(g.cards[cid], g.rules.deck)
				cv.affordable = panel.idx == viewer and g.can_afford(p, cid)
			else:
				cv.set_back(g.cards[cid].level, -1, g.rules.deck)
				any_hidden = true
			h.add_child(cv)
		v.add_child(h)
		var note := ""
		if panel.idx != viewer:
			if p.hidden.size() > 0:
				note = L.t("Face-down reserves stay hidden.")
			elif any_hidden:
				note = L.t("Older reserves are hidden (they are visible only until the player's next turn).")
			elif reveal_mode == "rodada":
				note = L.f("Visible until {name}'s next turn.", {"name": p.name})
		if note != "":
			v.add_child(UITheme.label(note, 12, UITheme.MUTED))
	else:
		v.add_child(UITheme.label(L.f("Philosophers: {name}", {"name": p.name}), 16, UITheme.GOLD))
		for k in range(p.nobles.size()):
			var nv := NobleView.new()
			nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nv.setup(p.nobles[k], "+%d" % g.rules.noble_pts(k), false)
			h.add_child(nv)
		v.add_child(h)
		v.add_child(UITheme.label(L.f("{n} points from philosophers", {"n": p.noble_points}), 12, UITheme.MUTED))
	add_child(box)
	_peek = box
	_peek_src = [panel, zone]
	await get_tree().process_frame
	if not is_instance_valid(box) or _peek != box:
		return
	var sz := box.get_combined_minimum_size()
	box.size = sz
	box.position = Vector2(PANEL_X - sz.x - 10, clampf(panel.position.y, 40, 720 - sz.y - 8))


# ---------------------------------------------------------------------------
# Dicas: o que falta para comprar uma carta, cartas no baralho, nobres
# ---------------------------------------------------------------------------
func _hide_info() -> void:
	if _info != null:
		_info.queue_free()
	_info = null
	_info_src = null


func _on_card_hover(cv: CardView, on: bool) -> void:
	if on:
		_show_card_info(cv)
	elif _info_src == cv:
		_hide_info()


func _on_noble_hover(nv: NobleView, on: bool) -> void:
	if on:
		_show_noble_info(nv)
	elif _info_src == nv:
		_hide_info()


func _on_noble_tap(nv: NobleView) -> void:
	if _info_src == nv:
		_hide_info()
	else:
		_show_noble_info(nv)


func _need_of(p: GameState.PlayerState, cd: Defs.CardDef) -> Array:
	var need: Array = []
	for c in range(5):
		need.append(maxi(0, cd.cost[c] - p.bonus[c] - p.tokens[c]))
	return need


func _gem_row(counts: Array, prefix := "") -> Control:
	## Linha de simbolos com numeros (so as cores com valor > 0).
	var cols: Array = []
	for c in range(counts.size()):
		if counts[c] > 0:
			cols.append(c)
	var ctl := Control.new()
	ctl.custom_minimum_size = Vector2(maxi(1, cols.size()) * 52, 30)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.draw.connect(func():
		for i in range(cols.size()):
			var c: int = cols[i]
			var center := Vector2(14 + i * 52, 15)
			GemDraw.draw_gem(ctl, c, center, 11)
			GemDraw.text(ctl, prefix + str(counts[c]), center + Vector2(15, 6), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3))
	return ctl


func _info_box(anchor: Control, lines: Array) -> void:
	## lines: Strings (texto) ou Controls.
	_hide_info()
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 20
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var first := true
	for it in lines:
		if it is Control:
			v.add_child(it)
		else:
			var l := UITheme.label(it, 16 if first else 14, UITheme.GOLD if first else UITheme.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(260, 0)
			v.add_child(l)
		first = false
	add_child(box)
	_info = box
	_info_src = anchor
	var r := _rect_of(anchor)
	await get_tree().process_frame
	if not is_instance_valid(box) or _info != box:
		return
	var sz := box.get_combined_minimum_size()
	box.size = sz
	var x := r.end.x + 10.0
	if x + sz.x > 1270.0:
		x = r.position.x - sz.x - 10.0
	box.position = Vector2(clampf(x, 4.0, 1276.0 - sz.x), clampf(r.position.y, 40.0, 716.0 - sz.y))


func _show_card_info(cv: CardView) -> void:
	var vp: GameState.PlayerState = g.players[viewer]
	if cv.src == "deck":
		var lv := cv.lv
		var total := 0
		for cd in g.cards:
			if cd.level == lv:
				total += 1
		var left: int = g.decks[lv].size()
		_info_box(cv, [L.f("Level {lv} deck", {"lv": lv}),
			L.f("{n} cards left in the deck; {out} have already been drawn.", {"n": left, "out": total - left})])
		return
	var cid := -1
	if cv.src == "m":
		cid = g.market[cv.lv][cv.slot]
	elif cv.src == "r" and cv.slot < vp.reserved.size():
		cid = vp.reserved[cv.slot]
	if cid < 0:
		_hide_info()
		return
	var cd: Defs.CardDef = g.cards[cid]
	var need := _need_of(vp, cd)
	var short := 0
	for c in range(5):
		short += need[c]
	var gold: int = vp.tokens[Defs.GOLD]
	var gname := L.color(Defs.GOLD)
	var lines: Array = [L.t("To buy this card")]
	if short == 0:
		lines.append(L.f("You can buy it with elements only (no {gold}).", {"gold": gname}))
	else:
		lines.append(L.f("Elements only: {n} missing", {"n": short}))
		lines.append(_gem_row(need, "−"))
		if gold == 0:
			lines.append(L.f("You have no {gold}.", {"gold": gname}))
		elif short <= gold:
			lines.append(L.f("With {gold} (you have {g}): you can buy it", {"gold": gname, "g": gold}))
		else:
			lines.append(L.f("With {gold} (you have {g}): {n} missing", {"gold": gname, "g": gold, "n": short - gold}))
	if g.rules.color_win > 0 and cd.points > 0:
		lines.append(L.f("Specialization: {a} → {b} points in {color}", {"a": vp.color_pts[cd.bonus],
			"b": vp.color_pts[cd.bonus] + cd.points, "color": L.color(cd.bonus)}))
	_info_box(cv, lines)


func _show_noble_info(nv: NobleView) -> void:
	var lines: Array = [L.t(Defs.PHILOSOPHERS[nv.noble]) if nv.noble >= 0 else L.t("Philosopher")]
	lines.append(L.t("A philosopher joins your academy automatically at the end of your turn when your element cards (bonuses) meet the requirement shown."))
	lines.append(L.t("Top left: the points this philosopher would give you now."))
	if nv.progress >= 0:
		if nv.progress == 0:
			lines.append(L.t("The number in the corner shows how many more cards you need: you already meet this one."))
		else:
			lines.append(L.f("The number in the corner shows how many more cards you need: {n}.", {"n": nv.progress}))
	if nv.flexible:
		lines.append(L.t("−2 any: the total requirement is 2 cards lower, and those 2 can be missing from any elements."))
	if g.rules.noble_points_mode == "decrescente":
		lines.append(L.t("Your first philosopher is worth 3 points, the second 2, and each one after that 1."))
	else:
		lines.append(L.t("Each philosopher is worth 3 points."))
	_info_box(nv, lines)


# ---------------------------------------------------------------------------
# Janelas (overlays)
# ---------------------------------------------------------------------------
func _open_overlay(title: String, oname := "Overlay") -> VBoxContainer:
	_close_overlay()
	var o := Control.new()
	o.name = oname
	o.size = size
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = size
	o.add_child(dim)
	var center := CenterContainer.new()
	center.size = size
	o.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := UITheme.label(title, 26, UITheme.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	add_child(o)
	_overlay = o
	_overlay_kind = oname
	o.modulate.a = 0.0
	create_tween().tween_property(o, "modulate:a", 1.0, 0.2)
	return v


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_overlay_kind = ""


func _hotseat(idx: int) -> void:
	var nm: String = g.players[idx].name
	var v := _open_overlay(L.f("Turn: {name}", {"name": nm}))
	v.add_child(UITheme.label(L.f("Pass the device to {name}.", {"name": nm}), 18))
	var b := UITheme.button(L.f("I'm {name}, start", {"name": nm}), 20, Vector2(320, 54))
	v.add_child(b)
	await b.pressed
	_close_overlay()


func _show_discard() -> void:
	var p := g.cur()
	var v := _open_overlay(L.f("Limit of {n} tokens", {"n": g.rules.hand_limit}))
	var info := UITheme.label("", 18)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var views: Array = []
	var upd := func():
		info.text = L.f("You have {n} tokens. Tap to return {k}.", {"n": p.token_count(), "k": p.token_count() - g.rules.hand_limit})
		for tv in views:
			tv.setup(tv.color_idx, p.tokens[tv.color_idx], 0, p.tokens[tv.color_idx] > 0)
	for c in range(6):
		var tv := TokenView.new()
		tv.color_idx = c
		tv.pressed.connect(func(x: TokenView):
			if g.discard(x.color_idx):
				Audio.play("discard")
				if g.phase != "descarte":
					_close_overlay()
					_continue()
				else:
					upd.call()
					refresh())
		h.add_child(tv)
		views.append(tv)
	upd.call()


func _show_noble_choice() -> void:
	var v := _open_overlay(L.t("Choose a philosopher"))
	v.add_child(UITheme.label(L.t("You meet the requirements of more than one philosopher."), 17))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var pts := g.rules.noble_pts(g.cur().nobles.size())
	for nb in g.noble_options:
		var nv := NobleView.new()
		nv.setup(nb, "+%d" % pts, g.rules.noble_mode == "flexivel")
		nv.selectable = true
		nv.pressed.connect(func(x: NobleView):
			if g.choose_noble(x.noble):
				_close_overlay()
				_continue())
		h.add_child(nv)


func _show_pause() -> void:
	if _overlay != null:
		return
	var v := _open_overlay(L.t("Pause"), "Pausa")
	var cont := UITheme.button(L.t("Continue"), 20, Vector2(320, 50))
	cont.pressed.connect(_close_overlay)
	v.add_child(cont)
	var speed := HBoxContainer.new()
	speed.add_child(UITheme.label(L.t("AI speed"), 16, UITheme.MUTED))
	var so := UITheme.option([L.t("Slow"), L.t("Normal"), L.t("Fast")], [1.1, 0.6, 0.2].find(ai_delay) if [1.1, 0.6, 0.2].has(ai_delay) else 1)
	so.item_selected.connect(func(i):
		ai_delay = [1.1, 0.6, 0.2][i]
		Store.set_value("game", "ai_delay", ai_delay))
	speed.add_child(so)
	v.add_child(speed)
	var rv := HBoxContainer.new()
	rv.add_child(UITheme.label(L.t("Opponents' reserves"), 16, UITheme.MUTED))
	var ro := UITheme.option([L.t("Until the player's next turn"), L.t("Always visible")], 1 if reveal_mode == "sempre" else 0)
	ro.item_selected.connect(func(i):
		reveal_mode = ["rodada", "sempre"][i]
		Store.set_value("game", "reserva_visivel", reveal_mode)
		refresh())
	rv.add_child(ro)
	v.add_child(rv)
	for pair in [[L.t("Music"), "Music"], [L.t("Effects"), "SFX"]]:
		var h := HBoxContainer.new()
		var l := UITheme.label(pair[0], 16, UITheme.MUTED)
		l.custom_minimum_size = Vector2(90, 0)
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = 0.05
		s.value = Audio.get_volume(pair[1])
		s.custom_minimum_size = Vector2(220, 30)
		var bus: String = pair[1]
		s.value_changed.connect(func(x): Audio.set_volume(bus, x))
		s.drag_ended.connect(func(_c): Audio.save_volumes())
		h.add_child(s)
		v.add_child(h)
	var mp := HBoxContainer.new()
	var mpl := UITheme.label(L.t("Playlist"), 16, UITheme.MUTED)
	mpl.custom_minimum_size = Vector2(90, 0)
	mp.add_child(mpl)
	var picker := MusicPicker.make()
	picker.custom_minimum_size = Vector2(320, 36)
	mp.add_child(picker)
	v.add_child(mp)
	var rs := UITheme.button(L.t("Restart game"), 18, Vector2(320, 46))
	rs.pressed.connect(func(): restart.emit())
	v.add_child(rs)
	var mm := UITheme.button(L.t("Main menu"), 18, Vector2(320, 46))
	mm.pressed.connect(func(): back_to_menu.emit())
	v.add_child(mm)


func _show_game_over() -> void:
	var w := g.winners()
	var title := L.f("{name} wins!", {"name": g.players[w[0]].name}) if w.size() == 1 else L.t("Draw!")
	Audio.play("win")
	var v := _open_overlay(title, "Fim")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	v.add_child(grid)
	for hd in ["", L.t("Player"), L.t("Points"), L.t("Cards"), L.t("Philosophers")]:
		grid.add_child(UITheme.label(hd, 15, UITheme.MUTED))
	var pos := 1
	for i in g.ranking():
		var p: GameState.PlayerState = g.players[i]
		var col := UITheme.GOLD if w.has(i) else UITheme.TEXT
		grid.add_child(UITheme.label("%d." % pos, 18, col))
		grid.add_child(UITheme.label(p.name, 18, col))
		grid.add_child(UITheme.label(str(p.points), 18, col))
		grid.add_child(UITheme.label(str(p.cards), 18, col))
		grid.add_child(UITheme.label(str(p.nobles.size()), 18, col))
		pos += 1
	var wp: GameState.PlayerState = g.players[w[0]]
	if g.meets_color(wp):
		var bc := g.best_color(wp)
		v.add_child(UITheme.label(L.f("Specialization victory: {pts} points in {color} cards", {"pts": wp.color_pts[bc], "color": L.color(bc)}), 16, UITheme.GOLD))
	v.add_child(UITheme.label(L.f("{n} rounds · ties are broken by fewer cards bought", {"n": g.round_no}), 13, UITheme.MUTED))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	var again := UITheme.button(L.t("Play again"), 19, Vector2(200, 50))
	again.pressed.connect(func(): restart.emit())
	h.add_child(again)
	var menu := UITheme.button(L.t("Menu"), 19, Vector2(140, 50))
	menu.pressed.connect(func(): back_to_menu.emit())
	h.add_child(menu)
	var see := UITheme.button(L.t("View table"), 19, Vector2(140, 50))
	see.pressed.connect(_close_overlay)
	h.add_child(see)
	v.add_child(h)
