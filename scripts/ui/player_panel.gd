class_name PlayerPanel
extends Control
## Resumo de um jogador. A esquerda, uma faixa com nome, reservas, filosofos (louro)
## e escritores (pena), IA, fichas na mao, pontos e especializacao. A direita, uma coluna
## por elemento: as cartas compradas em cima (com a bolha dos pontos daquela cor) e as
## fichas embaixo; a ultima coluna e a das esferas.

signal zone_hover(panel: PlayerPanel, zone: String)   # "reservas", "nobres", "governante" ou "" (saiu)
signal zone_tap(panel: PlayerPanel, zone: String)

var g: GameState
var idx := 0
var is_current := false
var viewer := 0                 # jogador que esta olhando a mesa
var _t := 0.0
var _zone := ""
var _res_zone := Rect2()
var _noble_zone := Rect2()
var _gov_zone := Rect2()
var _pulses := {}               # "b<c>" / "t<c>" / "r" -> tempo restante

const KIND_LABEL := {"tatica": "Tactical AI", "evoluida": "Evolved AI", "mista": "Mixed AI"}  # tr
const GOLDC := Color(0.93, 0.76, 0.40)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	mouse_exited.connect(func(): _set_zone(""))


func _process(delta: float) -> void:
	var redraw := is_current or Defs.visual == "solidos"
	_t += delta
	for key in _pulses.keys():
		_pulses[key] -= delta
		if _pulses[key] <= 0:
			_pulses.erase(key)
		redraw = true
	if redraw:
		queue_redraw()


func pulse(key: String) -> void:
	## Brilho rapido ao receber uma carta (b<cor>), ficha (t<cor>) ou reserva (r).
	_pulses[key] = 0.5
	queue_redraw()


func _zone_at(pos: Vector2) -> String:
	if _res_zone.has_area() and _res_zone.grow(5).has_point(pos):
		return "reservas"
	if _noble_zone.has_area() and _noble_zone.grow(5).has_point(pos):
		return "nobres"
	if _gov_zone.has_area() and _gov_zone.grow(5).has_point(pos):
		return "governante"
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


# --- geometria -----------------------------------------------------------------
func _strip_w() -> float:
	return clampf(size.x * 0.31, 128.0, 210.0)


func _col_w() -> float:
	return (size.x - _strip_w() - 12.0) / 6.0


func _k() -> float:
	## Escala dos elementos das colunas (cartas e fichas).
	return clampf(minf(size.y / 118.0, _col_w() / 70.0), 0.6, 1.15)


func _col_x(c: int) -> float:
	return _strip_w() + 8.0 + _col_w() * c + _col_w() / 2.0


func _card_rect(c: int) -> Rect2:
	var k := _k()
	return Rect2(Vector2(_col_x(c) - 30.0 * k, 12.0 * size.y / 118.0), Vector2(38, 46) * k)


func token_pos(c: int) -> Vector2:
	## Posicao (local) da ficha da cor c, usada nas animacoes.
	var k := _k()
	return Vector2(_col_x(c) - 10.0 * k, size.y - 26.0 * size.y / 118.0)


func bonus_pos(c: int) -> Vector2:
	return _card_rect(clampi(c, 0, 4) if c >= 0 else 2).get_center()


func reserve_rect(i: int) -> Rect2:
	return Rect2(_res_zone.position.x + i * 15, _res_zone.position.y, 11, 16)


func _f(sz: int) -> int:
	return int(round(sz * clampf(size.y / 118.0, 0.8, 1.15)))


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


# --- icones --------------------------------------------------------------------
static func _bez(P: Array, u: float) -> Vector2:
	var v := 1.0 - u
	return P[0] * v * v * v + P[1] * 3.0 * v * v * u + P[2] * 3.0 * v * u * u + P[3] * u * u * u


static func _dbez(P: Array, u: float) -> Vector2:
	var v := 1.0 - u
	return (P[1] - P[0]) * 3.0 * v * v + (P[2] - P[1]) * 6.0 * v * u + (P[3] - P[2]) * 3.0 * u * u


