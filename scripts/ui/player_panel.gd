class_name PlayerPanel
extends Control
## Resumo de um jogador: pontos, nobres, bonus (cartas) e fichas por cor.

signal zone_hover(panel: PlayerPanel, zone: String)   # "reservas", "nobres" ou "" (saiu)
signal zone_tap(panel: PlayerPanel, zone: String)

var g: GameState
var idx := 0
var is_current := false
var viewer := 0                 # jogador que esta olhando a mesa
var reveal_mode := "rodada"     # visibilidade das reservas dos adversarios
var _t := 0.0
var _zone := ""
var _res_zone := Rect2()
var _noble_zone := Rect2()
var _pulses := {}               # "b<c>" / "t<c>" / "r" -> tempo restante

# rotulo da IA no painel: o personagem (Defs.PERSONAS); as IAs internas dos testes tem rotulo proprio
const KIND_LABEL := {"tatica": "Tactical AI", "evoluida": "Evolved AI", "mista": "Mixed AI"}  # tr


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	mouse_exited.connect(func(): _set_zone(""))


func _process(delta: float) -> void:
	var redraw := is_current or Defs.visual == "solidos"
	_t += delta
	for k in _pulses.keys():
		_pulses[k] -= delta
		if _pulses[k] <= 0:
			_pulses.erase(k)
		redraw = true
	if redraw:
		queue_redraw()


func pulse(key: String) -> void:
	## Brilho rapido ao receber uma carta (b<cor>), ficha (t<cor>) ou reserva (r).
	_pulses[key] = 0.5
	queue_redraw()


func _zone_at(pos: Vector2) -> String:
	if _res_zone.has_area() and _res_zone.grow(4).has_point(pos):
		return "reservas"
	if _noble_zone.has_area() and _noble_zone.grow(4).has_point(pos):
		return "nobres"
	return ""


func _set_zone(z: String) -> void:
	if z != _zone:
		_zone = z
		zone_hover.emit(self, z)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_zone(_zone_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var z := _zone_at(event.position)
		if z != "":
			zone_tap.emit(self, z)
			accept_event()


func reserve_rect(i: int) -> Rect2:
	return Rect2(_res_zone.position.x + i * 19, 7, 15, 21)


func _pulse_ring(rect: Rect2, key: String, col: Color) -> void:
	if not _pulses.has(key):
		return
	var a: float = _pulses[key] / 0.5
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(col, a)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, rect.grow(3 + (1.0 - a) * 6))


func token_pos(c: int) -> Vector2:
	## Posicao (local) da ficha da cor c, usada nas animacoes.
	if c == Defs.GOLD:
		return Vector2(12 + 5 * 74 + 14, _row_y())
	return Vector2(12 + c * 74 + 48, _row_y())


func bonus_pos(c: int) -> Vector2:
	return Vector2(12 + c * 74 + 14, _row_y())


func _f(sz: int) -> int:
	## Textos pequenos ficam um pouco maiores no modo toque.
	return sz + 2 if UITheme.touch else sz


func _row_y() -> float:
	return size.y - 26


