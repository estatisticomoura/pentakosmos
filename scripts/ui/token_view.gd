class_name TokenView
extends Control
## Pilha de fichas do banco.

signal pressed(view: TokenView)

var color_idx := 0
var count := 0
var picked := 0        # quantas desta cor estao na selecao atual
var enabled := true
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(72, 72)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(func(): if enabled and color_idx != Defs.GOLD: create_tween().tween_property(self, "scale", Vector2(1.08, 1.08), 0.1))
	mouse_exited.connect(func(): create_tween().tween_property(self, "scale", Vector2.ONE, 0.1))


func setup(c: int, n: int, p: int, en: bool) -> void:
	color_idx = c
	count = n
	picked = p
	enabled = en
	queue_redraw()


func _process(delta: float) -> void:
	if picked > 0 or Defs.visual == "solidos":
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func _draw() -> void:
	var c := size / 2.0 - Vector2(0, 4)
	var r := 30.0
	# pilha: algumas fichas por baixo
	var layers := mini(count, 4)
	for i in range(layers, 0, -1):
		draw_circle(c + Vector2(0, i * 3), r, Defs.COLORS[color_idx].darkened(0.5))
	if count == 0:
		draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.18), 2.0, true)
	else:
		GemDraw.draw_chip(self, color_idx, c, r)
	if picked > 0:
		var a := 0.6 + 0.4 * sin(_t * 6.0)
		draw_arc(c, r + 5, 0, TAU, 40, Color(1.0, 0.85, 0.35, a), 4.0, true)
	# contador
	var bc := c + Vector2(r * 0.78, r * 0.78)
	draw_circle(bc, 13, Color(0.08, 0.08, 0.1, 0.92))
	draw_arc(bc, 13, 0, TAU, 24, Color(1, 1, 1, 0.4), 1.5, true)
	GemDraw.ctext(self, str(count), bc, 15, Color.WHITE)
	if picked > 0:
		var pc := c + Vector2(-r * 0.8, -r * 0.8)
		draw_circle(pc, 12, Color(1.0, 0.8, 0.3))
		GemDraw.ctext(self, "+%d" % picked, pc, 13, Color(0.1, 0.08, 0.0))
	if not enabled and count > 0:
		draw_circle(c, r, Color(0, 0, 0, 0.35))
