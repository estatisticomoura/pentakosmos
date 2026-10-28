class_name OrbitView
extends Control
## Tela inicial: a esfera no centro, como um sol, e os cinco solidos em orbitas
## elipticas, como planetas. Quanto menos faces, mais perto da esfera:
## tetraedro (4), cubo (6), octaedro (8), dodecaedro (12), icosaedro (20).
## Cada solido gira em torno de si (rotacao) e da esfera (translacao).

# [cor, semi-eixo maior, excentricidade, angulo do periélio, fase inicial, raio do solido em px]
# (orbitas quase circulares e bem espacadas; o raio em px e o mesmo em qualquer tela)
const PLANETS := [
	[3, 0.26, 0.04, 0.4, 0.3, 34.0],     # tetraedro (fogo)
	[4, 0.43, 0.03, 2.1, 2.2, 35.0],     # cubo (terra)
	[0, 0.60, 0.05, 4.0, 4.1, 37.0],     # octaedro (ar)
	[2, 0.77, 0.03, 1.2, 0.9, 40.0],     # dodecaedro (eter)
	[1, 0.94, 0.04, 5.2, 5.6, 42.0],     # icosaedro (agua)
]
const TILT := 0.50          # achatamento da elipse vista em perspectiva
const ROLL := -0.12         # inclinacao do plano das orbitas na tela
const R_REF := 382.0        # raio de referencia: em areas menores, tudo encolhe junto
const SPEED := 0.55         # escala do tempo

var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _orbit_point(a: float, e: float, w: float, nu: float) -> Vector3:
	## Posicao no plano da orbita (a esfera fica num dos focos), em unidades de "R".
	var r := a * (1.0 - e * e) / (1.0 + e * cos(nu))
	var x := r * cos(nu + w)
	var z := r * sin(nu + w)
	return Vector3(x, 0.0, z)


func _project(p: Vector3, center: Vector2, R: float) -> Array:
	## [ponto na tela, profundidade (-1 longe .. 1 perto)]
	var y := p.z * TILT
	var q := Vector2(p.x, y).rotated(ROLL) * R
	return [center + q, clampf(p.z, -1.0, 1.0)]


func _draw() -> void:
	var center := size / 2.0
	var R := minf(size.x / 2.0, size.y / (2.0 * TILT + 0.5)) * 0.98
	var sun_r := 50.0 * minf(1.0, R / R_REF)
	# orbitas (linhas finas)
	for pl in PLANETS:
		var pts := PackedVector2Array()
		for k in range(97):
			var p := _orbit_point(pl[1], pl[2], pl[3], TAU * k / 96.0)
			pts.append(_project(p, center, R)[0])
		draw_polyline(pts, Color(1.0, 0.85, 0.5, 0.16), 1.6, true)
	# planetas: atras do sol, o sol, na frente do sol
	var items: Array = []
	for i in range(PLANETS.size()):
		var pl: Array = PLANETS[i]
		var a: float = pl[1]
		# translacao: orbitas mais externas sao mais lentas (como Kepler, suavizado)
		var n := SPEED * 0.9 / pow(a / 0.26, 1.3)
		var nu: float = pl[4] + _t * n
		var pr: Array = _project(_orbit_point(a, pl[2], pl[3], nu), center, R)
		items.append([pr[1], i, pr[0]])
	items.sort_custom(func(x, y): return x[0] < y[0])
	var sun_drawn := false
	for it in items:
		if not sun_drawn and it[0] >= 0.0:
			_draw_sun(center, sun_r)
			sun_drawn = true
		_draw_planet(it[1], it[2], it[0], R)
	if not sun_drawn:
		_draw_sun(center, sun_r)


func _draw_sun(c: Vector2, r: float) -> void:
	# brilho em volta
	for k in range(10, 0, -1):
		var f := k / 10.0
		draw_circle(c, r * (1.0 + 1.6 * f), Color(1.0, 0.85, 0.4, 0.035 * (1.0 - f) + 0.01))
	if Defs.visual == "solidos":
		GemDraw.draw_solid(self, Defs.GOLD, c, r, _t * 0.6)
	else:
		_flat(Defs.GOLD, c, r, _t * 0.25)


func _draw_planet(i: int, p: Vector2, depth: float, R: float) -> void:
	var pl: Array = PLANETS[i]
	var c: int = pl[0]
	# perto fica maior e mais claro; longe, menor e mais apagado
	var r: float = pl[5] * minf(1.0, R / R_REF) * (1.0 + 0.18 * depth)
	if Defs.visual == "solidos":
		GemDraw.draw_solid(self, c, p, r, _t * (0.9 + 0.15 * i) + i * 7.0)
	else:
		_flat(c, p, r, _t * (0.5 + 0.1 * i) + i)


func _flat(c: int, p: Vector2, r: float, ang: float) -> void:
	## Visual poligonal: a forma plana do elemento girando.
	var pts := GemDraw.shape_points(c, Vector2.ZERO, r)
	var out := PackedVector2Array()
	for q in pts:
		out.append(p + q.rotated(ang))
	draw_colored_polygon(out, Defs.COLORS[c])
	var closed := out.duplicate()
	closed.append(out[0])
	draw_polyline(closed, Color(1, 1, 1, 0.5), maxf(1.0, r * 0.07), true)
