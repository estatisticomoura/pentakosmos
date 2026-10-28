class_name TimerView
extends Control
## Cronometros da mesa: rodada e tempo total da partida; e a contagem regressiva da vez
## (anel que se esvazia). compact = uma linha so (computador); senao, duas caixas (toque).

var compact := false
var round_text := ""
var game_secs := 0.0
var left := -1.0          # segundos restantes da vez (-1 = sem cronometro)
var limit := 0.0
var who := ""             # legenda da contagem ("sua vez", nome do jogador)

const GOLDC := Color(0.93, 0.76, 0.40)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func clock(secs: float) -> String:
	var s := int(secs)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if compact:
		var x := 0.0
		GemDraw.text(self, round_text, Vector2(x, 21), 16, Color(0.65, 0.68, 0.76))
		x += font.get_string_size(round_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 8
		GemDraw.text(self, clock(game_secs), Vector2(x, 21), 17, GOLDC)
		x += font.get_string_size(clock(game_secs), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 16
		if left >= 0.0:
			_ring(Vector2(x + 12, 15), 11.0, 3.0)
			GemDraw.text(self, clock(ceilf(left)), Vector2(x + 28, 21), 17, _left_col())
		return
	# caixa 1: rodada e tempo da partida
	var w := size.x
	GemDraw.rounded(self, Rect2(0, 0, w, 36), Color(0, 0, 0, 0.35), 8, Color(1, 1, 1, 0.12), 1)
	GemDraw.text(self, round_text, Vector2(10, 25), 16, Color(0.65, 0.68, 0.76), HORIZONTAL_ALIGNMENT_LEFT, w - 70)
	GemDraw.text(self, clock(game_secs), Vector2(0, 25), 18, GOLDC, HORIZONTAL_ALIGNMENT_RIGHT, w - 10)
	# caixa 2: contagem regressiva da vez
	var r2 := Rect2(0, 42, w, 62)
	GemDraw.rounded(self, r2, Color(0, 0, 0, 0.35), 8, Color(GOLDC, 0.5) if left >= 0.0 else Color(1, 1, 1, 0.10), 1)
	if left < 0.0:
		GemDraw.ctext(self, "—", r2.get_center(), 22, Color(1, 1, 1, 0.3))
		GemDraw.text(self, who, Vector2(0, r2.end.y - 8), 13, Color(0.65, 0.68, 0.76), HORIZONTAL_ALIGNMENT_CENTER, w)
		return
	_ring(Vector2(32, r2.get_center().y), 21.0, 5.0)
	GemDraw.text(self, clock(ceilf(left)), Vector2(62, r2.position.y + 36), 27, _left_col())
	GemDraw.text(self, who, Vector2(62, r2.position.y + 54), 13, Color(0.65, 0.68, 0.76), HORIZONTAL_ALIGNMENT_LEFT, w - 66)


func _left_col() -> Color:
	return Color(1.0, 0.45, 0.35) if left <= 10.0 else Color(0.92, 0.92, 0.96)


func _ring(c: Vector2, r: float, w: float) -> void:
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.12), w, true)
	var frac := clampf(left / maxf(1.0, limit), 0.0, 1.0)
	if frac > 0.0:
		var col := Color(0.45, 0.85, 0.55) if left > 10.0 else Color(1.0, 0.45, 0.35)
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, col, w, true)
