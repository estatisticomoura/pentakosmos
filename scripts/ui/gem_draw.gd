class_name GemDraw
extends RefCounted
## Desenho dos simbolos de cada elemento: cada cor tem tambem uma forma propria (acessibilidade
## para daltonicos): branco = losango, azul = circulo, verde = triangulo,
## vermelho = quadrado, preto = hexagono, ouro = estrela.


static func shape_points(c: int, center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match c:
		0:
			pts = PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.82, 0),
				center + Vector2(0, r), center + Vector2(-r * 0.82, 0)])
		1:
			for i in range(24):
				var a := TAU * i / 24.0
				pts.append(center + Vector2(cos(a), sin(a)) * r * 0.9)
		2:
			var cc := center + Vector2(0, r * 0.12)
			pts = PackedVector2Array([cc + Vector2(0, -r), cc + Vector2(r * 0.95, r * 0.72),
				cc + Vector2(-r * 0.95, r * 0.72)])
		3:
			var s := r * 0.78
			pts = PackedVector2Array([center + Vector2(-s, -s), center + Vector2(s, -s),
				center + Vector2(s, s), center + Vector2(-s, s)])
		4:
			for i in range(6):
				var a := TAU * i / 6.0 + PI / 6.0
				pts.append(center + Vector2(cos(a), sin(a)) * r * 0.92)
		_:
			for i in range(10):
				var a := TAU * i / 10.0 - PI / 2.0
				var rr := r if i % 2 == 0 else r * 0.45
				pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return pts


static func draw_gem(ci: CanvasItem, c: int, center: Vector2, r: float, outline := true) -> void:
	## Forma preenchida com a cor (usada em custos e requisitos).
	if Defs.visual == "solidos":
		draw_solid(ci, c, center, r * 1.05, -1.0)
		return
	var pts := shape_points(c, center, r)
	var col: Color = Defs.COLORS[c]
	ci.draw_colored_polygon(pts, col)
	# brilho no topo
	var hl := PackedVector2Array()
	for p in pts:
		hl.append(center + (p - center) * 0.55 + Vector2(-r * 0.15, -r * 0.2))
	ci.draw_colored_polygon(hl, Color(1, 1, 1, 0.16))
	if outline:
		var oc := Color(1, 1, 1, 0.85) if c == 4 else col.darkened(0.45)
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, oc, 2.0, true)


static func draw_chip(ci: CanvasItem, c: int, center: Vector2, r: float) -> void:
	## Ficha redonda com a forma da cor gravada no centro.
	var col: Color = Defs.COLORS[c]
	if Defs.visual == "solidos":
		_solid_chip(ci, c, center, r)
		return
	var body := col.lightened(0.10) if c != 4 else col.lightened(0.12)
	ci.draw_circle(center + Vector2(0, 3), r, Color(0, 0, 0, 0.30))
	ci.draw_circle(center, r, col.darkened(0.12))
	ci.draw_circle(center, r * 0.86, body)
	# luz difusa no alto da ficha
	ci.draw_circle(center + Vector2(-0.18, -0.22) * r, r * 0.55, Color(1, 1, 1, 0.10))
	ci.draw_circle(center + Vector2(-0.24, -0.30) * r, r * 0.30, Color(1, 1, 1, 0.08))
	# marcas na borda, como fichas de poker
	for i in range(8):
		var a := TAU * i / 8.0
		var p := center + Vector2(cos(a), sin(a)) * r * 0.93
		ci.draw_circle(p, r * 0.09, Color(1, 1, 1, 0.65) if c != 0 else Color(0, 0, 0, 0.22))
	var ink: Color = Defs.INK[c]
	ink.a = 0.72 if c == Defs.GOLD else 0.55
	ci.draw_colored_polygon(shape_points(c, center, r * 0.5), ink)
	ci.draw_arc(center, r * 0.86, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.5), 2.0, true)


static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0, ocolor := Color(0, 0, 0, 0.8)) -> void:
	var f := ThemeDB.fallback_font
	if outline > 0:
		ci.draw_string_outline(f, pos, s, align, width, size, outline, ocolor)
	ci.draw_string(f, pos, s, align, width, size, color)


static func ctext(ci: CanvasItem, s: String, center: Vector2, size: int, color: Color, outline := 0) -> void:
	## Texto centrado (horizontal e verticalmente) num ponto.
	var f := ThemeDB.fallback_font
	var w := 200.0
	var asc := f.get_ascent(size)
	var desc := f.get_descent(size)
	var pos := Vector2(center.x - w / 2.0, center.y + (asc - desc) / 2.0)
	if outline > 0:
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, outline, Color(0, 0, 0, 0.85))
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, color)


