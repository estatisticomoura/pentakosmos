class_name CardView
extends Control
## Carta de desenvolvimento desenhada em codigo. Se existir uma imagem em
## res://assets/cards/<pasta do deck>/<chave>.png ela e usada como arte de fundo
## (pastas: pentakosmos e legacy; lista em assets/cards/CARD_LIST.csv).

signal pressed(view: CardView)
signal hover_changed(view: CardView, on: bool)

const BASE_SIZE := Vector2(112, 154)
## false = quando houver arte em PNG, mostra so a imagem (sem faixa, pontos e custos)
const DRAW_INFO_OVER_ART := true
const BACK_COLORS := [Color(0, 0, 0), Color(0.16, 0.42, 0.30), Color(0.60, 0.46, 0.14), Color(0.20, 0.27, 0.62)]

var card: Defs.CardDef = null
var deck_name := "oficial"
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
	_hover = v
	hover_changed.emit(self, v)
	if not interactive or (card == null and back_level == 0):
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.05, 1.05) if v else Vector2.ONE, 0.12)
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
	var col: Color = BACK_COLORS[back_level]
	if _back_tex != null:
		draw_texture_rect(_back_tex, r, false)
	else:
		GemDraw.rounded(self, r, col.darkened(0.35), 12, col.lightened(0.25), 2)
		GemDraw.rounded(self, r.grow(-8), col.darkened(0.1), 8, Color(1, 1, 1, 0.15), 1)
		# losango decorativo
		var c := r.get_center()
		var pts := PackedVector2Array([c + Vector2(0, -34), c + Vector2(26, 0), c + Vector2(0, 34), c + Vector2(-26, 0)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.10))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(1, 1, 1, 0.35), 2.0, true)
	GemDraw.ctext(self, L.f("Level {lv}", {"lv": ["", "I", "II", "III"][back_level]}), Vector2(r.size.x / 2, 22), 15, Color(1, 1, 1, 0.9), 3)
	for i in range(back_level):
		draw_circle(Vector2(r.size.x / 2 + (i - (back_level - 1) / 2.0) * 14, r.size.y / 2), 4.5, Color(1, 1, 1, 0.85))
	if back_count >= 0:
		GemDraw.ctext(self, str(back_count), Vector2(r.size.x / 2, r.size.y - 20), 18, Color(1, 1, 1, 0.95), 4)


func _draw_face(r: Rect2) -> void:
	var bc: Color = Defs.COLORS[card.bonus]
	var ink: Color = Defs.INK[card.bonus]
	var border := Color(0.25, 0.9, 0.45) if affordable else bc.lightened(0.15)
	if card.bonus == 4 and not affordable:
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
			3 if card.bonus != 0 else 0, Color(0, 0, 0, 0.5))
	# gema do bonus
	if Defs.visual == "solidos":
		draw_circle(Vector2(r.size.x - 24, 24), 17, Color(0.07, 0.08, 0.11, 0.85))
	GemDraw.draw_gem(self, card.bonus, Vector2(r.size.x - 24, 24), 15)
	# custos: ordem fixa de cima para baixo (branco, azul, verde, vermelho, preto),
	# com o numero a direita do simbolo
	var cols: Array = []
	for c in range(5):
		if card.cost[c] > 0:
			cols.append(c)
	for i in range(cols.size()):
		var c: int = cols[i]
		var center := Vector2(18, r.size.y - 20 - (cols.size() - 1 - i) * 26)
		GemDraw.draw_gem(self, c, center, 11)
		GemDraw.text(self, str(card.cost[c]), center + Vector2(14, 7), 19, Color(1, 1, 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color(0, 0, 0, 0.85))
	# nivel
	for i in range(card.level):
		draw_circle(Vector2(r.size.x - 12 - i * 10, r.size.y - 12), 3.2, Color(1, 1, 1, 0.55))
	# selo "pode comprar"
	if affordable:
		var cc := Vector2(r.size.x - 18, r.size.y - 34)
		draw_circle(cc, 11, Color(0.15, 0.65, 0.3))
		draw_polyline(PackedVector2Array([cc + Vector2(-5, 0), cc + Vector2(-1, 4), cc + Vector2(6, -4)]),
			Color.WHITE, 2.5, true)
