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
var _gov_box: Control = null
var _gov_views: Array = []
var _gain_sel: Array = []
const EFFECT_INFO := {"token": "When bought: take 1 token",  # tr
	"two_tokens": "When bought: take 2 tokens of different elements",  # tr
	"sphere": "When bought: take 1 sphere", "extra_turn": "When bought: play an extra turn"}  # tr
const WAIT_PHASES := ["descarte", "ganho", "nobre", "governante", "cega", "escolha_gov"]
var _overlay_kind := ""
var _info: Control = null      # dica de carta, baralho ou nobre
var _info_src: Control = null
var _banner: Label
# geometria (o modo toque reorganiza e aumenta tudo)
var _px := float(PANEL_X)     # x dos paineis dos jogadores
var _pw := float(PANEL_W)     # largura base dos paineis
var _s := 1.0                 # escala de cartas, filosofos e reservas
var _ps := 1.0                # escala dos paineis
var _recent: Array = []       # modo toque: o que os outros fizeram desde a sua ultima jogada
var _ns := 1.0                # escala dos cartoes de filosofos/escritores (mais cartoes = menores)
var _noble_avail := 800.0     # largura disponivel para a fila de filosofos/escritores
const RES_K := 0.8            # reservas do jogador a 80% do tamanho das cartas
# cronometros
var _timer: TimerView
var _game_secs := 0.0
var _turn_left := -1.0        # segundos restantes da vez do humano (-1 = sem limite)
var _turn_limit := 0
# estatisticas: tempo de cada acao dos humanos
var _act_start := -1.0
var _act_times := {}          # indice do jogador -> [soma em segundos, quantidade]
var _recorded := false


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
	NobleView.source = g
	ai_delay = Store.get_value("game", "ai_delay", 0.6)
	viewer = 0
	for i in range(g.n):
		if not g.players[i].is_ai():
			viewer = i
			break
	_build()
	refresh()
	_continue()


func _build() -> void:
	if UITheme.touch:
		_build_touch()
		return
	# barra superior
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.35)
	top.size = Vector2(1280, 34)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_round_label = Label.new()       # o texto da rodada fica no cronometro
	_timer = TimerView.new()
	_timer.compact = true
	_timer.position = Vector2(12, 4)
	_timer.size = Vector2(420, 28)
	add_child(_timer)
	_log_label = UITheme.label("", 15, UITheme.TEXT)
	_log_label.position = Vector2(440, 7)
	_log_label.size = Vector2(640, 22)
	_log_label.clip_text = true
	add_child(_log_label)
	var menu := UITheme.button(L.t("Menu"), 15, Vector2(80, 28))
	menu.position = Vector2(1190, 3)
	menu.pressed.connect(_show_pause)
	add_child(menu)
	var player := MusicControls.new()
	player.position = Vector2(1086, 3)
	add_child(player)

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
	_noble_avail = PANEL_X - 24.0
	var res_h := CardView.BASE_SIZE.y * RES_K
	var res_y := 720.0 - res_h - 8.0
	var h := clampf((res_y - 34.0 - 40.0 - 6.0 * (g.n - 1)) / g.n, 84.0, 118.0)
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
	_reserve_title.position = Vector2(PANEL_X + 4, res_y - 26)
	add_child(_reserve_title)
	var rw := CardView.BASE_SIZE.x * RES_K
	for i in range(3):
		var rv := CardView.new()
		rv.position = Vector2(PANEL_X + 8 + i * (rw + 10), res_y)
		rv.src = "r"
		rv.slot = i
		_scale_card(rv, RES_K)
		rv.pressed.connect(_on_card_pressed)
		rv.hover_changed.connect(_on_card_hover)
		add_child(rv)
		_reserve_views.append(rv)
	var meta := UITheme.label("", 15, UITheme.MUTED)
	meta.name = "Meta"
	meta.position = Vector2(PANEL_X + 8 + 3 * (rw + 10) + 4, res_y + 8)
	meta.size = Vector2(1272 - (PANEL_X + 8 + 3 * (rw + 10) + 4), res_h)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(meta)
	_build_gov_box(meta.position - Vector2(0, 8), Vector2(meta.size.x, res_h))

	# acoes (a antiga dica de texto saiu: as regras ficam em "Como jogar")
	_hint = Label.new()
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

	_build_fx()


