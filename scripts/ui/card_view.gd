class_name CardView
extends Control
## Carta de desenvolvimento desenhada em codigo. Se existir uma imagem em
## res://assets/cards/<pasta do deck>/<chave>.png ela e usada como arte de fundo
## (pastas: pentakosmos e arcaico; lista em assets/cards/CARD_LIST.csv).

signal pressed(view: CardView)
signal hover_changed(view: CardView, on: bool)

const BASE_SIZE := Vector2(112, 154)
## false = quando houver arte em PNG, mostra so a imagem (sem faixa, pontos e custos)
const DRAW_INFO_OVER_ART := true
# verso: ceu escuro com uma estrela; basicas = laranja pequena, intermediarias = branco-amarelada,
# avancadas = azul-branca e grande (cores tambem usadas nas minicartas ocultas dos paineis)
const BACK_COLORS := [Color(0, 0, 0), Color(1.0, 0.62, 0.30), Color(1.0, 0.93, 0.72), Color(0.62, 0.74, 1.0)]
const STAR_CORE := [Color(0, 0, 0), Color(1.0, 0.70, 0.40), Color(1.0, 0.97, 0.86), Color(0.72, 0.82, 1.0)]
const STAR_R := [0.0, 9.0, 14.0, 22.0]
static var _dust: Array = []

var card: Defs.CardDef = null
var deck_name := "arcaico"
var back_level := 0         # > 0 desenha o verso (baralho ou reserva oculta)
var back_count := -1        # cartas restantes no baralho (-1 = nao mostra)
var selected := false
var affordable := false
var dimmed := false
var interactive := true
# contexto para a UI (origem da carta)
var src := ""               # "m", "r", "deck"
var lv := 0
var slot := -1

var _t := 0.0
var _hover := false
var base_scale := 1.0     # escala da carta na mesa (maior no modo toque)
var _tex: Texture2D = null
var _back_tex: Texture2D = null
static var _tex_cache := {}


func _init() -> void:
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = BASE_SIZE / 2.0


func _ready() -> void:
	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func(): _set_hover(false))
	resized.connect(func(): pivot_offset = size / 2.0)


func set_card(c: Defs.CardDef, p_deck: String) -> void:
	card = c
	deck_name = p_deck
	back_level = 0
	_tex = _load_tex("res://assets/cards/%s/%s.png" % [Defs.DECK_DIRS.get(deck_name, deck_name), c.key]) if c != null else null
	queue_redraw()


func set_back(level: int, count: int, p_deck: String) -> void:
	card = null
	back_level = level
	back_count = count
	deck_name = p_deck
	_back_tex = _load_tex("res://assets/cards/%s/back_l%d.png" % [Defs.DECK_DIRS.get(deck_name, deck_name), level])
	queue_redraw()


func set_empty() -> void:
	card = null
	back_level = 0
	queue_redraw()


static func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[path] = t
	return t


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _set_hover(v: bool) -> void:
	# no toque o "mouse" fica parado onde o dedo tocou: sem efeito de passar por cima
	if UITheme.touch:
		return
	_hover = v
	hover_changed.emit(self, v)
	if not interactive or (card == null and back_level == 0):
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * base_scale * (1.05 if v else 1.0), 0.12)
	z_index = 5 if v else 0


func _process(delta: float) -> void:
	if selected:
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card != null or back_level > 0:
			pressed.emit(self)
			accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if card == null and back_level == 0:
		GemDraw.rounded(self, r, Color(1, 1, 1, 0.03), 12, Color(1, 1, 1, 0.12), 2)
		return
	if selected:
		GemDraw.glow(self, r, Color(1.0, 0.85, 0.35), 0.75 + 0.25 * sin(_t * 5.0), 12)
	# sombra
	GemDraw.rounded(self, Rect2(Vector2(3, 5), size), Color(0, 0, 0, 0.45), 12)
	if card == null:
		_draw_back(r)
	else:
		_draw_face(r)
	if dimmed:
		GemDraw.rounded(self, r, Color(0, 0, 0, 0.45), 12)