static func _leaf(ci: CanvasItem, base: Vector2, dir: Vector2, L: float, Wd: float, col: Color, edge: Color, lw: float) -> void:
	var o := dir.orthogonal()
	var poly := PackedVector2Array()
	for j in range(17):
		var u := j / 16.0
		poly.append(base + dir * L * u + o * Wd * pow(sin(PI * u), 1.1) * (1.1 - 0.4 * u))
	for j in range(15, 0, -1):
		var u := j / 16.0
		poly.append(base + dir * L * u - o * Wd * pow(sin(PI * u), 1.1) * (1.1 - 0.4 * u))
	ci.draw_colored_polygon(poly, col)
	if lw > 0.0:
		var closed := poly.duplicate()
		closed.append(poly[0])
		ci.draw_polyline(closed, edge, lw, true)


static func draw_laurel(ci: CanvasItem, c: Vector2, h: float) -> void:
	## Coroa de louros (filosofos): dois ramos em U, abertos no alto.
	var col := Color(0.94, 0.75, 0.28)
	var edge := Color(0.59, 0.41, 0.12)
	var lw := maxf(0.8, h * 0.02)
	for s in [-1.0, 1.0]:
		var P := [c + Vector2(s * 0.12, 0.44) * h, c + Vector2(-s * 0.52, 0.40) * h,
			c + Vector2(-s * 0.56, -0.18) * h, c + Vector2(-s * 0.30, -0.44) * h]
		var pts := PackedVector2Array()
		for k in range(21):
			pts.append(_bez(P, k / 20.0))
		ci.draw_polyline(pts, edge, maxf(1.2, h * 0.055), true)
		for sp in [[0.16, 34.0, 1.0], [0.38, 30.0, 0.95], [0.60, 26.0, 0.88], [0.80, 20.0, 0.80],
				[0.48, -28.0, 0.6], [0.70, -24.0, 0.55]]:
			var d := _dbez(P, sp[0]).normalized().rotated(-deg_to_rad(sp[1]) * s)
			_leaf(ci, _bez(P, sp[0]), d, h * 0.36 * sp[2], h * 0.10 * sp[2], col, edge, lw)
		_leaf(ci, _bez(P, 1.0), _dbez(P, 1.0).normalized(), h * 0.30, h * 0.085, col, edge, lw)


static func draw_column(ci: CanvasItem, c: Vector2, h: float) -> void:
	## Coluna grega (governante): capitel, fuste com caneluras e base.
	var w := h * 0.62
	var col := Color(0.93, 0.80, 0.52)
	var top := c.y - h * 0.5
	ci.draw_rect(Rect2(c.x - w / 2.0, top, w, h * 0.13), col)
	ci.draw_rect(Rect2(c.x - w * 0.36, top + h * 0.15, w * 0.72, h * 0.66), col.darkened(0.08))
	for k in [-0.18, 0.0, 0.18]:
		ci.draw_line(Vector2(c.x + w * k, top + h * 0.18), Vector2(c.x + w * k, top + h * 0.78), col.darkened(0.45), 1.0)
	ci.draw_rect(Rect2(c.x - w / 2.0, top + h * 0.83, w, h * 0.15), col)


static func draw_quill(ci: CanvasItem, c: Vector2, h: float) -> void:
	## Pena de escrever (escritores).
	var col := Color(0.80, 0.90, 1.0)
	var edge := Color(0.35, 0.48, 0.62)
	var dir := Vector2(0.55, -0.83).normalized()
	var base := c - dir * h * 0.45
	_leaf(ci, base + dir * h * 0.12, dir, h * 0.82, h * 0.17, col, edge, maxf(0.8, h * 0.03))
	ci.draw_line(base, base + dir * h * 0.85, edge, maxf(1.0, h * 0.05), true)
	ci.draw_line(base - dir * h * 0.08, base + dir * h * 0.12, Color(0.25, 0.25, 0.3), maxf(1.2, h * 0.07), true)


# --- desenho -------------------------------------------------------------------
func _draw() -> void:
	if g == null:
		return
	var p: GameState.PlayerState = g.players[idx]
	var r := Rect2(Vector2.ZERO, size)
	var ky := size.y / 118.0
	if is_current:
		GemDraw.glow(self, r, Color(1.0, 0.85, 0.35), 0.55 + 0.25 * sin(_t * 3.0), 10)
	GemDraw.rounded(self, r, Color(0.10, 0.11, 0.15, 0.94), 10,
		Color(1.0, 0.85, 0.35) if is_current else Color(1, 1, 1, 0.12), 2)
	var sw := _strip_w()
	_draw_strip(p, sw, ky)
	draw_line(Vector2(sw, 10 * ky), Vector2(sw, size.y - 10 * ky), Color(1, 1, 1, 0.10), 1.0)
	_draw_columns(p)