func _draw() -> void:
	if g == null:
		return
	var p: GameState.PlayerState = g.players[idx]
	var r := Rect2(Vector2.ZERO, size)
	if is_current:
		GemDraw.glow(self, r, Color(1.0, 0.85, 0.35), 0.55 + 0.25 * sin(_t * 3.0), 10)
	GemDraw.rounded(self, r, Color(0.10, 0.11, 0.15, 0.92), 10,
		Color(1.0, 0.85, 0.35) if is_current else Color(1, 1, 1, 0.12), 2)
	# nome
	var name_col := Color(1.0, 0.92, 0.7) if is_current else Color(0.9, 0.9, 0.95)
	GemDraw.text(self, p.name, Vector2(12, 24), 18, name_col)
	var nw := ThemeDB.fallback_font.get_string_size(p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var tag := ""
	if Defs.PERSONAS.has(p.kind):
		var persona := L.t(Defs.PERSONAS[p.kind])
		tag = L.t("AI") if p.name.begins_with(persona) else "%s · %s" % [L.t("AI"), persona]
	elif KIND_LABEL.has(p.kind):
		tag = L.t(KIND_LABEL[p.kind])
	if tag != "":
		GemDraw.text(self, tag, Vector2(18 + nw, 23), _f(12), Color(0.65, 0.7, 0.8))
		nw += ThemeDB.fallback_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _f(12)).x + 6
	# reservas: minicartas (visiveis para quem olha) ou versos (ocultas)
	_res_zone = Rect2(24 + nw, 7, p.reserved.size() * 19 - 4, 21) if not p.reserved.is_empty() else Rect2()
	for i in range(p.reserved.size()):
		var cid: int = p.reserved[i]
		var cd: Defs.CardDef = g.cards[cid]
		var rr := reserve_rect(i)
		if g.reserve_visible(idx, cid, viewer, reveal_mode):
			GemDraw.rounded(self, rr, Defs.COLORS[cd.bonus], 3, Color(1, 0.9, 0.5, 0.9), 1)
			if cd.points > 0:
				GemDraw.ctext(self, str(cd.points), rr.get_center(), 12, Defs.INK[cd.bonus], 2 if cd.bonus != 0 else 0)
		else:
			GemDraw.rounded(self, rr, CardView.BACK_COLORS[cd.level], 3, Color(1, 1, 1, 0.5), 1)
	_pulse_ring(_res_zone, "r", Color(1, 0.85, 0.4))
	if _zone == "reservas":
		GemDraw.rounded(self, _res_zone.grow(3), Color(0, 0, 0, 0), 5, Color(1, 0.85, 0.4), 1)
	# nobres
	var nx := size.x - 120
	_noble_zone = Rect2(nx - 9, 6, p.nobles.size() * 18, 20) if not p.nobles.is_empty() else Rect2()
	for i in range(p.nobles.size()):
		var c := Vector2(nx + i * 18, 16)
		var crown := PackedVector2Array([c + Vector2(-7, 5), c + Vector2(-7, -4), c + Vector2(-3, 1),
			c + Vector2(0, -6), c + Vector2(3, 1), c + Vector2(7, -4), c + Vector2(7, 5)])
		draw_colored_polygon(crown, Color(0.95, 0.78, 0.35))
	if _zone == "nobres":
		GemDraw.rounded(self, _noble_zone.grow(3), Color(0, 0, 0, 0), 5, Color(1, 0.85, 0.4), 1)
	# pontos
	GemDraw.text(self, str(p.points), Vector2(size.x - 64, 34), 32, Color(1.0, 0.88, 0.55),
		HORIZONTAL_ALIGNMENT_RIGHT, 40, 3)
	GemDraw.text(self, "/%d" % g.rules.target, Vector2(size.x - 22, 34), _f(13), Color(0.7, 0.7, 0.75),
		HORIZONTAL_ALIGNMENT_LEFT, -1)
	# bonus + fichas por cor
	var y := _row_y()
	for c in range(5):
		var bx := 12 + c * 74
		var br := Rect2(bx, y - 17, 26, 34)
		var col: Color = Defs.COLORS[c]
		_pulse_ring(br, "b%d" % c, Color(1, 0.9, 0.5))
		if p.bonus[c] > 0:
			GemDraw.rounded(self, br, col, 4, col.lightened(0.3) if c != 4 else Color(0.6, 0.6, 0.65), 1)
			GemDraw.ctext(self, str(p.bonus[c]), br.get_center(), 17, Defs.INK[c], 2 if c != 0 else 0)
		else:
			GemDraw.rounded(self, br, Color(1, 1, 1, 0.04), 4, Color(col, 0.5), 1)
		# pontos de cartas desta cor (vitoria por especializacao)
		if g.rules.color_win > 0 and p.color_pts[c] > 0:
			var pc := Vector2(bx + 26, y - 17)
			var hot: bool = p.color_pts[c] >= g.rules.color_win - 3
			draw_circle(pc, 8, Color(0.85, 0.65, 0.2) if hot else Color(0.22, 0.22, 0.28))
			draw_arc(pc, 8, 0, TAU, 16, Color(1, 0.9, 0.6, 0.8), 1.0, true)
			GemDraw.ctext(self, str(p.color_pts[c]), pc, 11, Color(0.1, 0.07, 0.0) if hot else Color(1, 0.9, 0.6))
		var tc := Vector2(bx + 48, y)
		if _pulses.has("t%d" % c):
			draw_arc(tc, 15 + (1.0 - _pulses["t%d" % c] / 0.5) * 5, 0, TAU, 24, Color(1, 0.9, 0.5, _pulses["t%d" % c] / 0.5), 2.0, true)
		if p.tokens[c] > 0:
			GemDraw.draw_chip(self, c, tc, 13)
			GemDraw.ctext(self, str(p.tokens[c]), tc + Vector2(17, 0), 15, Color.WHITE, 2)
		else:
			draw_arc(tc, 12, 0, TAU, 20, Color(col, 0.35), 1.5, true)
	var gc := token_pos(Defs.GOLD)
	if _pulses.has("t5"):
		draw_arc(gc, 15 + (1.0 - _pulses["t5"] / 0.5) * 5, 0, TAU, 24, Color(1, 0.9, 0.5, _pulses["t5"] / 0.5), 2.0, true)
	if p.tokens[Defs.GOLD] > 0:
		GemDraw.draw_chip(self, Defs.GOLD, gc, 13)
		GemDraw.ctext(self, str(p.tokens[Defs.GOLD]), gc + Vector2(17, 0), 15, Color.WHITE, 2)
	else:
		draw_arc(gc, 12, 0, TAU, 20, Color(Defs.COLORS[5], 0.35), 1.5, true)
	# vitoria por especializacao: pontos na cor mais avancada
	if g.rules.color_win > 0:
		var bc := g.best_color(p)
		var cp: int = p.color_pts[bc]
		var gx := Vector2(size.x - 262, 17)
		if cp > 0:
			GemDraw.draw_gem(self, bc, gx, 7, false)
		GemDraw.text(self, "%d/%d" % [cp, g.rules.color_win], gx + Vector2(10, 5), _f(12),
			Color(1.0, 0.85, 0.35) if cp >= g.rules.color_win - 3 else Color(0.6, 0.62, 0.7))
	# total de fichas vs limite
	var tot := p.token_count()
	var lim := g.rules.hand_limit
	GemDraw.text(self, L.f("{n}/{lim} tokens", {"n": tot, "lim": lim}), Vector2(size.x - 200, 23), _f(12),
		Color(1, 0.5, 0.4) if tot >= lim else Color(0.6, 0.62, 0.7))
