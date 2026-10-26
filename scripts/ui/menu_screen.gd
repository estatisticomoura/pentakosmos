class_name MenuScreen
extends Control
## Tela inicial: predefinicoes de regras, opcoes individuais, jogadores e audio.

signal start_game(rules: RuleSet, players: Array)
signal show_text(which: String)   # "rules" (como jogar) ou "story" (processo criativo)

# Textos em ingles; L.t() traduz na hora de mostrar.
const OPTIONS := [
	["Solids per element", "gems_mode", ["classico", "house"], ["Legacy (4/5/7/8)", "Pentakosmos (4/6/7/8)"]],  # tr
	["Spheres (jokers)", "gold_mode", ["classico", "house"], ["Legacy (5)", "Pentakosmos (4/5/6/7)"]],  # tr
	["Take 2 of a kind", "take2_min", [4, 3], ["Pile of 4 or more", "Pile of 3 or more"]],  # tr
	["Market with 5 players", "market5", [4, 5], ["4 cards per level", "5 cards per level"]],  # tr
	["Philosopher requirement", "noble_mode", ["exato", "flexivel"], ["Exact", "Total −2, any elements"]],  # tr
	["Philosopher points", "noble_points_mode", ["fixo", "decrescente"], ["3 each", "3 / 2 / 1"]],  # tr
	["Deck", "deck", ["caio", "oficial"], ["Pentakosmos", "Legacy"]],  # tr
	["Token hand limit", "hand_limit", [9, 10, 11], ["9", "10", "11"]],  # tr
	["Points to win", "target", [12, 13, 14, 15, 16, 17, 18], ["12", "13", "14", "15", "16", "17", "18"]],  # tr
	["Specialization victory", "color_win", [0, 9, 10, 11, 12],  # tr
		["Off", "9 pts in one element", "10 pts in one element", "11 pts in one element", "12 pts in one element"]],  # tr
]
const KINDS := ["humano", "facil", "normal", "intermediaria", "dificil", "muito_dificil"]
# nomes no seletor: "Human" e os personagens da IA (Defs.PERSONAS), do mais fraco ao mais forte
const OLD_DEFAULTS := ["Você", "Lívia", "Otávio", "Júlia", "Marco"]   # nomes padrao de versoes antigas
static var _default_pool := []

var rules: RuleSet
var _presets: Array = []   # [nome, RuleSet, custom:bool]
var _preset_opt: OptionButton
var _opt_controls: Array = []
var _summary: Label
var _preset_name: LineEdit
var _del_btn: Button
var _count_opt: OptionButton
var _rows: Array = []      # [HBox, LineEdit, OptionButton]
var _note: Label
var _updating := false


func _init() -> void:
	size = Vector2(1280, 720)


func _ready() -> void:
	var saved = Store.get_value("setup", "rules", null)
	rules = RuleSet.from_dict(saved) if saved is Dictionary else RuleSet.house_full()
	_build()
	_load_players()
	_reload_presets()
	_sync_from_rules()


