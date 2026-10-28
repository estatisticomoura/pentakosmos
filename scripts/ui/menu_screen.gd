class_name MenuScreen
extends Control
## Menu em paginas: inicio (sistema solar dos solidos e botoes), nova partida
## (jogadores e regras), customizar regras, opcoes e idioma.

signal start_game(rules: RuleSet, players: Array)
signal show_text(which: String)   # "rules" (como jogar) ou "story" (processo criativo)

# Textos em ingles; L.t() traduz na hora de mostrar.
# Rotulos "free" (exato, -1 ... -5 livre) e "time" (sem limite, 20 s ...) sao gerados na hora.
# "num": campo numerico com - e + (minimo, maximo).
const OPTIONS := [
	["Deck", "deck", ["caio", "arcaico"], ["Pentakosmos", "Archaic"]],  # tr
	["Solids per element", "gems_mode", ["classico", "house"], ["Archaic (4/5/7/8)", "Pentakosmos (4/6/7/8)"]],  # tr
	["Spheres (jokers)", "gold_mode", ["classico", "house"], ["Archaic (5)", "Pentakosmos (4/5/6/7)"]],  # tr
	["Take 2 of a kind", "take2_min", [4, 3], ["Pile of 4 or more", "Pile of 3 or more"]],  # tr
	["Market with 5 players", "market5", [4, 5], ["4 cards per group", "5 cards per group"]],  # tr
	["Academy", "patrons", ["ambos", "filosofos", "escritores", "nenhum"],  # tr
		["Philosophers and writers", "Philosophers only", "Writers only", "No bonus"]],  # tr
	["Philosopher requirement", "noble_free", [0, 1, 2, 3, 4, 5], "free"],  # tr
	["Philosopher points", "noble_points_mode", ["fixo", "decrescente"], ["3 each", "3 / 2 / 1"]],  # tr
	["Writer requirement", "writer_free", [0, 1, 2, 3, 4, 5], "free"],  # tr
	["Token hand limit", "hand_limit", [9, 10, 11], ["9", "10", "11"]],  # tr
	["Points to win", "target", [10, 25], "num"],  # tr
	["Specialization victory", "color_win", [0, 9, 10, 11, 12],  # tr
		["Off", "9 pts in one element", "10 pts in one element", "11 pts in one element", "12 pts in one element"]],  # tr
	["Time per move against AIs", "time_ai", [0, 20, 30, 45, 60, 90, 120], "time"],  # tr
	["Time per move between humans", "time_humans", [0, 20, 30, 45, 60, 90, 120], "time"],  # tr
]
const KINDS := ["humano", "facil", "normal", "intermediaria", "dificil", "muito_dificil"]
# nomes no seletor: "Human" e os personagens da IA (Defs.PERSONAS), do mais fraco ao mais forte
const OLD_DEFAULTS := ["Você", "Lívia", "Otávio", "Júlia", "Marco"]   # nomes padrao de versoes antigas
const AI_DELAYS := [1.1, 0.6, 0.2]
static var _default_pool := []
static var start_page := "home"     # pagina mostrada ao voltar de outra tela

var rules: RuleSet
var page := "home"
var _rules_back := "home"     # de onde se chegou em "customizar regras"
var _players: Array = []      # [{name, kind}] (ate 5)
var _count := 3
var _presets: Array = []      # [nome, RuleSet, custom:bool]
var _preset_opt: OptionButton
var _opt_controls: Array = []
var _summary: Label
var _preset_name: LineEdit
var _del_btn: Button
var _count_btns: Array = []
var _rows: Array = []         # [HBox, LineEdit, OptionButton]
var _note: Label
var _updating := false


func _init() -> void:
	size = Vector2(1280, 720)


func _ready() -> void:
	var saved = Store.get_value("setup", "rules", null)
	rules = RuleSet.from_dict(saved) if saved is Dictionary else RuleSet.house_full()
	_load_players()
	show_page(start_page)
	start_page = "home"


func _notification(what: int) -> void:
	# botao "voltar" do Android
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	match page:
		"home":
			if OS.has_feature("mobile"):
				get_tree().quit()
		"rules":
			show_page(_rules_back)
		_:
			show_page("home")


