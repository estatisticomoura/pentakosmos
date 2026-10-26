class_name NobleView
extends Control
## Filosofo (o antigo "nobre"). Arte opcional em res://assets/philosophers/philosopher_<n>.png (n = 1..10).

signal pressed(view: NobleView)
signal hover_changed(view: NobleView, on: bool)

var noble := -1
var points_text := "3"
var flexible := false
var selectable := false
var progress := -1      # cartas que faltam para o jogador observado (-1 = nao mostra)
var _tex: Texture2D = null
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(94, 88)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hover_changed.emit(self, true))
	mouse_exited.connect(func(): hover_changed.emit(self, false))


func setup(nb: int, pts: String, flex: bool, prog: int = -1) -> void:
	noble = nb
	points_text = pts
	flexible = flex
	progress = prog
	var path := "res://assets/philosophers/philosopher_%d.png" % (nb + 1)
	_tex = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()


func _process(delta: float) -> void:
	if selectable:
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if selectable:
		GemDraw.glow(self, r, Color(1.0, 0.85, 0.35), 0.7 + 0.3 * sin(_t * 5.0), 10)
	GemDraw.rounded(self, Rect2(Vector2(2, 4), size), Color(0, 0, 0, 0.45), 10)
	if _tex != null:
		draw_texture_rect(_tex, r, false)
		GemDraw.rounded(self, r, Color(0, 0, 0, 0), 10, Color(0.85, 0.7, 0.35), 2)
	else:
		GemDraw.rounded(self, r, Color(0.20, 0.13, 0.22), 10, Color(0.85, 0.7, 0.35), 2)
	# pontos que este filosofo daria (canto superior esquerdo)
	GemDraw.text(self, points_text, Vector2(8, 27), 22 if points_text.length() <= 2 else 16,
		Color(1.0, 0.88, 0.55), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	if noble < 0:
		return
	# nome do filosofo
	var nm := L.t(Defs.PHILOSOPHERS[noble])
	var fs := 13
	while fs > 9 and ThemeDB.fallback_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 8:
		fs -= 1
	GemDraw.ctext(self, nm, Vector2(size.x / 2.0, 44), fs, Color(1.0, 0.93, 0.78), 3)
	if flexible:
		GemDraw.ctext(self, L.t("−2 any"), Vector2(size.x / 2.0, 59), 10, Color(1, 1, 1, 0.6))
	# requisito: simbolo e numero ao lado
	var req: Array = Defs.NOBLES[noble]
	var cols: Array = []
	for col in range(5):
		if req[col] > 0:
			cols.append(col)
	var slot := 30.0
	var x0 := (size.x - cols.size() * slot) / 2.0 + 9.0
	for i in range(cols.size()):
		var col: int = cols[i]
		var center := Vector2(x0 + i * slot, size.y - 13)
		GemDraw.draw_gem(self, col, center, 8)
		GemDraw.text(self, str(req[col]), center + Vector2(10, 5), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	if progress >= 0:
		# cartas que faltam para o jogador observado
		var pc := Vector2(size.x - 13, 13)
		draw_circle(pc, 10, Color(0.12, 0.45, 0.25) if progress <= 2 else Color(0.18, 0.18, 0.24))
		draw_arc(pc, 10, 0, TAU, 20, Color(1, 1, 1, 0.35), 1.0, true)
		GemDraw.ctext(self, str(progress), pc, 12, Color.WHITE)