func _build() -> void:
	var title := UITheme.label("PENTAKOSMOS", 50, UITheme.GOLD)
	title.position = Vector2(0, 10)
	title.size = Vector2(1280, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(title)

	# --- regras ---
	var left := PanelContainer.new()
	left.position = Vector2(40, 92)
	left.size = Vector2(650, 552)
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	lv.add_child(UITheme.label(L.t("Rules"), 22, UITheme.GOLD))
	var ph := HBoxContainer.new()
	ph.add_child(UITheme.label(L.t("Preset"), 17))
	_preset_opt = UITheme.option([])
	_preset_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_opt.item_selected.connect(_on_preset_selected)
	ph.add_child(_preset_opt)
	lv.add_child(ph)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 1)
	grid.add_theme_constant_override("h_separation", 12)
	lv.add_child(grid)
	for i in range(OPTIONS.size()):
		var o: Array = OPTIONS[i]
		var l := UITheme.label(L.t(o[0]), 15, UITheme.MUTED)
		l.custom_minimum_size = Vector2(230, 0)
		grid.add_child(l)
		var ob := UITheme.option(o[3].map(func(x): return L.t(x)))
		ob.custom_minimum_size = Vector2(360, 33)
		ob.add_theme_font_size_override("font_size", 15)
		ob.item_selected.connect(_on_option_changed.bind(i))
		grid.add_child(ob)
		_opt_controls.append(ob)
	_summary = UITheme.label("", 13, UITheme.MUTED)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(600, 36)
	lv.add_child(_summary)
	var sh := HBoxContainer.new()
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = L.t("Preset name")
	_preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_name.add_theme_font_size_override("font_size", 16)
	sh.add_child(_preset_name)
	var save := UITheme.button(L.t("Save"), 16, Vector2(90, 38))
	save.pressed.connect(_on_save_preset)
	sh.add_child(save)
	_del_btn = UITheme.button(L.t("Delete"), 16, Vector2(90, 38))
	_del_btn.pressed.connect(_on_delete_preset)
	sh.add_child(_del_btn)
	lv.add_child(sh)

	# --- jogadores ---
	var right := PanelContainer.new()
	right.position = Vector2(710, 92)
	right.size = Vector2(530, 552)
	add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)
	rv.add_child(UITheme.label(L.t("Players"), 22, UITheme.GOLD))
	var ch := HBoxContainer.new()
	ch.add_child(UITheme.label(L.t("Number"), 17))
	_count_opt = UITheme.option(["2", "3", "4", "5"], 1)
	_count_opt.item_selected.connect(func(_i): _update_rows())
	ch.add_child(_count_opt)
	rv.add_child(ch)
	for i in range(5):
		var row := HBoxContainer.new()
		var num := UITheme.label("%d." % (i + 1), 16, UITheme.MUTED)
		num.custom_minimum_size = Vector2(26, 0)
		row.add_child(num)
		var le := LineEdit.new()
		le.text = _default_name(i, "humano" if i == 0 else "normal")
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.max_length = 16
		le.add_theme_font_size_override("font_size", 16)
		row.add_child(le)
		var kind := UITheme.option(_kind_names(), 0 if i == 0 else 2)
		kind.item_selected.connect(_on_kind_changed.bind(i))
		kind.custom_minimum_size = Vector2(190, 36)
		kind.add_theme_font_size_override("font_size", 16)
		row.add_child(kind)
		rv.add_child(row)
		_rows.append([row, le, kind])
	_note = UITheme.label("", 13, Color(1.0, 0.75, 0.5))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(480, 34)
	rv.add_child(_note)
	rv.add_child(HSeparator.new())
	var vh := HBoxContainer.new()
	var vl := UITheme.label(L.t("Visual"), 18, UITheme.GOLD)
	vl.custom_minimum_size = Vector2(110, 0)
	vh.add_child(vl)
	var vo := UITheme.option(Defs.VISUAL_NAMES.map(func(x): return L.t(x)), maxi(0, Defs.VISUALS.find(Defs.visual)))
	vo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vo.item_selected.connect(_on_visual)
	vh.add_child(vo)
	rv.add_child(vh)
	var lh := HBoxContainer.new()
	# "Language" sempre aparece tambem em ingles, para quem nao entende o idioma atual
	var ll := UITheme.label(L.t("Language") if L.code == "en" else L.t("Language") + " / Language", 16, UITheme.GOLD)
	ll.custom_minimum_size = Vector2(110, 0)
	lh.add_child(ll)
	var lo := UITheme.option(L.names(), L.index())
	lo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lo.item_selected.connect(_on_language)
	lh.add_child(lo)
	rv.add_child(lh)
	rv.add_child(HSeparator.new())
	rv.add_child(UITheme.label(L.t("Audio"), 20, UITheme.GOLD))
	rv.add_child(_slider_row(L.t("Music"), "Music"))
	var mp := HBoxContainer.new()
	var mpl := UITheme.label(L.t("Playlist"), 16, UITheme.MUTED)
	mpl.custom_minimum_size = Vector2(90, 0)
	mp.add_child(mpl)
	var picker := MusicPicker.make()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp.add_child(picker)
	rv.add_child(mp)
	rv.add_child(_slider_row(L.t("Effects"), "SFX"))

	# --- botoes ---
	var rules_btn := UITheme.button(L.t("How to play"), 17, Vector2(170, 46))
	rules_btn.position = Vector2(40, 660)
	rules_btn.pressed.connect(func(): show_text.emit("rules"))
	add_child(rules_btn)
	var story_btn := UITheme.button(L.t("Creative process"), 17, Vector2(190, 46))
	story_btn.position = Vector2(220, 660)
	story_btn.pressed.connect(func(): show_text.emit("story"))
	add_child(story_btn)
	var play := UITheme.button(L.t("Play"), 24, Vector2(260, 56))
	play.position = Vector2(510, 654)
	play.add_theme_color_override("font_color", UITheme.GOLD)
	play.pressed.connect(_on_play)
	add_child(play)
	if not OS.has_feature("web"):
		var quit := UITheme.button(L.t("Quit"), 18, Vector2(120, 46))
		quit.position = Vector2(1120, 660)
		quit.pressed.connect(func(): get_tree().quit())
		add_child(quit)