func _build_fx() -> void:
	# camada de efeitos
	_fx = Control.new()
	_fx.size = size
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_banner = UITheme.label("", 34, UITheme.GOLD)
	_banner.size = Vector2(size.x, 60)
	_banner.position = Vector2(0, size.y / 2.0 - 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func _build_touch() -> void:
	## Celular/tablet na horizontal: botoes numa coluna a esquerda (perto do polegar),
	## registro das jogadas dos adversarios no alto, tudo maior.
	var W := size.x
	var H := size.y
	const LW := 156.0                  # coluna da esquerda
	const TB := 50.0                   # barra do registro
	var m := g.rules.market_for(g.n)
	var cols := m + 1
	var s_h := (H - TB - 18.0) / (88.0 + 6.0 + 3.0 * ROW_H)
	var s_w := (W - LW - 124.0) / (cols * COL_W + 380.0)   # os paineis podem ficar um pouco menores
	_s = clampf(minf(s_h, s_w), 0.8, 1.35)
	var mx := LW + 10.0
	var top_y := TB + 6.0
	var my := top_y + 88.0 * _s + 8.0
	var bank_x := mx + cols * COL_W * _s + 4.0
	_px = bank_x + 84.0
	var avail_w := W - _px - 8.0

	# coluna da esquerda: cronometros, Menu, acoes (espacadas por igual) e musica
	var left := ColorRect.new()
	left.color = Color(0, 0, 0, 0.28)
	left.size = Vector2(LW, H)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	_round_label = Label.new()
	_timer = TimerView.new()
	_timer.position = Vector2(10, 8)
	_timer.size = Vector2(LW - 20, 104)
	add_child(_timer)
	var menu := UITheme.button(L.t("Menu"), 22, Vector2(LW - 20, 56))
	menu.position = Vector2(10, 120)
	menu.pressed.connect(_show_pause)
	add_child(menu)
	_btn_take = UITheme.button(L.t("Take"), 24, Vector2(LW - 20, 84))
	_btn_take.pressed.connect(_on_take)
	_btn_buy = UITheme.button(L.t("Buy"), 24, Vector2(LW - 20, 84))
	_btn_buy.pressed.connect(_on_buy)
	_btn_reserve = UITheme.button(L.t("Reserve"), 24, Vector2(LW - 20, 84))
	_btn_reserve.pressed.connect(_on_reserve)
	_btn_clear = UITheme.button(L.t("Clear"), 24, Vector2(LW - 20, 84))
	_btn_clear.pressed.connect(_clear_selection.bind(true))
	_btn_pass = UITheme.button(L.t("Pass"), 24, Vector2(LW - 20, 84))
	_btn_pass.pressed.connect(_on_pass)
	var top_b := 196.0
	var bottom_b := H - 72.0
	var gap := maxf(8.0, (bottom_b - top_b - 4 * 84.0) / 3.0)
	var bh := minf(84.0, (bottom_b - top_b - 3 * gap) / 4.0)
	var order := [_btn_take, _btn_buy, _btn_reserve, _btn_clear]
	for i in range(4):
		var b: Button = order[i]
		b.position = Vector2(10, top_b + i * (bh + gap))
		b.size = Vector2(LW - 20, bh)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(b)
	# "Passar" so aparece quando nao ha jogada possivel: ocupa o lugar de "Pegar"
	_btn_pass.position = _btn_take.position
	_btn_pass.size = _btn_take.size
	_btn_pass.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_btn_pass)
	var player := MusicControls.new(42.0, 46.0)
	player.position = Vector2((LW - player.size.x) / 2.0, H - 56.0)
	add_child(player)
	_hint = Label.new()

	# registro: o que os adversarios fizeram desde a sua ultima jogada
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.35)
	top.position = Vector2(LW, 0)
	top.size = Vector2(W - LW, TB)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_log_label = UITheme.label("", 16, UITheme.TEXT)
	_log_label.position = Vector2(LW + 12, 2)
	_log_label.size = Vector2(W - LW - 24, TB - 4)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_log_label.max_lines_visible = 2
	_log_label.add_theme_constant_override("line_spacing", -2)
	add_child(_log_label)

	# filosofos e, logo depois deles, as fichas escolhidas
	_noble_box = Control.new()
	_noble_box.position = Vector2(mx, top_y)
	add_child(_noble_box)
	var tray_x := mx + minf(g.nobles.size() * 100.0 * _s, _px - mx - 200.0) + 8.0
	_noble_avail = tray_x - mx - 8.0
	_tray = Control.new()
	_tray.position = Vector2(tray_x, top_y + 6.0)
	_tray.size = Vector2(maxf(150.0, minf(250.0, _px - 8.0 - tray_x)), 88.0 * _s - 12.0)
	_tray.draw.connect(_draw_tray)
	_tray.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray.gui_input.connect(_on_tray_input)
	add_child(_tray)

	# mercado
	for lv in [3, 2, 1]:
		var y: float = my + (3 - lv) * ROW_H * _s
		var dv := CardView.new()
		dv.position = Vector2(mx, y)
		dv.src = "deck"
		dv.lv = lv
		_scale_card(dv)
		dv.pressed.connect(_on_card_pressed)
		add_child(dv)
		_deck_views[lv] = dv
		_market_views[lv] = []
		for sl in range(m):
			var cv := CardView.new()
			cv.position = Vector2(mx + (sl + 1) * COL_W * _s, y)
			cv.src = "m"
			cv.lv = lv
			cv.slot = sl
			_scale_card(cv)
			cv.pressed.connect(_on_card_pressed)
			add_child(cv)
			_market_views[lv].append(cv)

	# banco
	var step := minf(80.0, (H - my - 76.0) / 5.0)
	for c in range(6):
		var tv := TokenView.new()
		tv.position = Vector2(bank_x, my + c * step)
		tv.color_idx = c
		tv.pressed.connect(_on_token_pressed)
		add_child(tv)
		_token_views.append(tv)

	# reservas do jogador (embaixo, a direita, a 80%) e paineis (em cima)
	var res_h := CardView.BASE_SIZE.y * _s * RES_K
	var res_y := H - res_h - 8.0
	var rstep := (CardView.BASE_SIZE.x * RES_K + 10.0) * _s
	_reserve_title = UITheme.label("", 16, UITheme.MUTED)
	_reserve_title.position = Vector2(_px + 4, res_y - 26)
	add_child(_reserve_title)
	for i in range(3):
		var rv := CardView.new()
		rv.position = Vector2(_px + 4 + i * rstep, res_y)
		rv.src = "r"
		rv.slot = i
		_scale_card(rv, RES_K)
		rv.pressed.connect(_on_card_pressed)
		add_child(rv)
		_reserve_views.append(rv)
	var meta := UITheme.label("", 16, UITheme.MUTED)
	meta.name = "Meta"
	meta.position = Vector2(_px + 8 + 3 * rstep, res_y + 6)
	meta.size = Vector2(maxf(60.0, W - meta.position.x - 6), res_h)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# sem espaco, some (a meta e o limite ja aparecem nos paineis: "/15" e "x/10")
	meta.visible = meta.size.x >= 100.0
	add_child(meta)
	_build_gov_box(Vector2(meta.position.x - 2, res_y), Vector2(maxf(56.0, W - meta.position.x - 4), res_h))
	var ph_total := res_y - 32.0 - top_y
	var each := minf((ph_total - 6.0 * (g.n - 1)) / g.n, 118.0 * _s)
	_ps = clampf(minf(minf(_s, each / 84.0), avail_w / 448.0), 0.7, 1.35)
	_pw = avail_w / _ps
	for i in range(g.n):
		var pp := PlayerPanel.new()
		pp.g = g
		pp.idx = i
		pp.position = Vector2(_px, top_y + i * (each + 6.0))
		pp.size = Vector2(_pw, each / _ps)
		pp.scale = Vector2(_ps, _ps)
		pp.zone_tap.connect(_on_zone_tap)
		add_child(pp)
		_panels.append(pp)
	_build_fx()


func _build_gov_box(pos: Vector2, sz: Vector2) -> void:
	## Governantes em jogo: barras horizontais ao lado das reservas.
	_gov_views = []
	if g.gov_table.is_empty():
		return
	var meta := get_node_or_null("Meta")
	if meta != null:
		meta.visible = false
	_gov_box = Control.new()
	_gov_box.position = pos
	_gov_box.size = sz
	add_child(_gov_box)
	var k := g.gov_table.size()
	var bh := clampf((sz.y - 4.0 * (k - 1)) / k, 18.0, 34.0)
	for i in range(k):
		var gview := GovernorView.new()
		gview.position = Vector2(0, i * (bh + 4.0))
		gview.size = Vector2(sz.x, bh)
		gview.pressed.connect(_on_gov_pressed)
		if not UITheme.touch:
			gview.hover_changed.connect(func(v: GovernorView, on: bool):
				if on:
					_show_gov_info(v)
				elif _info_src == v:
					_hide_info())
		_gov_box.add_child(gview)
		_gov_views.append(gview)


func _scale_card(cv: CardView, k := 1.0) -> void:
	cv.base_scale = _s * k
	cv.pivot_offset = Vector2.ZERO
	cv.scale = Vector2(_s * k, _s * k)