static func rounded(ci: CanvasItem, rect: Rect2, bg: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	ci.draw_style_box(sb, rect)


static func glow(ci: CanvasItem, rect: Rect2, color: Color, strength: float, radius := 12) -> void:
	## Halo de selecao (varias bordas com transparencia crescente).
	for i in range(6):
		var grow := 2.0 + i * 3.0
		var c := color
		c.a = strength * (0.55 - i * 0.085)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.draw_center = false
		sb.border_color = c
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(radius + int(grow))
		sb.anti_aliasing = true
		ci.draw_style_box(sb, rect.grow(grow))


# --- visual "solidos platonicos" -------------------------------------------
# branco/ar = octaedro, azul/agua = icosaedro, verde/eter = dodecaedro,
# vermelho/fogo = tetraedro, preto/terra = cubo, ouro = esfera.

const PHI := 1.6180339887
const LIGHT := Vector3(-0.45, -0.65, 0.62)
static var _solids := {}


static func _verts(kind: int) -> Array:
	var v: Array = []
	match kind:
		3:  # tetraedro
			v = [Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)]
		4:  # cubo
			for x in [-1, 1]:
				for y in [-1, 1]:
					for z in [-1, 1]:
						v.append(Vector3(x, y, z))
		0:  # octaedro
			v = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
		1:  # icosaedro
			for a in [-1, 1]:
				for b in [-PHI, PHI]:
					v.append(Vector3(0, a, b))
					v.append(Vector3(a, b, 0))
					v.append(Vector3(b, 0, a))
		2:  # dodecaedro
			for x in [-1, 1]:
				for y in [-1, 1]:
					for z in [-1, 1]:
						v.append(Vector3(x, y, z))
			for a in [-1 / PHI, 1 / PHI]:
				for b in [-PHI, PHI]:
					v.append(Vector3(0, b, a))
					v.append(Vector3(b, a, 0))
					v.append(Vector3(a, 0, b))
	var out: Array = []
	for p in v:
		out.append((p as Vector3).normalized())
	return out


static func _solid(kind: int) -> Dictionary:
	## Vertices (raio 1) e faces; as normais das faces sao os vertices do dual.
	if _solids.has(kind):
		return _solids[kind]
	var dual := {3: 3, 4: 0, 0: 4, 1: 2, 2: 1}
	var vs := _verts(kind)
	var ns := _verts(dual[kind])
	if kind == 3:
		var neg: Array = []
		for n in ns:
			neg.append(-n)
		ns = neg
	var faces: Array = []
	for n in ns:
		var best := -2.0
		for v in vs:
			best = maxf(best, n.dot(v))
		var f: Array = []
		for i in range(vs.size()):
			if n.dot(vs[i]) > best - 0.01:
				f.append(i)
		# ordena os vertices em volta da normal
		var u: Vector3 = (vs[f[0]] - n * n.dot(vs[f[0]])).normalized()
		var w: Vector3 = n.cross(u)
		f.sort_custom(func(i, j): return atan2(vs[i].dot(w), vs[i].dot(u)) < atan2(vs[j].dot(w), vs[j].dot(u)))
		faces.append({"n": n, "f": f})
	var d := {"v": vs, "faces": faces}
	_solids[kind] = d
	return d


static func spin_time() -> float:
	return Time.get_ticks_msec() / 1000.0


const POSES := {0: [0.6, 0.42], 1: [1.5, 0.42], 2: [2.4, 0.42], 3: [0.785, -0.6], 4: [0.55, 0.5]}


static func draw_solid(ci: CanvasItem, c: int, center: Vector2, r: float, t := -1.0) -> void:
	## Solido sombreado. t < 0: pose fixa (custos nas cartas); senao gira devagar
	## e a luz passa lentamente, como um sol.
	var col: Color = Defs.COLORS[c]
	if c == Defs.GOLD:
		_draw_sphere(ci, center, r * (0.86 if t < 0.0 else 0.95), col, t)
		return
	var yaw: float = POSES[c][0]
	var pitch: float = POSES[c][1]
	var light := LIGHT
	if t >= 0.0:
		yaw = t * (0.55 + 0.05 * c) + c * 1.3
		pitch = 0.42 + 0.18 * sin(t * 0.37 + c)
		var la := t * 0.22 + c * 0.7
		light = Vector3(0.75 * cos(la), -0.45 + 0.25 * sin(la * 0.7), 0.6)
	draw_solid_pose(ci, c, center, r, yaw, pitch, light, t < 0.0)


