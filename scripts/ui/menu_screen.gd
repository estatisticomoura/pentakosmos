class_name MenuScreen
extends Control
## Menu em paginas: inicio (sistema solar dos solidos e botoes), nova partida
## (jogadores e regras), customizar regras, opcoes e idioma.

signal start_game(rules: RuleSet, players: Array)
signal show_text(which: String)   # "rules" (como jogar) ou "story" (processo criativo)

# Textos em ingles; L.t() traduz na hora de mostrar.
# Cada regra: [rotulo, valores, rotulos] ou [rotulo, valores, "free"/"time"/"num"], ou
# [rotulo, "check"] (caixa de selecao) ou [rotulo, "content:<tipo>"] (deck ou conjunto).
const OPT := {
	"target": ["Points to win", [1, 100], "num"],  # tr
	"color_win": ["Specialization victory", [0, 9, 10, 11, 12],  # tr
		["Off", "9 pts in one element", "10 pts in one element", "11 pts in one element", "12 pts in one element"]],  # tr
	"hand_limit": ["Token hand limit", [9, 10, 11], ["9", "10", "11"]],  # tr
	"see_reserves": ["Opponents' reserves", ["rodada", "sempre"], ["Visible until their next turn", "Always visible"]],  # tr
	"gems_mode": ["Solids per element", ["classico", "house"], ["Archaic (4/5/7/8)", "Pentakosmos (4/6/7/8)"]],  # tr
	"gold_mode": ["Spheres (jokers)", ["classico", "house"], ["Archaic (5)", "Pentakosmos (4/5/6/7)"]],  # tr
	"take2_min": ["Take 2 of a kind", [4, 3], ["Pile of 4 or more", "Pile of 3 or more"]],  # tr
	"deck": ["Deck", "content:decks"],  # tr
	"market5": ["Market with 5 players", [4, 5], ["4 cards per group", "5 cards per group"]],  # tr
	"philosophers": ["Philosophers", "check"],  # tr
	"phil_set": ["Set of philosophers", "content:philosophers"],  # tr
	"noble_free": ["Philosopher requirement", [0, 1, 2, 3, 4, 5], "free"],  # tr
	"noble_points_mode": ["Philosopher points", ["fixo", "decrescente"], ["3 each", "3 / 2 / 1"]],  # tr
	"writers": ["Writers", "check"],  # tr
	"writer_set": ["Set of writers", "content:writers"],  # tr
	"writer_free": ["Writer requirement", [0, 1, 2, 3, 4, 5], "free"],  # tr
	"governors": ["Governors", "check"],  # tr
	"gov_set": ["Set of governors", "content:governors"],  # tr
	"gov_pick": ["How governors reach the table", ["escolha", "sorteio"], ["Each player chooses one (30 s)", "Drawn at random"]],  # tr
	"gov_target": ["Goal for players without a governor", [1, 100], "num"],  # tr
	"time_ai": ["Time per move against AIs", [0, 20, 30, 45, 60, 90, 120], "time"],  # tr
	"time_humans": ["Time per move between humans", [0, 20, 30, 45, 60, 90, 120], "time"],  # tr
}
const TABS := [
	["Game", ["target", "color_win", "hand_limit", "see_reserves"]],  # tr
	["Tokens", ["gems_mode", "gold_mode", "take2_min"]],  # tr
	["Cards", ["deck", "market5"]],  # tr
	["Academy", ["philosophers", "phil_set", "noble_free", "noble_points_mode", "writers", "writer_set", "writer_free"]],  # tr
	["Governors", ["governors", "gov_set", "gov_pick", "gov_target"]],  # tr
	["Time", ["time_ai", "time_humans"]],  # tr
]
const DEPENDS := {"phil_set": "philosophers", "noble_free": "philosophers", "noble_points_mode": "philosophers",
	"writer_set": "writers", "writer_free": "writers", "gov_set": "governors", "gov_pick": "governors",
	"gov_target": "governors"}
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
var _ctl := {}                # chave da regra -> controle
var _row_bg := {}             # chave da regra -> fundo (degrade vermelho quando foge do habitual)
var _row_box := {}            # chave da regra -> linha inteira
var _tab_btns: Array = []
var _status: Label
var _msg: Label
static var _tab := 0
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
	_ctl = {}
	_row_bg = {}
	_row_box = {}
	_tab_btns = []
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
	col.add_theme_constant_override("separation", 9)
	add_child(col)
	var play := UITheme.button(L.t("Play"), 32, Vector2(400, 78))
	play.add_theme_color_override("font_color", UITheme.GOLD)
	play.pressed.connect(func(): show_page("setup"))
	col.add_child(play)
	for it in [["Customize rules", _open_rules_from_home],  # tr
			["Customize", func(): show_text.emit("custom")],  # tr
			["Statistics", func(): show_text.emit("stats")],  # tr
			["How to play", func(): show_text.emit("rules")],  # tr
			["Creative process", func(): show_text.emit("story")],  # tr
			["Options", func(): show_page("opcoes")]]:  # tr
		var b := UITheme.button(L.t(it[0]), 23, Vector2(400, 50))
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
	_title(L.t("Customize rules"), 12, 34)
	# predefinicao, situacao e "restaurar tudo"
	var ph := HBoxContainer.new()
	ph.position = Vector2(40, 62)
	ph.custom_minimum_size = Vector2(1200, 0)
	ph.add_theme_constant_override("separation", 14)
	add_child(ph)
	ph.add_child(UITheme.label(L.t("Preset"), 22, UITheme.GOLD))
	_preset_opt = UITheme.option([])
	_preset_opt.custom_minimum_size = Vector2(440, 50)
	_preset_opt.add_theme_font_size_override("font_size", UITheme.fs(21))
	_preset_opt.item_selected.connect(_on_preset_selected)
	ph.add_child(_preset_opt)
	_status = UITheme.label("", 17, UITheme.MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ph.add_child(_status)
	var reset := UITheme.button(L.t("Restore defaults"), 18, Vector2(230, 50))
	reset.pressed.connect(func():
		rules = RuleSet.house_full()
		Audio.play("select")
		_sync_from_rules())
	ph.add_child(reset)
	# abas
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(40, 124)
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	for i in range(TABS.size()):
		var b := UITheme.button(L.t(TABS[i][0]), 19, Vector2(194, 50))
		b.clip_text = true
		var k := i
		b.pressed.connect(func():
			_tab = k
			Audio.play("select")
			show_page("rules"))
		tabs.add_child(b)
		_tab_btns.append(b)
	# conteudo da aba
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 182)
	panel.size = Vector2(1200, 446)
	add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(1160, 0)
	sc.add_child(v)
	_tab = clampi(_tab, 0, TABS.size() - 1)
	for key in TABS[_tab][1]:
		v.add_child(_rule_row(key))
	if TABS[_tab][0] == "Game":
		var note := UITheme.label(L.t("With governors, the goal of each player is set in the Governors tab."), 15, UITheme.MUTED)
		note.name = "GovNote"
		v.add_child(note)
	var tab_reset := UITheme.button(L.t("Restore this tab"), 17, Vector2(240, 44))
	tab_reset.pressed.connect(func():
		var base := RuleSet.house_full()
		for key in TABS[_tab][1]:
			rules.set(key, base.get(key))
		Audio.play("select")
		_sync_from_rules())
	var tr := HBoxContainer.new()
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(tab_reset)
	v.add_child(tr)
	# rodape: voltar, salvar/apagar predefinicao, exportar/importar
	_back_button()
	var sh := HBoxContainer.new()
	sh.position = Vector2(256, 640)
	sh.add_theme_constant_override("separation", 10)
	add_child(sh)
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = L.t("Preset name")
	_preset_name.custom_minimum_size = Vector2(330, 60)
	_preset_name.add_theme_font_size_override("font_size", UITheme.fs(20))
	sh.add_child(_preset_name)
	var save := UITheme.button(L.t("Save"), 19, Vector2(140, 60))
	save.pressed.connect(_on_save_preset)
	sh.add_child(save)
	_del_btn = UITheme.button(L.t("Delete"), 19, Vector2(140, 60))
	_del_btn.pressed.connect(_on_delete_preset)
	sh.add_child(_del_btn)
	var ex := UITheme.button(L.t("Export"), 19, Vector2(140, 60))
	ex.pressed.connect(_on_export_preset)
	sh.add_child(ex)
	var im := UITheme.button(L.t("Import"), 19, Vector2(140, 60))
	im.pressed.connect(_on_import_preset)
	sh.add_child(im)
	if not Content.can_customize():
		for b in [ex, im]:
			b.disabled = true
			b.tooltip_text = L.t("Part of the expansion")
	_msg = UITheme.label("", 14, UITheme.MUTED)
	_msg.position = Vector2(256, 702)
	_msg.size = Vector2(980, 18)
	add_child(_msg)
	_reload_presets()
	_sync_from_rules()