func _notification(what: int) -> void:
	# botao "voltar" do Android: abre ou fecha a pausa
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and g != null:
		if _overlay_kind == "Pausa":
			_close_overlay()
		elif _overlay == null:
			_show_pause()


func _gui_input(event: InputEvent) -> void:
	# toque fora de tudo fecha as dicas abertas
	if event is InputEventMouseButton and event.pressed:
		_hide_info()
		_hide_peek()


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
	_timer.round_text = L.f("Round {n}", {"n": g.round_no})
	_timer.who = L.t("Game over.") if g.finished else (who + (L.t(" · last round!") if g.end_triggered else ""))
	_timer.queue_redraw()
	# nobres
	for v in _noble_views:
		v.queue_free()
	_noble_views = []
	# filosofos e escritores: pontos que dariam ao jogador observado agora
	_ns = minf(_s, _noble_avail / maxf(1.0, g.nobles.size() * 100.0))
	for i in range(g.nobles.size()):
		var id: int = g.nobles[i]
		var nv := NobleView.new()
		nv.position = Vector2(i * 100 * _ns, 0)
		nv.scale = Vector2(_ns, _ns)
		nv.setup(id, str(g.patron_pts(vp, id)), g.rules.writer_free if Defs.is_writer(id) else g.rules.noble_free,
			g.patron_distance(vp.bonus, id))
		if not UITheme.touch:
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
		_panels[i].queue_redraw()
	# governantes
	for i in range(_gov_views.size()):
		var gi: int = g.gov_table[i]
		var gv: Dictionary = g.governors[gi]
		var hn: String = g.players[g.gov_holder[gi]].name if g.gov_holder.has(gi) else ""
		_gov_views[i].setup(gi, gv, maxi(1, g.rules.base_target() + int(gv["target"])), hn,
			human and g.can_claim_governor(gi))
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
	meta.text = L.f("Goal {pts} pts · hand {n} tokens", {"pts": g.rules.base_target(), "n": g.rules.hand_limit})
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
	if UITheme.touch:
		_btn_take.visible = not _btn_pass.visible


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
			return L.f("Reserve the top card of the pile ({group}) face down (you gain 1 {gold}).", {"group": L.t(Defs.LEVEL_SHORT[sel_card["lv"]]), "gold": L.color(Defs.GOLD)})
		return L.t("Tap the card again to buy it quickly, or use the buttons.")
	return L.t("Take tokens, buy an element card (green seal = affordable) or reserve one.")


func _draw_tray() -> void:
	GemDraw.rounded(_tray, Rect2(Vector2.ZERO, _tray.size), Color(0, 0, 0, 0.3), 10, Color(1, 1, 1, 0.1), 1)
	if sel_tokens.is_empty():
		GemDraw.ctext(_tray, L.t("chosen tokens"), _tray.size / 2.0, 13, Color(1, 1, 1, 0.3))
		return
	for i in range(sel_tokens.size()):
		var r := minf(24.0 if not UITheme.touch else _tray.size.y / 2.0 - 6.0, (_tray.size.x - 44.0) / 6.0)
		GemDraw.draw_chip(_tray, sel_tokens[i], Vector2(r + 14 + i * (2 * r + 8), _tray.size.y / 2.0), r)


# ---------------------------------------------------------------------------
# Entrada do jogador
# ---------------------------------------------------------------------------
func _on_token_pressed(tv: TokenView) -> void:
	if not _human_turn() or tv.color_idx == Defs.GOLD:
		if tv.color_idx == Defs.GOLD and _human_turn():
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


func _note_action() -> void:
	## Guarda quanto tempo o humano levou para agir (estatisticas) e para o cronometro.
	if _act_start >= 0.0 and g != null:
		var e: Array = _act_times.get(g.current, [0.0, 0])
		e[0] += _game_secs - _act_start
		e[1] += 1
		_act_times[g.current] = e
	_act_start = -1.0
	_turn_left = -1.0


func _humans_count() -> int:
	var k := 0
	for p in g.players:
		if not p.is_ai():
			k += 1
	return k


func _process(delta: float) -> void:
	if g == null or not _alive:
		return
	var paused := _overlay_kind == "Pausa" or _overlay_kind == "Vez"
	if not g.finished and not paused:
		_game_secs += delta
		if _turn_left >= 0.0:
			_turn_left -= delta
			if _turn_left <= 0.0:
				_on_timeout()
	if _timer != null:
		_timer.game_secs = _game_secs
		_timer.left = _turn_left
		_timer.limit = _turn_limit
		_timer.queue_redraw()
	if _overlay_kind == "GovPick" and _overlay != null:
		var cdl := _overlay.find_child("Countdown", true, false)
		if cdl != null and _turn_left >= 0.0:
			cdl.text = L.f("{n} s", {"n": int(ceil(_turn_left))})


func _start_human_clock() -> void:
	## Comeca a contagem da vez do humano (se houver limite nas regras).
	_act_start = _game_secs
	_turn_limit = g.rules.turn_time(_humans_count())
	if g.phase == "escolha_gov":
		_turn_limit = RuleSet.GOV_PICK_SECONDS
	_turn_left = float(_turn_limit) if _turn_limit > 0 else -1.0


func _on_timeout() -> void:
	## Acabou o tempo: a vez passa sem acao (descarte e escolhas: o jogo decide).
	_turn_left = -1.0
	_note_action()
	_close_overlay()
	_clear_selection()
	var guard := 0
	while not g.finished and not g.cur().is_ai() and g.current == viewer and guard < 20:
		var before := g.turns_total
		g.timeout()
		guard += 1
		if g.turns_total != before:
			break
	Audio.play("error")
	_continue()


func _clear_selection(play_sound := false) -> void:
	sel_tokens = []
	sel_card = {}
	if play_sound:
		Audio.play("discard")
	if g != null:
		refresh()


func _on_take() -> void:
	_hide_info()
	_note_action()
	if g.act_take(sel_tokens):
		_clear_selection()
		_continue()
	else:
		Audio.play("error")


func _on_buy(joker := -2) -> void:
	_hide_info()
	var vp: GameState.PlayerState = g.players[viewer]
	var cid := -1
	if sel_card.get("src", "") == "m":
		cid = g.market[sel_card["lv"]][sel_card["slot"]]
	elif sel_card.get("src", "") == "r" and sel_card["idx"] < vp.reserved.size():
		cid = vp.reserved[sel_card["idx"]]
	if joker == -2 and cid >= 0 and g.cards[cid].kind == "joker":
		var cols := g.joker_colors(vp)
		if cols.size() > 1:
			_show_joker_choice(cols)
			return
		joker = cols[0] if not cols.is_empty() else -1
	joker = maxi(joker, -1)
	_note_action()
	var ok := false
	if sel_card.get("src", "") == "m":
		ok = g.act_buy_market(sel_card["lv"], sel_card["slot"], joker)
	elif sel_card.get("src", "") == "r":
		ok = g.act_buy_reserved(sel_card["idx"], joker)
	if ok:
		_clear_selection()
		_continue()
	else:
		Audio.play("error")