func show_page(p: String) -> void:
	if page == "setup" and not _rows.is_empty():
		_players = _current_players()
		_save_setup()
	if page == "rules":
		_save_setup()
	page = p
	for ch in get_children():
		ch.queue_free()
	_opt_controls = []
	_rows = []
	_count_btns = []
	_preset_opt = null
	match p:
		"setup":
			_build_setup()
		"rules":
			_build_rules()
		"opcoes":
			_build_options()
		"language":
			_build_language()
		_:
			_build_home()


func _save_setup() -> void:
	Store.set_value("setup", "rules", rules.to_dict())
	Store.set_value("setup", "players", _players.slice(0, _count))


# ---------------------------------------------------------------------------
# Paginas
# ---------------------------------------------------------------------------
func _title(text: String, y := 22.0, sz := 40) -> Label:
	var t := UITheme.label(text, sz, UITheme.GOLD)
	t.position = Vector2(0, y)
	t.size = Vector2(1280, sz + 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 6)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(t)
	return t


func _back_button(target := "") -> Button:
	var b := UITheme.button(L.t("Back"), 22, Vector2(200, 60))
	b.position = Vector2(40, 640)
	b.pressed.connect(func(): show_page(target) if target != "" else _go_back())
	add_child(b)
	return b


func _build_home() -> void:
	var orbit := OrbitView.new()
	# em telas mais largas que 16:9 (celulares) o sistema solar usa tambem a margem esquerda
	var margin := maxf(0.0, (get_viewport_rect().size.x - 1280.0) / 2.0)
	orbit.position = Vector2(-margin, 0)
	orbit.size = Vector2(790 + margin, 720)
	add_child(orbit)
	var title := UITheme.label("PENTAKOSMOS", 60, UITheme.GOLD)
	title.position = Vector2(780, 66)
	title.size = Vector2(470, 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(title)
	var col := VBoxContainer.new()
	col.position = Vector2(815, 158)
	col.custom_minimum_size = Vector2(400, 0)
	col.add_theme_constant_override("separation", 11)
	add_child(col)
	var play := UITheme.button(L.t("Play"), 32, Vector2(400, 78))
	play.add_theme_color_override("font_color", UITheme.GOLD)
	play.pressed.connect(func(): show_page("setup"))
	col.add_child(play)
	for it in [["Customize rules", _open_rules_from_home],  # tr
			["Statistics", func(): show_text.emit("stats")],  # tr
			["How to play", func(): show_text.emit("rules")],  # tr
			["Creative process", func(): show_text.emit("story")],  # tr
			["Options", func(): show_page("opcoes")]]:  # tr
		var b := UITheme.button(L.t(it[0]), 23, Vector2(400, 56))
		b.pressed.connect(it[1])
		col.add_child(b)
	# idioma e visual: um toque
	var row := HBoxContainer.new()
	row.position = Vector2(815, 618)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var lang_cap := L.t("Language") if L.code == "en" else L.t("Language") + " · Language"
	var lb := _two_line_button(lang_cap, L.LANGS[L.index()][1])
	lb.pressed.connect(func(): show_page("language"))
	row.add_child(lb)
	var vb := _two_line_button(L.t("Visual"), L.t(Defs.VISUAL_NAMES[maxi(0, Defs.VISUALS.find(Defs.visual))]))
	vb.pressed.connect(func():
		var i := (Defs.VISUALS.find(Defs.visual) + 1) % Defs.VISUALS.size()
		Defs.set_visual(Defs.VISUALS[i])
		Store.set_value("visual", "tema", Defs.VISUALS[i])
		show_page("home"))
	row.add_child(vb)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		var quit := UITheme.button(L.t("Quit"), 18, Vector2(110, 44))
		quit.position = Vector2(1150, 12)
		quit.pressed.connect(func(): get_tree().quit())
		add_child(quit)


func _open_rules_from_home() -> void:
	_rules_back = "home"
	show_page("rules")


func _two_line_button(cap: String, value: String) -> Button:
	## Botao com legenda pequena em cima e o valor atual embaixo.
	var b := UITheme.button("", 20, Vector2(194, 76))
	b.clip_contents = true
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := UITheme.label(cap, 14, UITheme.MUTED)
	var t := UITheme.label(value, 20, UITheme.TEXT)
	for l in [c, t]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	b.add_child(v)
	return b


func _build_setup() -> void:
	_title(L.t("New game"))
	# --- jogadores ---
	var left := PanelContainer.new()
	left.position = Vector2(40, 96)
	left.size = Vector2(770, 526)
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(lv)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 10)
	var pl := UITheme.label(L.t("Players"), 26, UITheme.GOLD)
	pl.custom_minimum_size = Vector2(170, 0)
	ch.add_child(pl)
	for n in range(2, 6):
		var b := UITheme.button(str(n), 24, Vector2(64, 54))
		b.toggle_mode = true
		b.pressed.connect(func():
			_count = n
			_update_rows())
		ch.add_child(b)
		_count_btns.append(b)
	lv.add_child(ch)
	for i in range(5):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var num := UITheme.label("%d." % (i + 1), 22, UITheme.MUTED)
		num.custom_minimum_size = Vector2(32, 0)
		row.add_child(num)
		var le := LineEdit.new()
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.max_length = 16
		le.custom_minimum_size = Vector2(0, 54)
		le.add_theme_font_size_override("font_size", UITheme.fs(22))
		row.add_child(le)
		var kind := UITheme.option(_kind_names(), 0)
		kind.custom_minimum_size = Vector2(260, 54)
		kind.add_theme_font_size_override("font_size", UITheme.fs(22))
		kind.item_selected.connect(_on_kind_changed.bind(i))
		row.add_child(kind)
		lv.add_child(row)
		_rows.append([row, le, kind])
	_note = UITheme.label("", 16, Color(1.0, 0.75, 0.5))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(700, 0)
	lv.add_child(_note)
	# --- regras ---
	var right := PanelContainer.new()
	right.position = Vector2(830, 96)
	right.size = Vector2(410, 526)
	add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	right.add_child(rv)
	rv.add_child(UITheme.label(L.t("Rules"), 26, UITheme.GOLD))
	_preset_opt = UITheme.option([])
	_preset_opt.custom_minimum_size = Vector2(0, 56)
	_preset_opt.add_theme_font_size_override("font_size", UITheme.fs(22))
	_preset_opt.item_selected.connect(_on_preset_selected)
	rv.add_child(_preset_opt)
	_summary = UITheme.label("", 17, UITheme.MUTED)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(350, 0)
	var ssc := ScrollContainer.new()
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ssc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ssc.custom_minimum_size = Vector2(0, 120)
	ssc.add_child(_summary)
	rv.add_child(ssc)
	var cust := UITheme.button(L.t("Customize rules"), 22, Vector2(0, 60))
	cust.pressed.connect(func():
		_rules_back = "setup"
		show_page("rules"))
	rv.add_child(cust)
	# --- rodape ---
	_back_button("home")
	var start := UITheme.button(L.t("Start game"), 30, Vector2(380, 72))
	start.position = Vector2(860, 634)
	start.add_theme_color_override("font_color", UITheme.GOLD)
	start.pressed.connect(_on_play)
	add_child(start)
	_apply_players(_players)
	_reload_presets()
	_sync_from_rules()


