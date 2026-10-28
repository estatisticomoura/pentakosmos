class_name NobleView
extends Control
## Cartao de filosofo (id 0..9) ou escritor (id 100..109).
## Pontos a esquerda; simbolos do requisito numa linha e os numeros embaixo; a linha
## "-N livre" (quando ha desconto); o nome; e uma bolha no canto com quantas cartas faltam.
## Arte opcional em res://assets/philosophers/philosopher_<n>.png ou assets/writers/writer_<n>.png.

signal pressed(view: NobleView)
signal hover_changed(view: NobleView, on: bool)

static var source: GameState = null   # partida de onde vem o requisito, o nome e a arte

var noble := -1
var req := [0, 0, 0, 0, 0]
var pname := ""
var points_text := "3"
var free_n := 0          # cartas livres no requisito (0 = exato)
var selectable := false
var progress := -1       # cartas que faltam para o jogador observado (-1 = nao mostra)
var _tex: Texture2D = null
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(94, 88)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hover_changed.emit(self, true))
	mouse_exited.connect(func(): hover_changed.emit(self, false))


func setup(nb: int, pts: String, p_free: int, prog: int = -1) -> void:
	noble = nb
	points_text = pts
	free_n = p_free
	progress = prog
	var path := ""
	if nb >= 0 and source != null:
		req = source.patron_req(nb)
		pname = source.patron_name(nb)
		var art := source.patron_art(nb)
		if art > 0:
			path = ("res://assets/writers/writer_%d.png" if Defs.is_writer(nb) else "res://assets/philosophers/philosopher_%d.png") % art
	_tex = load(path) if path != "" and ResourceLoader.exists(path) else null
	queue_redraw()


func _process(delta: float) -> void:
	if selectable:
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func is_writer() -> bool:
	return noble >= 0 and Defs.is_writer(noble)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var k := size.y / 100.0
	var writer := is_writer()
	var frame := Color(0.62, 0.78, 0.92) if writer else Color(0.93, 0.76, 0.40)
	var bg := Color(0.11, 0.15, 0.22) if writer else Color(0.20, 0.13, 0.17)
	if selectable:
		GemDraw.glow(self, r, Color(1.0, 0.85, 0.35), 0.7 + 0.3 * sin(_t * 5.0), 10)
	GemDraw.rounded(self, Rect2(Vector2(2, 4), size), Color(0, 0, 0, 0.45), 10)
	if _tex != null:
		draw_texture_rect(_tex, r, false)
		GemDraw.rounded(self, r, Color(0, 0, 0, 0), 10, frame, 2)
	else:
		GemDraw.rounded(self, r, bg, 10, frame, 2)
	# pontos que daria agora
	GemDraw.text(self, points_text, Vector2(6, 44) * k, int((32 if points_text.length() <= 2 else 22) * k),
		Color(1.0, 0.88, 0.55), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	if noble < 0:
		return
	# requisito: simbolos numa linha, numeros embaixo
	var cols: Array = []
	for c in range(5):
		if req[c] > 0:
			cols.append(c)
	var x0 := 30.0 * k
	var cw := (size.x - x0 - 6.0 * k) / maxi(1, cols.size())
	for i in range(cols.size()):
		var cx := x0 + cw * i + cw / 2.0
		GemDraw.draw_gem(self, cols[i], Vector2(cx, 20 * k), 8.5 * k)
		GemDraw.ctext(self, str(req[cols[i]]), Vector2(cx, 43 * k), int(20 * k), Color.WHITE, 3)
	if free_n > 0:
		GemDraw.ctext(self, L.f("−{n} any", {"n": free_n}), Vector2(size.x / 2.0, 64 * k), int(13 * k), Color(1, 1, 1, 0.65))
	# nome
	var nm := L.t(pname)
	var fs := int(17 * k)
	while fs > 9 and ThemeDB.fallback_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 8:
		fs -= 1
	GemDraw.ctext(self, nm, Vector2(size.x / 2.0, 85 * k), fs, Color(1.0, 0.93, 0.78), 3)
	if progress >= 0:
		# bolha: quantas cartas ainda faltam (verde = ja atende)
		var pc := Vector2(size.x - 2 * k, 2 * k)
		var rad := 12.0 * k
		draw_circle(pc, rad, Color(0.55, 0.88, 0.55) if progress == 0 else Color(1.0, 0.86, 0.45))
		draw_arc(pc, rad, 0, TAU, 24, Color(0.4, 0.3, 0.1), 1.5, true)
		GemDraw.ctext(self, str(progress), pc, int(15 * k), Color(0.15, 0.1, 0.0))