func _on_reserve() -> void:
	_hide_info()
	_note_action()
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
	_hide_info()
	_note_action()
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
		_start_human_clock()
		if g.phase != "acao":
			_show_phase()
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
			_log(L.f("{name} took {colors}.", {"name": pname, "colors": L.colors(e["colors"])}), pi)
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
				from = Rect2(_panel_point(panel, Vector2(_pw / 2.0, 20)) - CardView.BASE_SIZE / 2.0, CardView.BASE_SIZE)
			var bp: GameState.PlayerState = g.players[pi]
			var bc: int = g.spec_color_for(bp, e["card"], int(bp.joker.get(e["card"], -1)))
			if bc < 0:
				bc = cd.display_color()
			_fly_card(cd, from, _panel_point(panel, panel.bonus_pos(bc)), 1,
				func(): _land_card(panel, maxi(bc, 0)))
			var paid: Array = e["paid"]
			var k2 := 0
			for c in range(6):
				for j in range(paid[c]):
					var tv: TokenView = _token_views[c]
					_fly_chip(c, _panel_point(panel, panel.token_pos(c)), _center_of(tv), 0.25 + 0.06 * k2,
						func(): Audio.play("chip", 0.1, -12.0))
					k2 += 1
			_log(L.f("{name} bought a card ({group} · {color}){pts}.", {"name": pname, "group": L.t(Defs.LEVEL_SHORT[cd.level]),
				"color": _bonus_name(cd, bc), "pts": (" %+d" % cd.points) if cd.points != 0 else ""}), pi)
			Audio.play("buy", 0.04, -3.0)
			return 0.9
		"reserve":
			var cd2: Defs.CardDef = g.cards[e["card"]]
			var from2: Rect2 = _rect_of(_deck_views[e["lv"]]) if e["blind"] else _rect_of(_market_views[e["lv"]][e["slot"]])
			var to: Vector2 = _rect_of(_reserve_views[mini(g.players[pi].reserved.size() - 1, 2)]).get_center() if pi == viewer \
				else _panel_point(panel, Vector2(_pw / 2.0, 20))
			_fly_card(null if e["blind"] else cd2, from2, to, e["lv"], func(): panel.pulse("r"))
			if e["gold"]:
				_fly_chip(Defs.GOLD, _center_of(_token_views[Defs.GOLD]), _panel_point(panel, panel.token_pos(Defs.GOLD)), 0.3,
					func(): _land_token(panel, Defs.GOLD))
			if e["blind"]:
				_log(L.f("{name} reserved a face-down card ({group}).", {"name": pname, "group": L.t(Defs.LEVEL_SHORT[e["lv"]])}), pi)
			else:
				var rfmt := "{name} reserved a card ({group} · {color}){pts}."  # tr
				if not UITheme.touch:
					rfmt = "{name} reserved a card ({group} · {color}){pts}. Hover over their reserves to see it again."  # tr
				_log(L.f(rfmt, {"name": pname, "group": L.t(Defs.LEVEL_SHORT[cd2.level]), "color": _bonus_name(cd2, cd2.display_color()),
					"pts": (" %+d" % cd2.points) if cd2.points != 0 else ""}), pi)
			Audio.play("reserve", 0.04, -4.0)
			return 0.85
		"discard":
			var c3: int = e["color"]
			if e.has("to"):
				var tp: PlayerPanel = _panels[e["to"]]
				_fly_chip(c3, _panel_point(panel, panel.token_pos(c3)), _panel_point(tp, tp.token_pos(c3)), 0.0,
					func(): _land_token(tp, c3))
			else:
				_fly_chip(c3, _panel_point(panel, panel.token_pos(c3)), _center_of(_token_views[c3]), 0.0)
			Audio.play("discard", 0.06, -6.0)
			return 0.12
		"gain":
			for k in range(e["colors"].size()):
				var c4: int = e["colors"][k]
				_fly_chip(c4, _center_of(_token_views[c4]), _panel_point(panel, panel.token_pos(c4)), k * 0.09,
					func(): _land_token(panel, c4))
			_log(L.f("{name} gained {colors}.", {"name": pname, "colors": L.colors(e["colors"])}), pi)
			Audio.play("token", 0.06, -4.0)
			return 0.6
		"effect":
			if e["effect"] == "sphere":
				_fly_chip(Defs.GOLD, _center_of(_token_views[Defs.GOLD]), _panel_point(panel, panel.token_pos(Defs.GOLD)), 0.2,
					func(): _land_token(panel, Defs.GOLD))
				_log(L.f("{name} gained a sphere.", {"name": pname}), pi)
			return 0.4
		"extra_turn":
			_show_banner(L.f("{name} plays again!", {"name": pname}))
			_log(L.f("{name} plays again!", {"name": pname}), pi)
			Audio.play("turn")
			return 0.8
		"extra_round":
			_show_banner(L.t("One more round!"))
			_log(L.f("{name}: one more round!", {"name": pname}), pi)
			Audio.play("turn")
			return 1.0
		"governor":
			var gname := L.t(g.governors[e["gov"]]["name"])
			_show_banner(L.f("{name}: {gov} governs your academy!", {"name": pname, "gov": gname}))
			_log(L.f("{name} receives {gov}: goal {pts} points.", {"name": pname, "gov": gname,
				"pts": g.target_of(g.players[pi])}), pi)
			Audio.play("noble")
			return 1.0
		"gov_pick":
			_log(L.f("{name} chose {gov}.", {"name": pname, "gov": L.t(g.governors[e["gov"]]["name"])}), pi)
			return 0.3
		"noble_back":
			_log(L.f("{phil} returns to the table ({pts}).", {"phil": L.t(g.patron_name(e["noble"])), "pts": -int(e["pts"])}), pi)
			return 0.5
		"noble":
			var phil := L.t(g.patron_name(e["noble"]))
			_log(L.f("{name}: {phil} joins the academy (+{pts})!", {"name": pname, "phil": phil, "pts": e["pts"]}), pi)
			_show_banner(L.f("{name}: {phil} joins the academy (+{pts})!", {"name": pname, "phil": phil, "pts": e["pts"]}))
			for nv in _noble_views:
				if nv.noble == e["noble"]:
					var tw := create_tween().set_parallel()
					tw.tween_property(nv, "global_position", _panel_point(panel, Vector2(_pw - 120, 0)) + global_position, 0.6) \
						.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
					tw.tween_property(nv, "scale", Vector2(0.4, 0.4), 0.6)
			Audio.play("noble")
			return 0.9
		"color":
			_show_banner(L.f("{name}: {pts} points in {color}!", {"name": pname, "pts": e["pts"], "color": L.color(e["color"])}))
			_log(L.f("{name} achieved the specialization victory ({pts} points in {color}).", {"name": pname, "pts": e["pts"], "color": L.color(e["color"])}), pi)
			Audio.play("noble")
			return 1.0
		"last_round":
			_show_banner(L.t("Last round!"))
			if e.get("reason", "pontos") == "cor":
				_log(L.f("{name} reached the specialization victory: last round!", {"name": pname}), pi)
			else:
				_log(L.f("{name} reached {pts} points: last round!", {"name": pname, "pts": g.players[pi].points}), pi)
			Audio.play("turn")
			return 0.8
		"pass":
			_log(L.f("{name} passed.", {"name": pname}), pi)
			return 0.2
	return 0.0