static func draw_solid_pose(ci: CanvasItem, c: int, center: Vector2, r: float, yaw: float, pitch: float, light := LIGHT, icon := false) -> void:
	var col: Color = Defs.COLORS[c]
	if c == 4:
		col = col.lightened(0.22)  # a terra e muito escura: o cubo recebe um pouco mais de luz
	var sd := _solid(c)
	var basis := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)
	var scale := r * (1.12 if c == 3 else (1.02 if c == 4 else 1.0))
	var pts: Array = []
	for v in sd["v"]:
		pts.append(basis * (v as Vector3))
	var ln := light.normalized()
	for face in sd["faces"]:
		var n: Vector3 = basis * (face["n"] as Vector3)
		if n.z <= 0.02:
			continue
		var poly := PackedVector2Array()
		for i in face["f"]:
			var p: Vector3 = pts[i]
			poly.append(center + Vector2(p.x, p.y) * scale)
		var lit := clampf(n.dot(ln), 0.0, 1.0)
		var fc: Color
		if lit < 0.55:
			fc = col.darkened(0.30 * (1.0 - lit / 0.55))
		else:
			fc = col.lightened(0.38 * (lit - 0.55) / 0.45)
		# reflexo especular suave
		var spec := pow(maxf(0.0, (ln + Vector3(0, 0, 1)).normalized().dot(n)), 12.0)
		fc = fc.lerp(Color.WHITE, spec * 0.35)
		ci.draw_colored_polygon(poly, fc)
		var closed := poly.duplicate()
		closed.append(poly[0])
		ci.draw_polyline(closed, _edge_color(c, col, icon), maxf(1.0, r * (0.075 if icon else 0.06)), true)


static func _edge_color(c: int, col: Color, icon: bool) -> Color:
	## Arestas: ar (branco) com arestas pretas, terra com arestas claras;
	## nos icones das cartas as arestas sao mais escuras, para destacar a forma.
	if c == 0:
		return Color(0.04, 0.05, 0.08, 0.9)
	if c == 4:
		return Color(0.93, 0.80, 0.62, 0.95)
	if icon:
		return Color(col.darkened(0.6), 0.9)
	var e := col.lightened(0.55)
	e.a = 0.6
	return e


static func _draw_sphere(ci: CanvasItem, center: Vector2, r: float, col: Color, t: float) -> void:
	# esfera dourada e clara: degrade na direcao da luz, meridianos suaves e brilho
	var off := Vector2(-0.28, -0.32)
	if t >= 0.0:
		var la := t * 0.22 + 3.5
		off = Vector2(0.75 * cos(la), -0.45 + 0.25 * sin(la * 0.7)).normalized() * 0.42
	var gold := Color(1.0, 0.88, 0.30)
	ci.draw_circle(center, r, gold.darkened(0.08))
	var steps := 10
	for i in range(1, steps):
		var k := float(i) / steps
		var cc := center + off * r * k
		ci.draw_circle(cc, r * (1.0 - k * 0.82), gold.darkened(0.08 * (1.0 - k)).lightened(0.12 + 0.60 * k * k))
	var ph := (t if t >= 0.0 else 0.4) * 0.7
	for m in range(3):
		var a := fposmod(ph + m * PI / 3.0, PI)
		var rx := absf(cos(a)) * r
		if rx < 1.0:
			continue
		var pts := PackedVector2Array()
		for j in range(17):
			var th := -PI / 2.0 + PI * j / 16.0
			pts.append(center + Vector2(rx * cos(th) * (1 if sin(a) >= 0 else -1), r * sin(th)))
		ci.draw_polyline(pts, Color(0.75, 0.58, 0.10, 0.28), maxf(1.0, r * 0.045), true)
	ci.draw_arc(center, r, 0, TAU, 32, Color(0.70, 0.52, 0.08, 0.7), maxf(1.0, r * 0.05), true)
	ci.draw_circle(center + off * 1.05 * r, r * 0.17, Color(1, 1, 0.92, 0.75))


static func _solid_chip(ci: CanvasItem, c: int, center: Vector2, r: float) -> void:
	## Ficha com aro da cor, fundo iluminado e o solido girando por cima.
	var col: Color = Defs.COLORS[c]
	var rim := col if c != 4 else col.lightened(0.25)
	ci.draw_circle(center + Vector2(0, 3), r, Color(0, 0, 0, 0.30))
	ci.draw_circle(center, r, rim.darkened(0.15))
	var base := Color(0.25, 0.27, 0.33).lerp(col, 0.12 if c == 0 else (0.42 if c == Defs.GOLD else 0.30))
	ci.draw_circle(center, r * 0.84, base)
	ci.draw_circle(center + Vector2(-0.12, -0.15) * r, r * 0.62, base.lightened(0.10))
	ci.draw_circle(center + Vector2(-0.2, -0.25) * r, r * 0.34, base.lightened(0.18))
	ci.draw_arc(center, r * 0.92, 0, TAU, 40, rim.lightened(0.3), maxf(1.0, r * 0.07), true)
	draw_solid(ci, c, center, r * 0.70, spin_time())