func _build_rules() -> void:
	_title(L.t("Customize rules"), 18, 36)
	var ph := HBoxContainer.new()
	ph.position = Vector2(60, 84)
	ph.custom_minimum_size = Vector2(1160, 0)
	ph.add_theme_constant_override("separation", 14)
	add_child(ph)
	ph.add_child(UITheme.label(L.t("Preset"), 22, UITheme.GOLD))
	_preset_opt = UITheme.option([])
	_preset_opt.custom_minimum_size = Vector2(0, 52)
	_preset_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_opt.add_theme_font_size_override("font_size", UITheme.fs(22))
	_preset_opt.item_selected.connect(_on_preset_selected)
	ph.add_child(_preset_opt)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 146)
	scroll.size = Vector2(1200, 482)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for i in range(OPTIONS.size()):
		var o: Array = OPTIONS[i]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var lab := UITheme.label(L.t(o[0]), 18, UITheme.MUTED)
		lab.custom_minimum_size = Vector2(372, 0)
		lab.clip_text = true
		cell.add_child(lab)
		if typeof(o[3]) == TYPE_STRING and o[3] == "num":
			var nf := _number_field(i)
			cell.add_child(nf)
			_opt_controls.append(nf)
		else:
			var ob := UITheme.option(option_labels(o))
			ob.custom_minimum_size = Vector2(372, 48)
			ob.clip_text = true
			ob.fit_to_longest_item = false
			ob.add_theme_font_size_override("font_size", UITheme.fs(20))
			ob.item_selected.connect(_on_option_changed.bind(i))
			cell.add_child(ob)
			_opt_controls.append(ob)
		grid.add_child(cell)
	_summary = null
	_back_button()
	var sh := HBoxContainer.new()
	sh.position = Vector2(300, 640)
	sh.add_theme_constant_override("separation", 12)
	add_child(sh)
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = L.t("Preset name")
	_preset_name.custom_minimum_size = Vector2(500, 60)
	_preset_name.add_theme_font_size_override("font_size", UITheme.fs(20))
	sh.add_child(_preset_name)
	var save := UITheme.button(L.t("Save"), 20, Vector2(190, 60))
	save.pressed.connect(_on_save_preset)
	sh.add_child(save)
	_del_btn = UITheme.button(L.t("Delete"), 20, Vector2(190, 60))
	_del_btn.pressed.connect(_on_delete_preset)
	sh.add_child(_del_btn)
	_reload_presets()
	_sync_from_rules()