func _on_language(i: int) -> void:
	L.set_lang(L.LANGS[i][0])
	Store.set_value("geral", "idioma", L.code)
	Audio.play("select")
	# remonta a tela no novo idioma, mantendo as escolhas atuais
	var keep_players := _current_players()
	for ch in get_children():
		ch.queue_free()
	_opt_controls = []
	_rows = []
	_build()
	_apply_players(keep_players)
	_reload_presets()
	_sync_from_rules()


func _current_players() -> Array:
	var out: Array = []
	for i in range(_count_opt.selected + 2):
		out.append({"name": _rows[i][1].text, "kind": KINDS[_rows[i][2].selected]})
	return out


func _apply_players(saved: Array) -> void:
	_count_opt.select(clampi(saved.size(), 2, 5) - 2)
	for i in range(mini(saved.size(), 5)):
		var kind: String = saved[i].get("kind", "normal")
		_rows[i][2].select(maxi(KINDS.find(kind), 0))
		var nm: String = saved[i].get("name", "")
		# nomes padrao acompanham o idioma e o adversario escolhido
		_rows[i][1].text = _default_name(i, kind) if _is_default_name(nm) else nm


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
	if _is_default_name(_rows[i][1].text):
		_rows[i][1].text = _default_name(i, KINDS[sel])


func _on_visual(i: int) -> void:
	Defs.set_visual(Defs.VISUALS[i])
	Store.set_value("visual", "tema", Defs.VISUALS[i])


func _slider_row(text: String, bus: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UITheme.label(text, 16, UITheme.MUTED)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Audio.get_volume(bus)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 30)
	s.value_changed.connect(func(v): Audio.set_volume(bus, v))
	s.drag_ended.connect(func(_c): Audio.save_volumes(); Audio.play("select"))
	h.add_child(s)
	return h


# --- predefinicoes -----------------------------------------------------------
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
	_sync_from_rules()


func _sync_from_rules() -> void:
	_updating = true
	for i in range(OPTIONS.size()):
		var o: Array = OPTIONS[i]
		var idx: int = o[2].find(rules.get(o[1]))
		_opt_controls[i].select(maxi(idx, 0))
	var match_i := _presets.size()
	for i in range(_presets.size()):
		if (_presets[i][1] as RuleSet).equals(rules):
			match_i = i
			break
	_preset_opt.select(match_i)
	_del_btn.disabled = not (match_i < _presets.size() and _presets[match_i][2])
	_summary.text = rules.summary()
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


# --- jogadores ---------------------------------------------------------------
func _update_rows() -> void:
	if _count_opt == null:
		return
	var n := _count_opt.selected + 2
	for i in range(5):
		_rows[i][0].visible = i < n
	var notes: Array = []
	if n == 5:
		if rules.market5 == 4:
			notes.append(L.t("With 5 players, a 5-card market per level is recommended."))
		if rules.deck == "oficial":
			notes.append(L.t("With the Legacy deck and 5 players, the level 1 deck often runs out."))
	_note.text = " ".join(notes)


func _load_players() -> void:
	var saved = Store.get_value("setup", "players", null)
	if saved is Array and saved.size() >= 2:
		_apply_players(saved)


func _on_play() -> void:
	var n := _count_opt.selected + 2
	var players: Array = []
	for i in range(n):
		var nm: String = _rows[i][1].text.strip_edges()
		if nm == "":
			nm = _default_name(i, KINDS[_rows[i][2].selected])
		players.append({"name": nm, "kind": KINDS[_rows[i][2].selected]})
	Store.set_value("setup", "rules", rules.to_dict())
	Store.set_value("setup", "players", players)
	start_game.emit(rules.copy(), players)
