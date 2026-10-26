class_name MusicControls
extends Control
## Tocador compacto (tela de jogo): anterior, tocar/pausar, proxima.
## Passar o mouse mostra o nome da peca.

const BTN := 30.0
var _hover := -1


func _init() -> void:
	custom_minimum_size = Vector2(BTN * 3 + 8, 28)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	Audio.state_changed.connect(_refresh)
	Audio.track_started.connect(func(_i): _refresh())
	mouse_exited.connect(func():
		_hover = -1
		queue_redraw())
	_refresh()


func _refresh() -> void:
	if Audio.current.is_empty():
		tooltip_text = L.t("Music")
	else:
		tooltip_text = "%s — %s" % [Audio.current["title"], Audio.current["composer"]]
	queue_redraw()


func _button_at(x: float) -> int:
	return clampi(int(x / (BTN + 4)), 0, 2)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var b := _button_at(event.position.x)
		if b != _hover:
			_hover = b
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match _button_at(event.position.x):
			0:
				Audio.prev_track()
			1:
				Audio.toggle_pause()
			2:
				Audio.next_track()
		Audio.play("click")
		accept_event()


func _draw() -> void:
	var col := Color(1, 0.92, 0.75, 0.9)
	for i in range(3):
		var r := Rect2(Vector2(i * (BTN + 4), 0), Vector2(BTN, size.y))
		GemDraw.rounded(self, r, Color(1, 1, 1, 0.10 if _hover == i else 0.05), 6, Color(1, 1, 1, 0.18), 1)
		var c := r.get_center()
		match i:
			0:  # anterior: barra + triangulo para a esquerda
				draw_rect(Rect2(c + Vector2(-7, -6), Vector2(2.5, 12)), col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(6, -6), c + Vector2(6, 6), c + Vector2(-4, 0)]), col)
			1:
				if Audio.is_paused():
					draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -7), c + Vector2(-4, 7), c + Vector2(7, 0)]), col)
				else:
					draw_rect(Rect2(c + Vector2(-5, -6), Vector2(3.5, 12)), col)
					draw_rect(Rect2(c + Vector2(1.5, -6), Vector2(3.5, 12)), col)
			2:  # proxima
				draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -6), c + Vector2(-6, 6), c + Vector2(4, 0)]), col)
				draw_rect(Rect2(c + Vector2(4.5, -6), Vector2(2.5, 12)), col)