func _number_field(opt_i: int) -> HBoxContainer:
	## Campo numerico com - e +; tocar no numero abre o teclado (aceita do minimo ao maximo).
	var o: Array = OPTIONS[opt_i]
	var lo: int = o[2][0]
	var hi: int = o[2][1]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var minus := UITheme.button("−", 26, Vector2(64, 48))
	var le := LineEdit.new()
	le.name = "Num"
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.custom_minimum_size = Vector2(220, 48)
	le.add_theme_font_size_override("font_size", UITheme.fs(24))
	le.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	le.max_length = 3
	var plus := UITheme.button("+", 26, Vector2(64, 48))
	var apply := func(v: int):
		var c := clampi(v, lo, hi)
		rules.set(o[1], c)
		le.text = str(c)
		_sync_from_rules()
	minus.pressed.connect(func(): apply.call(int(rules.get(o[1])) - 1))
	plus.pressed.connect(func(): apply.call(int(rules.get(o[1])) + 1))
	le.text_submitted.connect(func(t: String): apply.call(int(t) if t.is_valid_int() else int(rules.get(o[1]))))
	le.focus_exited.connect(func(): apply.call(int(le.text) if le.text.is_valid_int() else int(rules.get(o[1]))))
	h.add_child(minus)
	h.add_child(le)
	h.add_child(plus)
	return h


func _build_options() -> void:
	_title(L.t("Options"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(200, 96)
	scroll.size = Vector2(880, 530)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(864, 0)
	scroll.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UITheme.label(L.t("Audio"), 26, UITheme.GOLD))
	v.add_child(_row(L.t("Music"), _slider("Music")))
	var picker := MusicPicker.make()
	picker.custom_minimum_size = Vector2(0, 52)
	picker.add_theme_font_size_override("font_size", UITheme.fs(20))
	v.add_child(_row(L.t("Playlist"), picker))
	v.add_child(_row(L.t("Effects"), _slider("SFX")))
	v.add_child(HSeparator.new())
	v.add_child(UITheme.label(L.t("Game"), 26, UITheme.GOLD))
	var delay: float = Store.get_value("game", "ai_delay", 0.6)
	var so := _big_option([L.t("Slow"), L.t("Normal"), L.t("Fast")], maxi(0, AI_DELAYS.find(delay)) if AI_DELAYS.has(delay) else 1)
	so.item_selected.connect(func(i): Store.set_value("game", "ai_delay", AI_DELAYS[i]))
	v.add_child(_row(L.t("AI speed"), so))
	var reveal := str(Store.get_value("game", "reserva_visivel", "rodada"))
	var ro := _big_option([L.t("From the last turn"), L.t("Always visible")], 1 if reveal == "sempre" else 0)
	ro.item_selected.connect(func(i): Store.set_value("game", "reserva_visivel", ["rodada", "sempre"][i]))
	v.add_child(_row(L.t("See reserves"), ro))
	var io := _big_option(UITheme.LAYOUT_NAMES.map(func(x): return L.t(x)),
		maxi(0, UITheme.LAYOUTS.find(str(Store.get_value("geral", "interface", "auto")))))
	io.item_selected.connect(func(i): Store.set_value("geral", "interface", UITheme.LAYOUTS[i]))
	v.add_child(_row(L.t("Table layout"), io))
	var ts := _big_option(UITheme.TEXT_SIZES.map(func(x): return L.t(x)), clampi(int(Store.get_value("geral", "texto", 0)), 0, 2))
	ts.item_selected.connect(func(i):
		Store.set_value("geral", "texto", i)
		var n: Node = self
		while n != null and not n.has_method("refresh_theme"):
			n = n.get_parent()
		if n != null:
			n.refresh_theme()
		else:
			UITheme.update_touch()
		show_page.call_deferred("opcoes"))
	v.add_child(_row(L.t("Text size"), ts))
	_back_button("home")


func _row(text: String, ctl: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UITheme.label(text, 21, UITheme.TEXT)
	l.custom_minimum_size = Vector2(290, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctl)
	return h


func _big_option(items: Array, sel: int) -> OptionButton:
	var o := UITheme.option(items, sel)
	o.custom_minimum_size = Vector2(0, 52)
	o.add_theme_font_size_override("font_size", UITheme.fs(20))
	o.item_selected.connect(func(_i): Audio.play("select"))
	return o


func _slider(bus: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Audio.get_volume(bus)
	s.custom_minimum_size = Vector2(0, 52)
	s.value_changed.connect(func(x): Audio.set_volume(bus, x))
	s.drag_ended.connect(func(_c): Audio.save_volumes(); Audio.play("select"))
	return s


func _build_language() -> void:
	_title(L.t("Language") if L.code == "en" else L.t("Language") + " · Language", 18, 36)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(40, 82)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for i in range(L.LANGS.size()):
		var b := UITheme.button(L.LANGS[i][1], 20, Vector2(292, 48))
		if i == L.index():
			b.add_theme_color_override("font_color", UITheme.GOLD)
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.22, 0.20, 0.14), UITheme.GOLD, 2))
		var code: String = L.LANGS[i][0]
		b.pressed.connect(func():
			L.set_lang(code)
			Store.set_value("geral", "idioma", code)
			show_page("home"))
		grid.add_child(b)
	_back_button("home")