func _bonus_name(cd: Defs.CardDef, c: int) -> String:
	match cd.kind:
		"none":
			return L.t("no bonus")
		"multi":
			var cols: Array = []
			for k in range(5):
				for j in range(cd.bonus_vec[k]):
					cols.append(k)
			return L.colors(cols)
	return L.color(c) if c >= 0 else L.t("joker")


func _log(s: String, pi := -1) -> void:
	if not UITheme.touch:
		_log_label.text = s
		return
	# modo toque: a barra lista o que os outros fizeram desde a sua ultima jogada
	if pi == viewer and not g.players[pi].is_ai():
		_recent.clear()
		_log_label.text = ""
		return
	_recent.append(s)
	_log_label.text = "   ·   ".join(_recent)
	# se nao couber em duas linhas, mostra as mais recentes
	while _recent.size() > 1 and _log_label.get_line_count() > 2:
		_recent.pop_front()
		_log_label.text = "   ·   ".join(_recent)


func _show_banner(s: String) -> void:
	_banner.text = s
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.1)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)


# --- geometria e efeitos -----------------------------------------------------
func _rect_of(c: Control) -> Rect2:
	## Retangulo na tela (ja com a escala do controle), em coordenadas desta mesa.
	var t := c.get_global_transform()
	return Rect2(get_global_transform().affine_inverse() * t.origin, c.size * t.get_scale())


func _center_of(c: Control) -> Vector2:
	return _rect_of(c).get_center()


func _panel_point(panel: PlayerPanel, local: Vector2) -> Vector2:
	if panel == null:
		return Vector2(_px, 60)
	return panel.position + local * panel.scale


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
	var start_scale := from.size.x / CardView.BASE_SIZE.x if from.size.x > 0 else 1.0
	var end_scale := 0.22
	var p2 := to_center - CardView.BASE_SIZE * end_scale / 2.0
	var p1 := (p0 + p2) / 2.0 + Vector2(0, -110)
	var dur := 0.7
	var step := func(t: float) -> void:
		var u := ease(t, -2.0)  # acelera e desacelera
		v.position = p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
		var sc := lerpf(start_scale, end_scale, ease(t, 1.6))
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
	if UITheme.touch:
		return
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
			if g.reserve_visible(panel.idx, cid, viewer):
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
			elif g.rules.see_reserves == "rodada":
				note = L.f("Visible until {name}'s next turn.", {"name": p.name})
		if note != "":
			v.add_child(UITheme.label(note, 12, UITheme.MUTED))
	elif zone == "governante":
		if p.governor >= 0:
			v.add_child(_gov_card(p.governor, "held"))
	else:
		v.add_child(UITheme.label(L.f("Academy: {name}", {"name": p.name}), 18, UITheme.GOLD))
		for k in range(p.nobles.size()):
			var id: int = p.nobles[k]
			var nv := NobleView.new()
			nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nv.setup(id, "+%d" % int(p.patron_pts.get(id, 0)), 0)
			h.add_child(nv)
		v.add_child(h)
		v.add_child(UITheme.label(L.f("{n} points from the academy", {"n": p.noble_points}), 15, UITheme.MUTED))
	add_child(box)
	_peek = box
	_peek_src = [panel, zone]
	await get_tree().process_frame
	if not is_instance_valid(box) or _peek != box:
		return
	var sz := box.get_combined_minimum_size()
	box.size = sz
	box.position = Vector2(_px - sz.x - 10, clampf(panel.position.y, 40, size.y - sz.y - 8))


# ---------------------------------------------------------------------------
# Dicas: o que falta para comprar uma carta, cartas no baralho, nobres
# ---------------------------------------------------------------------------
func _hide_info() -> void:
	if _info != null:
		_info.queue_free()
	_info = null
	_info_src = null


func _on_card_hover(cv: CardView, on: bool) -> void:
	if UITheme.touch:
		return
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


func _gem_row(counts: Array, prefix := "", big := 26) -> Control:
	## Linha de simbolos com numeros (so as cores com valor > 0), em letra grande.
	var cols: Array = []
	for c in range(counts.size()):
		if counts[c] > 0:
			cols.append(c)
	var step := big * 2.3
	var ctl := Control.new()
	ctl.custom_minimum_size = Vector2(maxi(1, cols.size()) * step, big * 1.3)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.draw.connect(func():
		for i in range(cols.size()):
			var c: int = cols[i]
			var center := Vector2(big * 0.55 + i * step, big * 0.65)
			GemDraw.draw_gem(ctl, c, center, big * 0.48)
			GemDraw.text(ctl, prefix + str(counts[c]), center + Vector2(big * 0.62, big * 0.36), big, Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 3))
	return ctl


func _info_box(anchor: Control, lines: Array) -> void:
	## Dica curta: lines sao Strings, [texto, cor] ou Controls. A primeira linha e o titulo.
	_hide_info()
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 20
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	var first := true
	for it in lines:
		if it is Control:
			v.add_child(it)
		else:
			var txt: String = it if it is String else it[0]
			var col: Color = (UITheme.GOLD if first else UITheme.TEXT) if it is String else it[1]
			var l := UITheme.label(txt, 26 if first else 21, col)
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
	if x + sz.x > size.x - 10.0:
		x = r.position.x - sz.x - 10.0
	box.position = Vector2(clampf(x, 4.0, size.x - 4.0 - sz.x), clampf(r.position.y, 40.0, size.y - 4.0 - sz.y))