func _rule_row(key: String) -> Control:
	## Uma regra: rotulo e controle, com um fundo que fica vermelho quando ela foge do habitual.
	var o: Array = OPT[key]
	var box := Control.new()
	box.custom_minimum_size = Vector2(1150, 58)
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.85, 0.18, 0.15, 1.0))
	gr.set_color(1, Color(0.85, 0.18, 0.15, 0.0))
	gt.gradient = gr
	gt.width = 256
	gt.height = 4
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(760, 58)
	bg.modulate.a = 0.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	_row_bg[key] = bg
	_row_box[key] = box
	var dep := DEPENDS.has(key)
	var ctl: Control
	if typeof(o[1]) == TYPE_STRING and o[1] == "check":
		var cb := CheckBox.new()
		cb.text = L.t(o[0])
		cb.add_theme_font_size_override("font_size", UITheme.fs(23))
		cb.add_theme_color_override("font_color", UITheme.GOLD)
		cb.add_theme_color_override("font_pressed_color", UITheme.GOLD)
		cb.position = Vector2(14, 6)
		cb.custom_minimum_size = Vector2(700, 46)
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on: bool):
			if _updating:
				return
			rules.set(key, on)
			Audio.play("select")
			_sync_from_rules())
		box.add_child(cb)
		ctl = cb
	else:
		var lab := UITheme.label(L.t(o[0]), 20, UITheme.TEXT)
		lab.position = Vector2(56 if dep else 16, 12)
		lab.size = Vector2(500, 34)
		lab.clip_text = true
		box.add_child(lab)
		if typeof(o[1]) == TYPE_STRING and str(o[1]).begins_with("content:"):
			var kind: String = str(o[1]).trim_prefix("content:")
			var items := Content.list(kind)
			var ob := UITheme.option(items.map(func(it): return it["name"] if it["builtin"] else it["name"] + " ★"))
			ob.set_meta("ids", items.map(func(it): return it["id"]))
			ob.item_selected.connect(func(i):
				if _updating:
					return
				rules.set(key, ob.get_meta("ids")[i])
				Audio.play("select")
				_sync_from_rules())
			ctl = ob
		elif typeof(o[2]) == TYPE_STRING and o[2] == "num":
			ctl = _number_field(key)
		else:
			var ob2 := UITheme.option(option_labels(o))
			ob2.item_selected.connect(func(i):
				if _updating:
					return
				rules.set(key, o[1][i])
				Audio.play("select")
				_sync_from_rules())
			ctl = ob2
		if ctl is OptionButton:
			ctl.custom_minimum_size = Vector2(560, 48)
			ctl.clip_text = true
			ctl.fit_to_longest_item = false
			ctl.add_theme_font_size_override("font_size", UITheme.fs(19))
		ctl.position = Vector2(580, 5)
		box.add_child(ctl)
	_ctl[key] = ctl
	return box