# ---------------------------------------------------------------------------
# Jogadores
# ---------------------------------------------------------------------------
static func option_labels(o: Array) -> Array:
	match o[3]:
		"free":
			return o[2].map(func(k): return L.t("Exact") if k == 0 else L.f("Total −{n}, any elements", {"n": k}))
		"time":
			return o[2].map(func(t): return L.t("No limit") if t == 0 else L.f("{n} s", {"n": t}))
	return o[3].map(func(x): return L.t(x))


func _current_players() -> Array:
	var out: Array = []
	for i in range(5):
		out.append({"name": _rows[i][1].text, "kind": KINDS[_rows[i][2].selected]})
	return out


func _apply_players(saved: Array) -> void:
	for i in range(5):
		var kind: String = saved[i].get("kind", "normal") if i < saved.size() else ("humano" if i == 0 else "normal")
		_rows[i][2].select(maxi(KINDS.find(kind), 0))
	for i in range(5):
		var kind: String = KINDS[_rows[i][2].selected]
		var nm: String = saved[i].get("name", "") if i < saved.size() else ""
		# nomes padrao acompanham o idioma e o adversario escolhido
		_rows[i][1].text = _default_name(i, kind) if _is_default_name(nm) else nm
	_update_rows()


func _kind_names() -> Array:
	var out: Array = [L.t("Human")]
	for k in KINDS.slice(1):
		out.append(L.t(Defs.PERSONAS[k]))
	return out


func _default_name(i: int, kind: String) -> String:
	if kind == "humano":
		return L.t("You") if i == 0 else L.f("Player {n}", {"n": i + 1})
	var base := L.t(Defs.PERSONAS[kind])
	# dois adversarios iguais: "Crito", "Crito 2"
	var same := 0
	for j in range(i):
		if j < _rows.size() and KINDS[_rows[j][2].selected] == kind:
			same += 1
	return base if same == 0 else "%s %d" % [base, same + 1]