func _draw_back(r: Rect2) -> void:
	if _back_tex != null:
		draw_texture_rect(_back_tex, r, false)
	else:
		var glow: Color = BACK_COLORS[back_level]
		GemDraw.rounded(self, r, Color(0.035, 0.04, 0.07), 12, Color(glow, 0.6), 2)
		if _dust.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in range(46):
				_dust.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.4, 1.2), rng.randf_range(0.25, 0.8)])
		for d in _dust:
			draw_circle(Vector2(8, 8) + d[0] * (r.size - Vector2(16, 16)), d[1], Color(1, 1, 1, d[2] * 0.55))
		var c := Vector2(r.size.x / 2.0, r.size.y * 0.48)
		var rad: float = STAR_R[back_level]
		for k in range(12, 0, -1):
			var f := k / 12.0
			draw_circle(c, rad * (1.0 + 2.4 * f), Color(glow, 0.05 * (1.0 - f) + 0.012))
		var core: Color = STAR_CORE[back_level]
		draw_circle(c, rad, core)
		draw_circle(c + Vector2(-0.25, -0.3) * rad, rad * 0.55, core.lightened(0.35))
		draw_circle(c + Vector2(-0.3, -0.35) * rad, rad * 0.25, Color(1, 1, 1, 0.55))
		# orbita com 1, 2 ou 3 planetas
		var rx := r.size.x * 0.40
		var ry := rx * 0.32
		var pts := PackedVector2Array()
		for k in range(49):
			var ang := TAU * k / 48.0
			pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
		draw_polyline(pts, Color(0.93, 0.76, 0.40, 0.35), 1.2, true)
		for k in range(back_level):
			var ang := 0.6 + k * TAU / back_level
			draw_circle(c + Vector2(cos(ang) * rx, sin(ang) * ry), 3.0, Color(0.93, 0.76, 0.40))
	# grupo (Basicas, Intermediarias, Avancadas)
	var word := L.t(Defs.LEVEL_SHORT[back_level])
	var fs := 15
	while fs > 9 and ThemeDB.fallback_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 12:
		fs -= 1
	GemDraw.ctext(self, word, Vector2(r.size.x / 2, 20), fs, Color(0.93, 0.76, 0.40), 3)
	if back_count >= 0:
		GemDraw.ctext(self, str(back_count), Vector2(r.size.x / 2, r.size.y - 20), 20, Color(1, 1, 1, 0.95), 4)