func _number_field(key: String) -> HBoxContainer:
	## Campo numerico com - e +; tocar no numero abre o teclado (aceita do minimo ao maximo).
	var o: Array = OPT[key]
	var lo: int = o[1][0]
	var hi: int = o[1][1]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var minus := UITheme.button("−", 26, Vector2(64, 48))
	var le := LineEdit.new()
	le.name = "Num"
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.custom_minimum_size = Vector2(200, 48)
	le.add_theme_font_size_override("font_size", UITheme.fs(24))
	le.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	le.max_length = 3
	var plus := UITheme.button("+", 26, Vector2(64, 48))
	var apply := func(val: int):
		var c := clampi(val, lo, hi)
		rules.set(key, c)
		le.text = str(c)
		_sync_from_rules()
	minus.pressed.connect(func(): apply.call(int(rules.get(key)) - 1))
	plus.pressed.connect(func(): apply.call(int(rules.get(key)) + 1))
	le.text_submitted.connect(func(t: String): apply.call(int(t) if t.is_valid_int() else int(rules.get(key))))
	le.focus_exited.connect(func(): apply.call(int(le.text) if le.text.is_valid_int() else int(rules.get(key))))
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
	var vo := _big_option(Defs.VISUAL_NAMES.map(func(x): return L.t(x)), maxi(0, Defs.VISUALS.find(Defs.visual)))
	vo.item_selected.connect(func(i):
		Defs.set_visual(Defs.VISUALS[i])
		Store.set_value("visual", "tema", Defs.VISUALS[i]))
	v.add_child(_row(L.t("Visual"), vo))
	var vnote := UITheme.label(L.t("Polygonal also saves battery (30 frames per second)."), 15, UITheme.MUTED)
	v.add_child(vnote)
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
	match o[2]:
		"free":
			return o[1].map(func(k): return L.t("Exact") if k == 0 else L.f("Total −{n}, any elements", {"n": k}))
		"time":
			return o[1].map(func(t): return L.t("No limit") if t == 0 else L.f("{n} s", {"n": t}))
	return o[2].map(func(x): return L.t(x))


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
	Content.migrate_presets()
	_presets = []
	for p in RuleSet.builtin_presets():
		_presets.append([p[0], p[1], false, ""])
	for it in Content.list("presets"):
		_presets.append([it["name"], RuleSet.from_dict(Content.load_preset(it["id"])), true, it["id"]])
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


