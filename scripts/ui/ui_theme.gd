class_name UITheme
extends RefCounted
## Tema visual dos controles (botoes, paineis, listas). Troque as cores aqui
## quando a direcao de arte final estiver definida.

const GOLD := Color(0.93, 0.76, 0.40)
const TEXT := Color(0.92, 0.92, 0.96)
const MUTED := Color(0.65, 0.68, 0.76)
const PANEL := Color(0.08, 0.09, 0.13, 0.94)

## Disposicao da mesa: "auto" (toque no celular, computador no resto), "pc" ou "toque".
const LAYOUTS := ["auto", "pc", "toque"]
const LAYOUT_NAMES := ["Auto layout", "Computer layout", "Touch layout"]  # tr
static var touch := false
## Tamanho do texto (Opcoes): Normal, Grande, Muito grande.
const TEXT_SIZES := ["Normal", "Large", "Extra large"]  # tr
const TEXT_SCALES := [1.0, 1.12, 1.25]
static var text_scale := 1.0


static func fs(n: int) -> int:
	return int(round(n * text_scale))


static func update_touch() -> void:
	var m := str(Store.get_value("geral", "interface", "auto"))
	touch = OS.has_feature("mobile") if m == "auto" else m == "toque"
	text_scale = TEXT_SCALES[clampi(int(Store.get_value("geral", "texto", 0)), 0, 2)]


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw := 0, radius := 8, pad := 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = fs(18)
	# botoes
	var normal := box(Color(0.16, 0.17, 0.23), Color(GOLD, 0.45), 1)
	var hover := box(Color(0.22, 0.23, 0.30), GOLD, 2)
	var pressed := box(Color(0.12, 0.12, 0.16), GOLD, 2)
	var disabled := box(Color(0.12, 0.12, 0.15, 0.6), Color(1, 1, 1, 0.08), 1)
	var focus := box(Color(0, 0, 0, 0), Color(GOLD, 0.7), 2)
	focus.draw_center = false
	for cls in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("disabled", cls, disabled)
		t.set_stylebox("focus", cls, focus)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 0.95, 0.8))
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.3))
	for cls in ["CheckButton", "CheckBox"]:
		var flat := box(Color(0, 0, 0, 0))
		t.set_stylebox("normal", cls, flat)
		t.set_stylebox("hover", cls, flat)
		t.set_stylebox("pressed", cls, flat)
	# caixa de selecao desenhada aqui (o tema padrao fica pequeno e some quando desmarcada)
	var sz := fs(30)
	t.set_icon("checked", "CheckBox", _check_icon(sz, true, false))
	t.set_icon("unchecked", "CheckBox", _check_icon(sz, false, false))
	t.set_icon("checked_disabled", "CheckBox", _check_icon(sz, true, true))
	t.set_icon("unchecked_disabled", "CheckBox", _check_icon(sz, false, true))
	t.set_constant("h_separation", "CheckBox", 12)
	# textos
	t.set_color("font_color", "Label", TEXT)
	# paineis
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(GOLD, 0.30), 1, 14, 18))
	t.set_stylebox("panel", "Panel", box(PANEL, Color(GOLD, 0.30), 1, 14))
	t.set_stylebox("panel", "PopupMenu", box(Color(0.10, 0.11, 0.15), Color(GOLD, 0.4), 1, 8, 6))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.25, 0.22, 0.15), Color(0, 0, 0, 0), 0, 6, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.95, 0.8))
	t.set_font_size("font_size", "PopupMenu", fs(21))
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_constant("item_start_padding", "PopupMenu", 12)
	t.set_constant("item_end_padding", "PopupMenu", 16)
	# campos
	var le := box(Color(0.06, 0.07, 0.10), Color(1, 1, 1, 0.15), 1, 6, 8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(Color(0.06, 0.07, 0.10), GOLD, 1, 6, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.1, 0.1, 0.14), GOLD, 1, 6, 8))
	# barras
	t.set_stylebox("slider", "HSlider", box(Color(0.2, 0.2, 0.26), Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("grabber_area", "HSlider", box(Color(GOLD, 0.7), Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color(0, 0, 0, 0), 0, 4, 2))
	return t


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, size := 18, min_size := Vector2(0, 44)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs(size))
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click"))
	return b


static func option(items: Array, selected := 0) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	if items.size() > 0:
		o.select(selected)
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(0, 40)
	return o


static func _check_icon(sz: int, on: bool, off: bool) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var a := 0.4 if off else 1.0
	var border := Color(GOLD, a)
	var w := maxi(2, sz / 14)
	for y in range(sz):
		for x in range(sz):
			var edge := x < w or y < w or x >= sz - w or y >= sz - w
			if edge:
				img.set_pixel(x, y, border)
			elif on:
				img.set_pixel(x, y, Color(0.24, 0.20, 0.10, a))
	if on:
		# marca de "certo"
		var pts := [Vector2(0.22, 0.52), Vector2(0.42, 0.72), Vector2(0.80, 0.30)]
		for k in range(2):
			var p0: Vector2 = pts[k] * sz
			var p1: Vector2 = pts[k + 1] * sz
			var n := int(p0.distance_to(p1) * 2)
			for i in range(n + 1):
				var p := p0.lerp(p1, float(i) / n)
				for dy in range(-w, w + 1):
					for dx in range(-w, w + 1):
						var x := int(p.x) + dx
						var y := int(p.y) + dy
						if x >= 0 and y >= 0 and x < sz and y < sz:
							img.set_pixel(x, y, Color(GOLD.lightened(0.2), a))
	return ImageTexture.create_from_image(img)