func _is_default_name(nm: String) -> bool:
	## Nome padrao em qualquer idioma (para trocar junto com o idioma ou o adversario).
	if nm.strip_edges() == "":
		return true
	if _default_pool.is_empty():
		var cur := L.code
		_default_pool.append_array(OLD_DEFAULTS)
		for l in L.LANGS:
			L.set_lang(l[0])
			_default_pool.append(L.t("You"))
			for n in range(1, 6):
				_default_pool.append(L.f("Player {n}", {"n": n}))
			for k in Defs.PERSONAS:
				_default_pool.append(L.t(Defs.PERSONAS[k]))
		L.set_lang(cur)
	var base := nm.strip_edges()
	var parts := base.rsplit(" ", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		base = parts[0]
	return nm in _default_pool or base in _default_pool


func _on_kind_changed(sel: int, i: int) -> void:
	Audio.play("select")
	if _is_default_name(_rows[i][1].text):
		_rows[i][1].text = _default_name(i, KINDS[sel])


func _update_rows() -> void:
	if _rows.is_empty():
		return
	for i in range(5):
		_rows[i][0].visible = i < _count
	for k in range(_count_btns.size()):
		var on := k + 2 == _count
		_count_btns[k].set_pressed_no_signal(on)
		_count_btns[k].add_theme_color_override("font_color", UITheme.GOLD if on else UITheme.TEXT)
	var notes: Array = []
	if _count == 5:
		if rules.market5 == 4:
			notes.append(L.t("With 5 players, a 5-card market per level is recommended."))
		if rules.deck == "arcaico":
			notes.append(L.t("With the Archaic deck and 5 players, the basic cards often run out."))
	if _note:
		_note.text = " ".join(notes)


func _load_players() -> void:
	var saved = Store.get_value("setup", "players", null)
	if saved is Array and saved.size() >= 2:
		_players = saved.duplicate(true)
		_count = clampi(saved.size(), 2, 5)
	else:
		_players = []
		_count = 3
	# completa ate 5 (as linhas escondidas guardam os ultimos nomes usados)
	while _players.size() < 5:
		_players.append({"name": "", "kind": "humano" if _players.is_empty() else "normal"})


func _on_play() -> void:
	_players = _current_players()
	var players: Array = []
	for i in range(_count):
		var nm: String = _rows[i][1].text.strip_edges()
		if nm == "":
			nm = _default_name(i, KINDS[_rows[i][2].selected])
		players.append({"name": nm, "kind": KINDS[_rows[i][2].selected]})
	Store.set_value("setup", "rules", rules.to_dict())
	Store.set_value("setup", "players", players)
	start_game.emit(rules.copy(), players)


# ---------------------------------------------------------------------------
# Predefinicoes de regras
# ---------------------------------------------------------------------------
func _reload_presets() -> void:
	_presets = []
	for p in RuleSet.builtin_presets():
		_presets.append([p[0], p[1], false])
	var custom := Store.custom_presets()
	for name in custom:
		_presets.append([name, RuleSet.from_dict(custom[name]), true])
	_preset_opt.clear()
	for p in _presets:
		_preset_opt.add_item((p[0] + " ★") if p[2] else L.t(p[0]))
	_preset_opt.add_item(L.t("Custom"))


func _on_preset_selected(i: int) -> void:
	if i >= _presets.size():
		return
	rules = (_presets[i][1] as RuleSet).copy()
	_sync_from_rules()
	Audio.play("select")


func _on_option_changed(sel: int, opt_i: int) -> void:
	if _updating:
		return
	var o: Array = OPTIONS[opt_i]
	rules.set(o[1], o[2][sel])
	Audio.play("select")
	_sync_from_rules()


func _sync_from_rules() -> void:
	_updating = true
	for i in range(_opt_controls.size()):
		var o: Array = OPTIONS[i]
		if _opt_controls[i] is OptionButton:
			var idx: int = o[2].find(rules.get(o[1]))
			_opt_controls[i].select(maxi(idx, 0))
		elif _opt_controls[i] != null:
			var le: LineEdit = _opt_controls[i].get_node("Num")
			if not le.has_focus():
				le.text = str(rules.get(o[1]))
	var match_i := _presets.size()
	for i in range(_presets.size()):
		if (_presets[i][1] as RuleSet).equals(rules):
			match_i = i
			break
	if _preset_opt:
		_preset_opt.select(match_i)
	if _del_btn and is_instance_valid(_del_btn):
		_del_btn.disabled = not (match_i < _presets.size() and _presets[match_i][2])
	if _summary and is_instance_valid(_summary):
		_summary.text = rules.summary().replace(" · ", "\n")
	_updating = false
	_update_rows()


func _on_save_preset() -> void:
	var name := _preset_name.text.strip_edges()
	if name == "":
		Audio.play("error")
		_preset_name.placeholder_text = L.t("Type a name first")
		return
	Store.save_custom_preset(name, rules)
	_preset_name.text = ""
	_reload_presets()
	_sync_from_rules()
	Audio.play("reserve")


func _on_delete_preset() -> void:
	var i := _preset_opt.selected
	if i < _presets.size() and _presets[i][2]:
		Store.delete_custom_preset(_presets[i][0])
		_reload_presets()
		_sync_from_rules()
