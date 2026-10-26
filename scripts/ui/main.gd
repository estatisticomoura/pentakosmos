extends Control
## Raiz do jogo: fundo animado, palco de 1280x720 centralizado e troca de telas.

const BASE := Vector2(1280, 720)

var stage: Control
var _screen: Control = null
var _bg: TextureRect
var _dust: CPUParticles2D
var _rules: RuleSet
var _players: Array = []


func _ready() -> void:
	var vis := str(Store.get_value("visual", "tema", "solidos"))
	Defs.set_visual("poligonal" if vis == "gemas" else vis)
	L.set_lang(str(Store.get_value("geral", "idioma", "en")))
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	stage = Control.new()
	stage.size = BASE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(_layout)
	_layout()
	show_menu()
	Audio.start_music()


func _layout() -> void:
	stage.position = ((size - BASE) / 2.0).floor()
	if _bg:
		_bg.size = size
	if _dust:
		_dust.position = size / 2.0
		_dust.emission_rect_extents = size / 2.0


func _build_background() -> void:
	_bg = TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.40)
	gt.fill_to = Vector2(1.15, 1.15)
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(0.14, 0.17, 0.24), Color(0.025, 0.03, 0.045)])
	gt.gradient = gr
	gt.width = 512
	gt.height = 512
	_bg.texture = gt
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# poeira dourada flutuando (ambientacao)
	_dust = CPUParticles2D.new()
	_dust.amount = 36
	_dust.lifetime = 14.0
	_dust.preprocess = 14.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2(0, -1)
	_dust.spread = 40.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 4.0
	_dust.initial_velocity_max = 14.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 0.85, 0.5, 0.0), Color(1, 0.85, 0.5, 0.35), Color(1, 0.85, 0.5, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_dust.color_ramp = ramp
	add_child(_dust)


func _set_screen(s: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = s
	stage.add_child(s)
	s.modulate.a = 0.0
	create_tween().tween_property(s, "modulate:a", 1.0, 0.3)


func show_menu() -> void:
	var m := MenuScreen.new()
	m.start_game.connect(func(r, p):
		_rules = r
		_players = p
		show_game())
	m.show_text.connect(show_text)
	_set_screen(m)


func show_text(which: String) -> void:
	var t := TextScreen.new()
	t.which = which
	t.back.connect(show_menu)
	_set_screen(t)


func show_game() -> void:
	var gs := GameScreen.new()
	gs.back_to_menu.connect(show_menu)
	gs.restart.connect(show_game)
	_set_screen(gs)
	gs.start(_rules.copy(), _players.duplicate(true))