func _show_card_info(cv: CardView) -> void:
	var vp: GameState.PlayerState = g.players[viewer]
	if cv.src == "deck":
		var lv := cv.lv
		_info_box(cv, [L.t(Defs.LEVEL_NAMES[lv]), L.f("{n} cards in the deck", {"n": g.decks[lv].size()})])
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
	var gold: int = vp.tokens[Defs.GOLD] - cd.cost[5]
	var lines: Array = []
	if short == 0 and gold >= 0:
		lines.append([L.t("You can buy it"), Color(0.55, 0.9, 0.6)])
		lines.append(L.t("without using spheres") if cd.cost[5] == 0 else L.f("paying {n} spheres", {"n": cd.cost[5]}))
	else:
		lines.append(L.f("{n} missing", {"n": short + maxi(0, -gold)}))
		if cd.cost[5] > 0:
			need.append(maxi(0, -gold))
		lines.append(_gem_row(need))
		if gold > 0 and short > 0:
			lines.append(L.f("With {g} spheres: you can buy it", {"g": gold}) if short <= gold
				else L.f("With {g} spheres: {n} missing", {"g": gold, "n": short - gold}))
	if cd.cost[5] > 0:
		lines.append([L.f("Costs {n} spheres (only spheres pay this part)", {"n": cd.cost[5]}), UITheme.MUTED])
	match cd.kind:
		"none":
			lines.append([L.t("No bonus: it gives points, but no discount"), UITheme.MUTED])
		"multi":
			lines.append([L.t("Bonus of several elements"), UITheme.MUTED])
		"joker":
			lines.append([L.t("Joker: when you buy it, choose the element of one of your cards"), UITheme.MUTED])
	if cd.effect != "":
		lines.append([L.t(EFFECT_INFO[cd.effect]), UITheme.GOLD])
	var sc := g.spec_color_for(vp, cid)
	var cw := g.spec_threshold(vp)
	if cw > 0 and cd.points > 0 and sc >= 0:
		lines.append([L.f("{color}: {a} → {b} of {cw}", {"color": L.color(sc), "a": vp.color_pts[sc],
			"b": vp.color_pts[sc] + cd.points, "cw": cw}), UITheme.MUTED])
	_info_box(cv, lines)


func _show_noble_info(nv: NobleView) -> void:
	if nv.noble < 0:
		return
	var vp: GameState.PlayerState = g.players[viewer]
	var id := nv.noble
	var lines: Array = [L.f("{name} · {n} points", {"name": L.t(g.patron_name(id)), "n": g.patron_pts(vp, id)})]
	var d := g.patron_distance(vp.bonus, id)
	if d == 0:
		lines.append([L.t("Already met: arrives at the end of your turn"), Color(0.55, 0.9, 0.6)])
	else:
		lines.append(L.f("{n} more cards", {"n": d}))
		var req: Array = g.patron_req(id)
		var miss := [0, 0, 0, 0, 0]
		for c in range(5):
			miss[c] = maxi(0, req[c] - vp.bonus[c])
		lines.append(_gem_row(miss))
	var free_n: int = g.rules.writer_free if Defs.is_writer(id) else g.rules.noble_free
	if free_n > 0:
		lines.append([L.f("−{n} any", {"n": free_n}), UITheme.MUTED])
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
	var v := _open_overlay(L.f("Turn: {name}", {"name": nm}), "Vez")
	v.add_child(UITheme.label(L.f("Pass the device to {name}.", {"name": nm}), 18))
	var b := UITheme.button(L.f("I'm {name}, start", {"name": nm}), 20, Vector2(320, 54))
	v.add_child(b)
	await b.pressed
	_close_overlay()


func _show_discard() -> void:
	var p := g.cur()
	var over_limit := g.discard_to == g.rules.hand_limit
	var v := _open_overlay(L.f("Limit of {n} tokens", {"n": g.rules.hand_limit}) if over_limit else L.t("Return tokens"))
	var info := UITheme.label("", 18)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var views: Array = []
	var upd := func():
		info.text = L.f("You have {n} tokens. Tap to return {k}.", {"n": p.token_count(), "k": p.token_count() - g.discard_to})
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
					_after_choice()
				else:
					upd.call()
					refresh())
		h.add_child(tv)
		views.append(tv)
	upd.call()


func _show_noble_choice() -> void:
	var writers: bool = Defs.is_writer(g.noble_options[0])
	var v := _open_overlay(L.t("Choose a writer") if writers else L.t("Choose a philosopher"))
	v.add_child(UITheme.label(L.t("You meet the requirements of more than one writer.") if writers
		else L.t("You meet the requirements of more than one philosopher."), 18))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 22)
	v.add_child(h)
	for nb in g.noble_options:
		var nv := NobleView.new()
		nv.setup(nb, "+%d" % g.patron_pts(g.cur(), nb), g.rules.writer_free if writers else g.rules.noble_free)
		nv.custom_minimum_size = Vector2(141, 132)
		nv.size = nv.custom_minimum_size
		nv.selectable = true
		nv.pressed.connect(func(x: NobleView):
			if g.choose_noble(x.noble):
				_close_overlay()
				_after_choice())
		h.add_child(nv)


func _show_phase() -> void:
	## Abre a janela da decisao que o jogo esta esperando do jogador da vez.
	match g.phase:
		"descarte":
			_show_discard()
		"nobre":
			_show_noble_choice()
		"ganho":
			_show_gain()
		"governante":
			_show_governor_offer(g.gov_options, false)
		"cega":
			_show_blind_choice()
		"escolha_gov":
			_show_gov_pick()


func _after_choice() -> void:
	## Depois de uma escolha numa janela: outra decisao do mesmo jogador, ou segue o jogo.
	refresh()
	if g.phase in WAIT_PHASES and not g.cur().is_ai() and g.current == viewer:
		_show_phase()
		return
	if g.phase != "escolha_gov":
		_note_action()
	_continue()


func _show_gain() -> void:
	_gain_sel = []
	var v := _open_overlay(L.f("Take {n} tokens", {"n": g.gain_n}) if g.gain_n > 1 else L.t("Take 1 token"))
	v.add_child(UITheme.label(L.t("Choose tokens of different elements from the piles."), 18))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var ok := UITheme.button(L.t("Take"), 20, Vector2(200, 52))
	var views: Array = []
	var upd := func():
		for tv in views:
			tv.setup(tv.color_idx, g.bank[tv.color_idx], 1 if _gain_sel.has(tv.color_idx) else 0, g.bank[tv.color_idx] > 0)
		ok.disabled = _gain_sel.is_empty()
	for c in range(5):
		var tv := TokenView.new()
		tv.color_idx = c
		tv.pressed.connect(func(x: TokenView):
			if _gain_sel.has(x.color_idx):
				_gain_sel.erase(x.color_idx)
			elif _gain_sel.size() < g.gain_n and g.bank[x.color_idx] > 0:
				_gain_sel.append(x.color_idx)
			else:
				Audio.play("error")
				return
			Audio.play("select")
			upd.call())
		h.add_child(tv)
		views.append(tv)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	ok.pressed.connect(func():
		if g.gain(_gain_sel.duplicate()):
			_close_overlay()
			_after_choice())
	row.add_child(ok)
	var skip := UITheme.button(L.t("Skip"), 18, Vector2(160, 52))
	skip.pressed.connect(func():
		if g.gain([]):
			_close_overlay()
			_after_choice())
	row.add_child(skip)
	v.add_child(row)
	upd.call()