func _draw_face(r: Rect2) -> void:
	var dc := card.display_color()
	var bc: Color = Defs.COLORS[dc] if dc >= 0 else (Color(0.62, 0.55, 0.40) if card.kind == "joker" else Color(0.42, 0.43, 0.48))
	var ink: Color = Defs.INK[dc] if dc >= 0 else Color(1, 1, 1)
	var border := Color(0.25, 0.9, 0.45) if affordable else bc.lightened(0.15)
	if dc == 4 and not affordable:
		border = Color(0.6, 0.6, 0.65)
	# corpo
	GemDraw.rounded(self, r, Color(0.11, 0.12, 0.16), 12, border, 3 if affordable else 2)
	if _tex != null:
		draw_texture_rect(_tex, r.grow(-3), false)
		if not DRAW_INFO_OVER_ART:
			return
	else:
		# fundo: degrade suave da cor do bonus
		var steps := 10
		for i in range(steps):
			var y0 := 46.0 + (r.size.y - 52.0) * i / steps
			var h := (r.size.y - 52.0) / steps + 1.0
			var c := bc.darkened(0.55 + 0.03 * i)
			c.a = 0.55
			draw_rect(Rect2(4, y0, r.size.x - 8, h), c)
		# reflexo diagonal
		draw_colored_polygon(PackedVector2Array([Vector2(r.size.x * 0.55, 48), Vector2(r.size.x - 5, 48),
			Vector2(r.size.x - 5, 90)]), Color(1, 1, 1, 0.05))
	# faixa superior
	var band := Rect2(3, 3, r.size.x - 6, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bc if _tex == null else Color(bc, 0.85)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.anti_aliasing = true
	draw_style_box(sb, band)
	draw_rect(Rect2(3, 42, r.size.x - 6, 3), bc.darkened(0.35))
	# pontos
	if card.points > 0:
		GemDraw.text(self, str(card.points), Vector2(10, 36), 32, ink, HORIZONTAL_ALIGNMENT_LEFT, -1,
			3 if dc != 0 else 0, Color(0, 0, 0, 0.5))
	elif card.points < 0:
		GemDraw.text(self, "−%d" % -card.points, Vector2(8, 34), 26, Color(1.0, 0.55, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1,
			4, Color(0, 0, 0, 0.8))
	# bonus: um solido, varios, nenhum ou coringa
	var gc := Vector2(r.size.x - 24, 24)
	if Defs.visual == "solidos" or card.kind != "single":
		draw_circle(gc, 17, Color(0.07, 0.08, 0.11, 0.85))
	match card.kind:
		"single":
			GemDraw.draw_gem(self, card.bonus, gc, 15)
		"none":
			draw_arc(gc, 11, 0, TAU, 24, Color(1, 1, 1, 0.45), 2.0, true)
			draw_line(gc + Vector2(-7, 7), gc + Vector2(7, -7), Color(1, 1, 1, 0.45), 2.0, true)
		"joker":
			for c in range(5):
				var a0 := -PI / 2.0 + c * TAU / 5.0
				draw_arc(gc, 12, a0 + 0.08, a0 + TAU / 5.0 - 0.08, 8, Defs.COLORS[c].lightened(0.2), 4.0, true)
			GemDraw.ctext(self, "?", gc, 15, Color(1, 1, 1, 0.95), 3)
		"multi":
			var gems: Array = []
			for c in range(5):
				for k in range(card.bonus_vec[c]):
					gems.append(c)
			for i in range(gems.size()):
				var ang := -PI / 2.0 + i * TAU / gems.size()
				GemDraw.draw_gem(self, gems[i], gc + Vector2(cos(ang), sin(ang)) * 8.0, 7)
	# efeito ao comprar
	if card.effect != "":
		var ec := Vector2(r.size.x - 17, 62)
		draw_circle(ec, 12, Color(0.10, 0.10, 0.14, 0.92))
		draw_arc(ec, 12, 0, TAU, 24, Color(0.93, 0.76, 0.40), 1.5, true)
		match card.effect:
			"token":
				GemDraw.ctext(self, "+1", ec, 13, Color(1, 1, 1), 2)
			"two_tokens":
				GemDraw.ctext(self, "+2", ec, 13, Color(1, 1, 1), 2)
			"sphere":
				GemDraw.draw_gem(self, Defs.GOLD, ec, 8)
			"extra_turn":
				draw_arc(ec, 6.5, 0.4, TAU - 0.5, 16, Color(1, 1, 1), 2.0, true)
				draw_colored_polygon(PackedVector2Array([ec + Vector2(6.0, -4.0), ec + Vector2(9.5, 2.0),
					ec + Vector2(2.5, 1.5)]), Color(1, 1, 1))
	# custos embaixo, na ordem fixa (ar, agua, eter, fogo, terra): 1 coluna ate 2 cores,
	# 2 colunas com 3 ou 4 cores (a primeira coluna enche primeiro)
	var cols: Array = []
	for c in range(6):
		if card.cost[c] > 0:
			cols.append(c)
	var ncol := 1 if cols.size() <= 2 else 2
	var rows := int(ceil(cols.size() / float(ncol)))
	var rowh := 29.0
	var y0 := r.size.y - 9.0 - rows * rowh + rowh / 2.0
	for i in range(cols.size()):
		var ci := 0 if (ncol == 1 or i < rows) else 1
		var ri := i if ci == 0 else i - rows
		var c: int = cols[i]
		var center := Vector2(17 + ci * 52, y0 + ri * rowh)
		GemDraw.draw_gem(self, c, center, 12)
		GemDraw.text(self, str(card.cost[c]), center + Vector2(14, 8), 23, Color(1, 1, 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color(0, 0, 0, 0.85))
	# selo "pode comprar"
	if affordable:
		var cc := Vector2(r.size.x / 2.0 + 4, 23)
		draw_circle(cc, 11, Color(0.15, 0.65, 0.3))
		draw_polyline(PackedVector2Array([cc + Vector2(-5, 0), cc + Vector2(-1, 4), cc + Vector2(6, -4)]),
			Color.WHITE, 2.5, true)