func _draw_strip(p: GameState.PlayerState, sw: float, ky: float) -> void:
	var x := 12.0
	# icones da linha do nome: reservas, louro (filosofos) e pena (escritores)
	var phil := 0
	var wri := 0
	for id in p.nobles:
		if Defs.is_writer(id):
			wri += 1
		else:
			phil += 1
	var icon_h := 20.0 * ky
	var icons_w := 0.0
	if not p.reserved.is_empty():
		icons_w += p.reserved.size() * 15 + 10
	if phil > 0:
		icons_w += icon_h + (14 if phil > 1 else 0) + 6
	if wri > 0:
		icons_w += icon_h + (14 if wri > 1 else 0) + 6
	if p.governor >= 0:
		icons_w += icon_h + 6
	var name_col := Color(1.0, 0.92, 0.7) if is_current else Color(0.92, 0.92, 0.96)
	var fs := _f(21)
	var font := ThemeDB.fallback_font
	while fs > 12 and font.get_string_size(p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > sw - 22 - icons_w:
		fs -= 1
	var y1 := 26.0 * ky
	GemDraw.text(self, p.name, Vector2(x, y1), fs, name_col)
	var ix := x + font.get_string_size(p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8
	# reservas: minicartas (visiveis) ou versos (ocultas)
	_res_zone = Rect2(ix, y1 - 15 * ky, p.reserved.size() * 15 - 4, 16) if not p.reserved.is_empty() else Rect2()
	for i in range(p.reserved.size()):
		var cid: int = p.reserved[i]
		var cd: Defs.CardDef = g.cards[cid]
		var rr := reserve_rect(i)
		if g.reserve_visible(idx, cid, viewer):
			var dc := cd.display_color()
			GemDraw.rounded(self, rr, Defs.COLORS[dc] if dc >= 0 else Color(0.5, 0.5, 0.55), 3, Color(1, 0.9, 0.5, 0.9), 1)
		else:
			GemDraw.rounded(self, rr, Color(0.035, 0.04, 0.07), 3, Color(CardView.BACK_COLORS[cd.level], 0.9), 1)
	_pulse_ring(_res_zone, "r", Color(1, 0.85, 0.4))
	if _zone == "reservas":
		GemDraw.rounded(self, _res_zone.grow(3), Color(0, 0, 0, 0), 5, Color(1, 0.85, 0.4), 1)
	if not p.reserved.is_empty():
		ix += p.reserved.size() * 15 + 10   # respiro entre reservas e louros
	var nz_start := ix
	if phil > 0:
		draw_laurel(self, Vector2(ix + icon_h * 0.5, y1 - 7 * ky), icon_h)
		ix += icon_h + 2
		if phil > 1:
			GemDraw.text(self, "×%d" % phil, Vector2(ix, y1 - 1), _f(13), GOLDC)
			ix += 14
		ix += 4
	if wri > 0:
		draw_quill(self, Vector2(ix + icon_h * 0.5, y1 - 7 * ky), icon_h)
		ix += icon_h + 2
		if wri > 1:
			GemDraw.text(self, "×%d" % wri, Vector2(ix, y1 - 1), _f(13), Color(0.8, 0.9, 1.0))
			ix += 14
	_noble_zone = Rect2(nz_start - 2, y1 - 18 * ky, ix - nz_start + 4, 22 * ky) if (phil + wri) > 0 else Rect2()
	if _zone == "nobres":
		GemDraw.rounded(self, _noble_zone.grow(2), Color(0, 0, 0, 0), 5, Color(1, 0.85, 0.4), 1)
	# governante: uma coluna grega
	if p.governor >= 0:
		ix += 6
		draw_column(self, Vector2(ix + icon_h * 0.4, y1 - 7 * ky), icon_h)
		_gov_zone = Rect2(ix - 2, y1 - 18 * ky, icon_h * 0.8 + 4, 22 * ky)
		ix += icon_h * 0.8 + 4
		if _zone == "governante":
			GemDraw.rounded(self, _gov_zone.grow(2), Color(0, 0, 0, 0), 5, Color(1, 0.85, 0.4), 1)
	else:
		_gov_zone = Rect2()
	# IA
	var y := y1
	var tag := ""
	if Defs.PERSONAS.has(p.kind):
		var persona := L.t(Defs.PERSONAS[p.kind])
		tag = L.t("AI") if p.name.begins_with(persona) else "%s · %s" % [L.t("AI"), persona]
	elif KIND_LABEL.has(p.kind):
		tag = L.t(KIND_LABEL[p.kind])
	if tag != "":
		y += 21 * ky
		GemDraw.text(self, tag, Vector2(x, y), _f(15), Color(0.65, 0.68, 0.76), HORIZONTAL_ALIGNMENT_LEFT, sw - 18)
	# fichas na mao
	y += 22 * ky
	var tot := p.token_count()
	var lim := g.rules.hand_limit
	GemDraw.text(self, L.f("{n}/{lim} tokens", {"n": tot, "lim": lim}), Vector2(x, y), _f(16),
		Color(1, 0.55, 0.45) if tot >= lim else Color(0.88, 0.88, 0.92), HORIZONTAL_ALIGNMENT_LEFT, sw - 18)
	# pontos e especializacao
	var by := size.y - 10 * ky
	var pts_s := str(p.points)
	var pfs := _f(36)
	GemDraw.text(self, pts_s, Vector2(x, by), pfs, Color(1.0, 0.88, 0.55), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	var pw := font.get_string_size(pts_s, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	var tgt := g.target_of(p)
	GemDraw.text(self, "/%d" % tgt, Vector2(x + pw + 2, by - 2), _f(17),
		GOLDC if p.governor >= 0 else Color(0.65, 0.68, 0.76))
	var cw := g.spec_threshold(p)
	if cw > 0:
		var bc := g.best_color(p)
		var cp: int = p.color_pts[bc]
		if cp > 0:
			var sx := x + pw + 2 + font.get_string_size("/%d" % tgt, HORIZONTAL_ALIGNMENT_LEFT, -1, _f(17)).x + 10
			GemDraw.draw_gem(self, bc, Vector2(sx + 8, by - 8 * ky), 8 * ky)
			GemDraw.text(self, "%d/%d" % [cp, cw], Vector2(sx + 19, by - 2), _f(16),
				GOLDC if cp >= cw - 3 else Color(0.88, 0.88, 0.92))


func _draw_columns(p: GameState.PlayerState) -> void:
	var k := _k()
	for c in range(6):
		var col: Color = Defs.COLORS[c]
		var faint := Color(col, 0.35) if c != 4 else Color(0.6, 0.45, 0.3, 0.45)
		if c < 5:
			var cr := _card_rect(c)
			_pulse_ring(cr, "b%d" % c, Color(1, 0.9, 0.5))
			if p.bonus[c] > 0:
				GemDraw.rounded(self, cr, col.darkened(0.35) if c != 0 else col.darkened(0.15), 6, col.lightened(0.2), 2)
				GemDraw.ctext(self, str(p.bonus[c]), cr.get_center() + Vector2(0, 1), int(23 * k),
					Color.WHITE if c != 0 else Color(0.08, 0.08, 0.12))
				if p.color_pts[c] > 0:
					# bolha: pontos das cartas desta cor
					var bc := cr.position + Vector2(cr.size.x, 0)
					var rad := 11.0 * k
					var hot: bool = g.spec_threshold(p) > 0 and p.color_pts[c] >= g.spec_threshold(p) - 3
					draw_circle(bc, rad, Color(1.0, 0.72, 0.25) if hot else Color(1.0, 0.86, 0.45))
					draw_arc(bc, rad, 0, TAU, 24, Color(0.4, 0.3, 0.1), 1.5, true)
					GemDraw.ctext(self, str(p.color_pts[c]), bc, int(14 * k), Color(0.15, 0.1, 0.0))
			else:
				GemDraw.rounded(self, cr, Color(0, 0, 0, 0), 6, faint, 1)
		var tc := token_pos(c)
		var tr := 21.0 * k
		if _pulses.has("t%d" % c):
			draw_arc(tc, tr + 2 + (1.0 - _pulses["t%d" % c] / 0.5) * 5, 0, TAU, 24,
				Color(1, 0.9, 0.5, _pulses["t%d" % c] / 0.5), 2.0, true)
		if p.tokens[c] > 0:
			GemDraw.draw_chip(self, c, tc, tr)
			GemDraw.text(self, str(p.tokens[c]), tc + Vector2(tr + 3, 8 * k), int(22 * k), Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		else:
			draw_arc(tc, tr - 2, 0, TAU, 28, faint, 1.5, true)