func _sync_from_rules() -> void:
	_updating = true
	for key in _ctl:
		var c: Control = _ctl[key]
		var o: Array = OPT[key]
		var val = rules.get(key)
		if c is CheckBox:
			c.button_pressed = bool(val)
		elif c is OptionButton:
			var idx := -1
			if c.has_meta("ids"):
				idx = c.get_meta("ids").find(val)
			else:
				idx = o[1].find(val)
			c.select(maxi(idx, 0))
		else:
			var le: LineEdit = c.get_node("Num")
			if not le.has_focus():
				le.text = str(val)
		var on := not DEPENDS.has(key) or bool(rules.get(DEPENDS[key]))
		_set_enabled(c, on)
		if _row_box.has(key):
			_row_box[key].modulate.a = 1.0 if on else 0.45
		if _row_bg.has(key):
			_row_bg[key].modulate.a = 0.55 * rules.deviation(key) if on else 0.0
	# abas com regras fora do habitual ganham um ponto vermelho
	for i in range(_tab_btns.size()):
		var dev := 0.0
		for key in TABS[i][1]:
			if not DEPENDS.has(key) or bool(rules.get(DEPENDS[key])):
				dev = maxf(dev, rules.deviation(key))
		var b: Button = _tab_btns[i]
		b.text = L.t(TABS[i][0]) + ("  •" if dev > 0.0 else "")
		b.add_theme_color_override("font_color", UITheme.GOLD if i == _tab else (Color(1.0, 0.55, 0.5) if dev > 0.0 else UITheme.TEXT))
		b.add_theme_stylebox_override("normal", UITheme.box(Color(0.22, 0.20, 0.14), UITheme.GOLD, 2) if i == _tab
			else UITheme.box(Color(0.12, 0.13, 0.17, 0.9), Color(1, 1, 1, 0.15), 1))
	var gn := find_child("GovNote", true, false)
	if gn != null:
		gn.visible = rules.governors
	if _status != null and is_instance_valid(_status):
		var k := rules.unusual_count()
		_status.text = L.t("All rules within the usual") if k == 0 else L.t("1 rule outside the usual (in red)") if k == 1 else L.f("{n} rules outside the usual (in red)", {"n": k})
		_status.add_theme_color_override("font_color", UITheme.MUTED if k == 0 else Color(1.0, 0.6, 0.55))
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


func _set_enabled(c: Control, on: bool) -> void:
	if c is BaseButton:
		c.disabled = not on
	for ch in c.get_children():
		if ch is BaseButton:
			ch.disabled = not on
		elif ch is LineEdit:
			ch.editable = on


func _say(t: String) -> void:
	if _msg != null and is_instance_valid(_msg):
		_msg.text = t


func _selected_preset_name() -> String:
	var i := _preset_opt.selected
	if i < _presets.size():
		return _presets[i][0] if _presets[i][2] else L.t(_presets[i][0])
	return _preset_name.text.strip_edges() if _preset_name.text.strip_edges() != "" else L.t("Custom")


func _on_export_preset() -> void:
	var nm := Content.clean_name(_selected_preset_name())
	Files.save_dialog(self, L.t("Export"), nm + ".zip", func(path: String):
		var dest := Files.writable(path)
		if Content.export_package(nm, rules, dest):
			_say(L.f("Saved: {path}", {"path": ProjectSettings.globalize_path(dest)}))
		else:
			_say(L.t("Could not save the file.")))


func _on_import_preset() -> void:
	Files.open_dialog(self, L.t("Import"), ["zip", "csv"], func(path: String):
		var res: Dictionary
		if path.get_extension().to_lower() == "zip":
			res = Content.import_package(path)
		else:
			var r := Content.import_text("presets", path.get_file().get_basename(), FileAccess.get_file_as_string(path))
			res = {"preset": r["id"], "errors": r["errors"]}
		_reload_presets()
		if res["preset"] != "":
			rules = RuleSet.from_dict(Content.load_preset(res["preset"]))
			_sync_from_rules()
			_say(L.t("Preset imported."))
		else:
			_say(L.t("This file could not be read.") + " " + " ".join(res["errors"])))


func _on_save_preset() -> void:
	var name := _preset_name.text.strip_edges()
	if name == "":
		Audio.play("error")
		_preset_name.placeholder_text = L.t("Type a name first")
		return
	Content.save_preset(name, rules)
	_preset_name.text = ""
	_reload_presets()
	_sync_from_rules()
	Audio.play("reserve")


func _on_delete_preset() -> void:
	var i := _preset_opt.selected
	if i < _presets.size() and _presets[i][2]:
		Content.delete_item("presets", _presets[i][3])
		_reload_presets()
		_sync_from_rules()