func _gov_card(gi: int, state := "", width := 300.0) -> Control:
	## Cartao de um governante: nome, titulo, condicao, custo, vantagem e meta.
	var gv: Dictionary = g.governors[gi]
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	var sb := UITheme.box(Color(GovernorView.GROUP_COLORS.get(gv["group"], Color(0.4, 0.35, 0.3)).darkened(0.62), 0.97),
		UITheme.GOLD if state in ["", "offer"] else Color(1, 1, 1, 0.2), 2)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var nm := UITheme.label(L.t(gv["name"]), 22, UITheme.GOLD)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	if str(gv["title"]) != "":
		v.add_child(UITheme.label(L.t(gv["title"]), 14, UITheme.MUTED))
	var lines: Array = [[L.t("Condition") + ": " + Governors.cond_text(gv), UITheme.TEXT]]
	if gv["cost"] != "none":
		lines.append([L.t("Cost") + ": " + Governors.cost_text(gv), Color(1.0, 0.6, 0.5)])
	if gv["adv"] != "none":
		lines.append([L.t("Advantage") + ": " + Governors.adv_text(gv), Color(0.6, 0.9, 0.65)])
	lines.append([Governors.target_text(gv, g.rules.base_target()), UITheme.GOLD])
	for ln in lines:
		var l := UITheme.label(ln[0], 16, ln[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width - 24, 0)
		v.add_child(l)
	if state == "taken" or state == "held":
		var who := ""
		for q in g.players:
			if q.gov_choice == gi and state == "taken":
				who = q.name
		if g.gov_holder.has(gi):
			who = g.players[g.gov_holder[gi]].name
			v.add_child(UITheme.label(L.f("Governs {name}'s academy", {"name": who}), 14, UITheme.MUTED))
		elif who != "":
			v.add_child(UITheme.label(L.f("Chosen by {name}", {"name": who}), 14, UITheme.MUTED))
	return p


func _show_gov_info(view: GovernorView) -> void:
	var gi := view.gi
	var lines: Array = [_gov_card(gi, "held", 320.0)]
	if not g.gov_holder.has(gi):
		var chooser := ""
		for q in g.players:
			if q.gov_choice == gi:
				chooser = q.name
		if chooser != "":
			lines.append([L.f("Chosen by {name} · anyone who meets the condition first may receive it", {"name": chooser}), UITheme.MUTED])
		if _human_turn() and g.can_claim_governor(gi):
			lines.append([L.t("Tap to receive it now"), Color(0.55, 0.9, 0.6)])
	_info_box(view, lines)


func _on_gov_pressed(view: GovernorView) -> void:
	if _human_turn() and g.can_claim_governor(view.gi):
		_hide_info()
		_show_governor_offer([view.gi], true)
		return
	if _info_src == view:
		_hide_info()
	else:
		_show_gov_info(view)


func _show_governor_offer(opts: Array, manual: bool) -> void:
	var v := _open_overlay(L.t("A governor for your academy?"))
	var sub := UITheme.label(L.t("You meet the condition. Receiving one is optional; you can only have one governor."), 17)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(minf(760.0, size.x - 120.0), 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	for gi in opts:
		var col := VBoxContainer.new()
		col.add_child(_gov_card(gi, "offer", 300.0))
		var b := UITheme.button(L.t("Receive"), 20, Vector2(300, 52))
		var gidx: int = gi
		b.pressed.connect(func():
			var ok: bool = g.claim_governor_now(gidx) if manual else g.choose_governor(gidx)
			if ok:
				_close_overlay()
				if manual:
					refresh()
					_drain_events()
					if g.phase in WAIT_PHASES:
						_show_phase()
				else:
					_after_choice())
		col.add_child(b)
		h.add_child(col)
	var no := UITheme.button(L.t("Not now") if manual else L.t("Refuse"), 18, Vector2(220, 48))
	no.pressed.connect(func():
		_close_overlay()
		if not manual and g.choose_governor(-1):
			_after_choice())
	v.add_child(no)
	if not manual:
		v.add_child(UITheme.label(L.t("A refused governor can still be received later: tap it on the table."), 14, UITheme.MUTED))


func _show_blind_choice() -> void:
	var v := _open_overlay(L.t("Choose the card to reserve"))
	v.add_child(UITheme.label(L.t("The others go back to the top of the pile."), 17))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	for cid in g.blind_options:
		var cv := CardView.new()
		cv.set_card(g.cards[cid], g.rules.deck)
		var c: int = cid
		cv.pressed.connect(func(_x):
			if g.choose_blind(c):
				_close_overlay()
				_after_choice())
		h.add_child(cv)


func _show_joker_choice(cols: Array) -> void:
	var v := _open_overlay(L.t("Joker: which element?"))
	v.add_child(UITheme.label(L.t("The card counts as one more card of the element you choose."), 17))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	for c in cols:
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 110)
		b.focus_mode = Control.FOCUS_NONE
		var cc: int = c
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(110, 110)
		icon.draw.connect(func():
			GemDraw.draw_gem(icon, cc, Vector2(55, 46), 26)
			GemDraw.ctext(icon, L.color(cc), Vector2(55, 92), 16, UITheme.TEXT))
		b.add_child(icon)
		b.pressed.connect(func():
			_close_overlay()
			_on_buy(cc))
		h.add_child(b)
	var cancel := UITheme.button(L.t("Cancel"), 18, Vector2(180, 46))
	cancel.pressed.connect(_close_overlay)
	v.add_child(cancel)


func _show_gov_pick() -> void:
	var p := g.cur()
	var v := _open_overlay(L.f("{name}, choose your governor", {"name": p.name}), "GovPick")
	var sub := UITheme.label(L.t("Your choice goes to the table. Whoever meets its condition first may receive it."), 16, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(minf(1180.0, size.x - 60.0), minf(470.0, size.y - 230.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	sc.add_child(body)
	var avail := g.gov_available()
	var cw := (sc.custom_minimum_size.x - 40.0) / 3.0
	for grp in Governors.GROUPS:
		var items: Array = []
		for i in range(g.governors.size()):
			if g.governors[i]["group"] == grp:
				items.append(i)
		if items.is_empty():
			continue
		body.add_child(UITheme.label(L.t(Governors.GROUP_NAMES[grp]), 18, UITheme.GOLD))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		body.add_child(grid)
		for gi in items:
			var free: bool = avail.has(gi)
			var card := _gov_card(gi, "" if free else "taken", cw)
			if not free:
				card.modulate = Color(1, 1, 1, 0.45)
			else:
				card.mouse_filter = Control.MOUSE_FILTER_STOP
				var gidx: int = gi
				card.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						if g.pick_governor(gidx):
							Audio.play("select")
							_close_overlay()
							_after_choice())
			grid.add_child(card)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var rnd := UITheme.button(L.t("Choose at random"), 20, Vector2(280, 52))
	rnd.pressed.connect(func():
		if g.pick_governor(-1):
			_close_overlay()
			_after_choice())
	row.add_child(rnd)
	var cd := UITheme.label("", 18, UITheme.MUTED)
	cd.name = "Countdown"
	row.add_child(cd)
	v.add_child(row)


func _show_pause() -> void:
	if _overlay != null:
		return
	var v := _open_overlay(L.t("Pause"), "Pausa")
	var cont := UITheme.button(L.t("Continue"), 22, Vector2(420, 56))
	cont.pressed.connect(_close_overlay)
	v.add_child(cont)
	# idioma: troca na hora e volta para a partida ja traduzida
	var lang_cap := L.t("Language") if L.code == "en" else L.t("Language") + " · Language"
	var lb := UITheme.button("%s: %s" % [lang_cap, L.LANGS[L.index()][1]], 20, Vector2(420, 52))
	lb.pressed.connect(_show_languages)
	v.add_child(lb)
	var speed := HBoxContainer.new()
	speed.add_child(UITheme.label(L.t("AI speed"), 16, UITheme.MUTED))
	var so := UITheme.option([L.t("Slow"), L.t("Normal"), L.t("Fast")], [1.1, 0.6, 0.2].find(ai_delay) if [1.1, 0.6, 0.2].has(ai_delay) else 1)
	so.item_selected.connect(func(i):
		ai_delay = [1.1, 0.6, 0.2][i]
		Store.set_value("game", "ai_delay", ai_delay))
	speed.add_child(so)
	v.add_child(speed)
	var ts := HBoxContainer.new()
	ts.add_child(UITheme.label(L.t("Text size"), 16, UITheme.MUTED))
	var tso := UITheme.option(UITheme.TEXT_SIZES.map(func(x): return L.t(x)), clampi(int(Store.get_value("geral", "texto", 0)), 0, 2))
	tso.item_selected.connect(func(i):
		Store.set_value("geral", "texto", i)
		var n := get_parent()
		while n != null and not n.has_method("refresh_theme"):
			n = n.get_parent()
		if n != null:
			n.refresh_theme()
		_rebuild()
		_show_pause())
	ts.add_child(tso)
	v.add_child(ts)
	var vs := HBoxContainer.new()
	vs.add_child(UITheme.label(L.t("Visual"), 16, UITheme.MUTED))
	var vso := UITheme.option(Defs.VISUAL_NAMES.map(func(x): return L.t(x)), maxi(0, Defs.VISUALS.find(Defs.visual)))
	vso.item_selected.connect(func(i):
		Defs.set_visual(Defs.VISUALS[i])
		Store.set_value("visual", "tema", Defs.VISUALS[i])
		_rebuild()
		_show_pause())
	vs.add_child(vso)
	v.add_child(vs)
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


func _show_languages() -> void:
	_close_overlay()
	var v := _open_overlay(L.t("Language") if L.code == "en" else L.t("Language") + " · Language", "Pausa")
	var grid := GridContainer.new()
	grid.columns = 4 if size.x >= 1200 else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for i in range(L.LANGS.size()):
		var b := UITheme.button(L.LANGS[i][1], 18, Vector2(240, 40))
		if i == L.index():
			b.add_theme_color_override("font_color", UITheme.GOLD)
		var code: String = L.LANGS[i][0]
		b.pressed.connect(func():
			L.set_lang(code)
			Store.set_value("geral", "idioma", code)
			_rebuild())
		grid.add_child(b)
	var back := UITheme.button(L.t("Back"), 18, Vector2(240, 44))
	back.pressed.connect(func():
		_close_overlay()
		_show_pause())
	v.add_child(back)


func _rebuild() -> void:
	## Remonta a mesa (ex.: depois de trocar o idioma), mantendo a partida.
	_close_overlay()
	_hide_info()
	_hide_peek()
	for ch in get_children():
		ch.queue_free()
	_market_views = [[], [], [], []]
	_deck_views = [null, null, null, null]
	_token_views = []
	_panels = []
	_reserve_views = []
	_noble_views = []
	_recent = []
	_build()
	refresh()
	if g.finished:
		_show_game_over()
	elif not g.cur().is_ai() and g.current == viewer and g.phase != "acao":
		_show_phase()


func _show_game_over() -> void:
	if not _recorded and _humans_count() > 0:
		_recorded = true
		Stats.record_game(g, _game_secs, _act_times)
	var w := g.winners()
	var title := L.f("{name} wins!", {"name": g.players[w[0]].name}) if w.size() == 1 else L.t("Draw!")
	Audio.play("win")
	var v := _open_overlay(title, "Fim")
	var grid := GridContainer.new()
	var wr := g.rules.uses_writers()
	var gov := not g.gov_table.is_empty()
	grid.columns = 5 + (1 if wr else 0) + (1 if gov else 0)
	grid.add_theme_constant_override("h_separation", 22)
	v.add_child(grid)
	var heads := ["", L.t("Player"), L.t("Points"), L.t("Cards"), L.t("Philosophers")]
	if wr:
		heads.append(L.t("Writers"))
	if gov:
		heads.append(L.t("Governor"))
	for hd in heads:
		grid.add_child(UITheme.label(hd, 16, UITheme.MUTED))
	var pos := 1
	for i in g.ranking():
		var p: GameState.PlayerState = g.players[i]
		var col := UITheme.GOLD if w.has(i) else UITheme.TEXT
		grid.add_child(UITheme.label("%d." % pos, 18, col))
		grid.add_child(UITheme.label(p.name, 18, col))
		grid.add_child(UITheme.label(str(p.points), 18, col))
		grid.add_child(UITheme.label(str(p.cards), 18, col))
		var nphil := GameState.philosopher_count(p)
		grid.add_child(UITheme.label(str(nphil), 18, col))
		if wr:
			grid.add_child(UITheme.label(str(p.nobles.size() - nphil), 18, col))
		if gov:
			grid.add_child(UITheme.label(("%s (%d)" % [L.t(g.governors[p.governor]["name"]), g.target_of(p)])
				if p.governor >= 0 else "—", 18, col))
		pos += 1
	var wp: GameState.PlayerState = g.players[w[0]]
	if g.meets_color(wp):
		var bc := g.best_color(wp)
		v.add_child(UITheme.label(L.f("Specialization victory: {pts} points in {color} cards", {"pts": wp.color_pts[bc], "color": L.color(bc)}), 16, UITheme.GOLD))
	v.add_child(UITheme.label(L.f("{n} rounds · {t} · ties are broken by fewer cards bought",
		{"n": g.round_no, "t": TimerView.clock(_game_secs)}), 15, UITheme.MUTED))
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
