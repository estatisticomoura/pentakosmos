class_name CustomizeScreen
extends Control
## Personalizar: decks, filosofos, escritores, governantes e predefinicoes.
## Os conteudos de fabrica ficam travados (podem ser vistos e duplicados); os do jogador podem
## ser editados aqui ou numa planilha (cada um e um arquivo .csv). Criar, duplicar, editar,
## importar e exportar e coisa da expansao; sem ela, a tela mostra os conteudos de fabrica.

signal back

const TABS := [["decks", "Decks"], ["philosophers", "Philosophers"], ["writers", "Writers"],  # tr
	["governors", "Governors"], ["presets", "Presets"]]  # tr
const BONUS_HELP := "air · water · aether · fire · earth · none · joker · air + fire"
const EFFECT_NAMES := ["No effect", "Take 1 token", "Take 2 tokens", "Take 1 sphere", "Extra turn"]  # tr

static var _tab := 0
var _items: Array = []
var _sel := 0
var _list: VBoxContainer
var _detail: VBoxContainer
var _msg: Label
# editor
var _ed_kind := ""
var _ed_id := ""
var _ed_name: LineEdit
var _ed_rows: VBoxContainer
var _ed_errors: Label
var _ed_readonly := false


func _init() -> void:
	size = Vector2(1280, 720)


func _ready() -> void:
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


func _on_back() -> void:
	if _ed_kind != "":
		_ed_kind = ""
		_build()
	else:
		back.emit()


func _clear() -> void:
	for ch in get_children():
		ch.queue_free()


func _kind() -> String:
	return TABS[_tab][0]


# ---------------------------------------------------------------------------
# Lista
# ---------------------------------------------------------------------------
func _build() -> void:
	_clear()
	var title := UITheme.label(L.t("Customize"), 36, UITheme.GOLD)
	title.position = Vector2(0, 12)
	title.size = Vector2(1280, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(40, 70)
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for i in range(TABS.size()):
		var b := UITheme.button(L.t(TABS[i][1]), 19, Vector2(226, 50))
		if i == _tab:
			b.add_theme_color_override("font_color", UITheme.GOLD)
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.22, 0.20, 0.14), UITheme.GOLD, 2))
		var k := i
		b.pressed.connect(func():
			_tab = k
			_sel = 0
			Audio.play("select")
			_build())
		tabs.add_child(b)
	# lista
	var lp := PanelContainer.new()
	lp.position = Vector2(40, 132)
	lp.size = Vector2(460, 494)
	add_child(lp)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size = Vector2(420, 0)
	sc.add_child(_list)
	# detalhe
	var dp := PanelContainer.new()
	dp.position = Vector2(516, 132)
	dp.size = Vector2(724, 494)
	add_child(dp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	dp.add_child(_detail)
	# rodape
	var bk := UITheme.button(L.t("Back"), 22, Vector2(200, 60))
	bk.position = Vector2(40, 640)
	bk.pressed.connect(_on_back)
	add_child(bk)
	var foot := HBoxContainer.new()
	foot.position = Vector2(256, 640)
	foot.add_theme_constant_override("separation", 10)
	add_child(foot)
	if _kind() != "presets":
		var im := UITheme.button(L.t("Import CSV"), 19, Vector2(200, 60))
		im.pressed.connect(_on_import)
		im.disabled = not Content.can_customize()
		foot.add_child(im)
	if not OS.has_feature("mobile") and Content.can_customize():
		var of := UITheme.button(L.t("Open folder"), 19, Vector2(200, 60))
		of.pressed.connect(func():
			DirAccess.make_dir_recursive_absolute(Content.dir(_kind()))
			OS.shell_open(ProjectSettings.globalize_path(Content.dir(_kind()))))
		foot.add_child(of)
	_msg = UITheme.label("", 15, UITheme.MUTED)
	_msg.position = Vector2(700, 650)
	_msg.size = Vector2(540, 60)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_msg)
	_fill()


func _fill() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	_items = Content.list(_kind())
	if _kind() == "presets":
		var pre: Array = []
		for p in RuleSet.builtin_presets():
			pre.append({"id": "", "name": L.t(p[0]), "builtin": true, "rules": p[1]})
		_items = pre + _items
	_sel = clampi(_sel, 0, maxi(0, _items.size() - 1))
	for i in range(_items.size()):
		var it: Dictionary = _items[i]
		var b := UITheme.button(("%s  ·  %s" % [it["name"], L.t("built-in")]) if it["builtin"] else it["name"], 19,
			Vector2(410, 48))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		if i == _sel:
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.25, 0.21, 0.12, 0.9), UITheme.GOLD, 2))
		var k := i
		b.pressed.connect(func():
			_sel = k
			Audio.play("select")
			_fill())
		_list.add_child(b)
	_fill_detail()


func _fill_detail() -> void:
	for ch in _detail.get_children():
		ch.queue_free()
	if not Content.can_customize():
		var lock := UITheme.label(L.t("Creating and editing decks, philosophers, writers and governors is part of the expansion."), 19, UITheme.GOLD)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.custom_minimum_size = Vector2(680, 0)
		_detail.add_child(lock)
		var more := UITheme.label(L.t("The expansion also brings 14 more governors and 8 more writers. In the base game you can look at everything that comes with it."), 16, UITheme.MUTED)
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.custom_minimum_size = Vector2(680, 0)
		_detail.add_child(more)
	if _items.is_empty():
		_detail.add_child(UITheme.label(L.t("Nothing here yet."), 18, UITheme.MUTED))
		return
	var it: Dictionary = _items[_sel]
	_detail.add_child(UITheme.label(it["name"], 26, UITheme.GOLD))
	var info := UITheme.label(_describe(it), 17, UITheme.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(680, 0)
	_detail.add_child(info)
	if it["builtin"]:
		_detail.add_child(UITheme.label(L.t("Built-in: to change it, duplicate it."), 15, UITheme.MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_detail.add_child(grid)
	var can := Content.can_customize()
	var kind := _kind()
	if kind != "presets":
		var view := UITheme.button(L.t("View") if it["builtin"] or not can else L.t("Edit"), 19, Vector2(220, 54))
		view.pressed.connect(func(): _open_editor(kind, it["id"], it["builtin"] or not can))
		grid.add_child(view)
	var dup := UITheme.button(L.t("Duplicate"), 19, Vector2(220, 54))
	dup.disabled = not can or (kind == "presets" and it["builtin"])
	dup.pressed.connect(func():
		var nid := ""
		if kind == "presets" and not it["builtin"]:
			nid = Content.save_preset(Content.free_name("presets", L.f("Copy of {name}", {"name": it["name"]})),
				RuleSet.from_dict(Content.load_preset(it["id"])))
		else:
			nid = Content.duplicate_item(kind, it["id"])
		_select_id(nid)
		_say(L.t("Duplicated. You can now edit the copy.")))
	grid.add_child(dup)
	var ren := UITheme.button(L.t("Rename"), 19, Vector2(220, 54))
	ren.disabled = it["builtin"] or not (can or kind == "presets")
	ren.pressed.connect(func(): _ask_name(it["name"], func(nm: String):
		_select_id(Content.rename_item(kind, it["id"], nm))))
	grid.add_child(ren)
	var del := UITheme.button(L.t("Delete"), 19, Vector2(220, 54))
	del.disabled = it["builtin"]
	del.pressed.connect(func():
		Content.delete_item(kind, it["id"])
		_sel = maxi(0, _sel - 1)
		_fill())
	grid.add_child(del)
	var ex := UITheme.button(L.t("Export CSV") if kind != "presets" else L.t("Export"), 19, Vector2(220, 54))
	ex.disabled = not can
	ex.pressed.connect(func(): _on_export(it))
	grid.add_child(ex)


func _describe(it: Dictionary) -> String:
	var kind := _kind()
	match kind:
		"decks":
			var cards := Content.load_deck(it["id"])
			var per := [0, 0, 0, 0]
			var special := 0
			for cd in cards:
				per[cd.level] += 1
				if cd.kind != "single" or cd.effect != "" or cd.cost[5] > 0 or cd.points < 0:
					special += 1
			var s := L.f("{n} cards: {a} basic, {b} intermediate, {c} advanced.", {"n": cards.size(), "a": per[1], "b": per[2], "c": per[3]})
			if special > 0:
				s += " " + L.f("{n} special cards (effects, sphere costs, other bonuses or negative points).", {"n": special})
			return s
		"philosophers", "writers":
			var items := Content.load_patrons(kind, it["id"])
			return L.f("{n} in the set: {names}.", {"n": items.size(), "names": ", ".join(items.map(func(x): return L.t(x["name"])))})
		"governors":
			var govs := Content.load_governors(it["id"])
			return L.f("{n} in the set: {names}.", {"n": govs.size(), "names": ", ".join(govs.map(func(x): return L.t(x["name"])))})
		"presets":
			var r: RuleSet = it["rules"] if it.has("rules") else RuleSet.from_dict(Content.load_preset(it["id"]))
			return r.summary()
	return ""


func _select_id(id: String) -> void:
	_fill()
	for i in range(_items.size()):
		if _items[i]["id"] == id:
			_sel = i
	_fill()


func _say(t: String) -> void:
	if _msg != null and is_instance_valid(_msg):
		_msg.text = t


func _ask_name(current: String, on_ok: Callable) -> void:
	var o := Control.new()
	o.size = size
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = size
	o.add_child(dim)
	var p := PanelContainer.new()
	p.position = Vector2(340, 250)
	p.size = Vector2(600, 200)
	o.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UITheme.label(L.t("New name"), 22, UITheme.GOLD))
	var le := LineEdit.new()
	le.text = current
	le.custom_minimum_size = Vector2(560, 54)
	le.add_theme_font_size_override("font_size", UITheme.fs(21))
	v.add_child(le)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ok := UITheme.button(L.t("Save"), 19, Vector2(180, 50))
	ok.pressed.connect(func():
		var nm := le.text.strip_edges()
		o.queue_free()
		if nm != "":
			on_ok.call(nm))
	h.add_child(ok)
	var cancel := UITheme.button(L.t("Cancel"), 19, Vector2(180, 50))
	cancel.pressed.connect(o.queue_free)
	h.add_child(cancel)
	v.add_child(h)
	add_child(o)
	le.grab_focus()


func _on_export(it: Dictionary) -> void:
	var kind := _kind()
	if kind == "presets":
		var r: RuleSet = it["rules"] if it.has("rules") else RuleSet.from_dict(Content.load_preset(it["id"]))
		Files.save_dialog(self, L.t("Export"), Content.clean_name(it["name"]) + ".zip", func(path: String):
			var dest := Files.writable(path)
			_say(L.f("Saved: {path}", {"path": ProjectSettings.globalize_path(dest)}) if Content.export_package(it["name"], r, dest)
				else L.t("Could not save the file.")))
		return
	var text := Content.text_of(kind, it["id"])
	Files.save_dialog(self, L.t("Export CSV"), Content.clean_name(it["name"]) + ".csv", func(path: String):
		var where := Files.write_text(path, text)
		_say(L.f("Saved: {path}", {"path": where}) if where != "" else L.t("Could not save the file.")))


func _on_import() -> void:
	var kind := _kind()
	Files.open_dialog(self, L.t("Import CSV"), ["csv"], func(path: String):
		var r := Content.import_text(kind, path.get_file().get_basename(), FileAccess.get_file_as_string(path))
		if r["errors"].is_empty():
			_select_id(r["id"])
			_say(L.t("Imported."))
		else:
			_say(L.t("Not imported:") + " " + " ".join(r["errors"].slice(0, 3))))


# ---------------------------------------------------------------------------
# Editor (tabela)
# ---------------------------------------------------------------------------
func _open_editor(kind: String, id: String, readonly: bool) -> void:
	_ed_kind = kind
	_ed_id = id
	_ed_readonly = readonly
	_clear()
	var top := HBoxContainer.new()
	top.position = Vector2(40, 16)
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	var kname := ""
	for t in TABS:
		if t[0] == kind:
			kname = t[1]
	top.add_child(UITheme.label(L.t(kname), 26, UITheme.GOLD))
	_ed_name = LineEdit.new()
	_ed_name.text = Content.name_of(kind, id)
	_ed_name.editable = not readonly
	_ed_name.custom_minimum_size = Vector2(520, 50)
	_ed_name.add_theme_font_size_override("font_size", UITheme.fs(21))
	top.add_child(_ed_name)
	if kind == "decks":
		var help := UITheme.label(L.t("Bonus") + ": " + BONUS_HELP, 14, UITheme.MUTED)
		help.position = Vector2(40, 72)
		add_child(help)
	var p := PanelContainer.new()
	p.position = Vector2(40, 98)
	p.size = Vector2(1200, 524)
	add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	p.add_child(sc)
	var all := VBoxContainer.new()
	all.add_theme_constant_override("separation", 4)
	sc.add_child(all)
	# cabecalho das colunas (dentro da rolagem, para andar junto)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	all.add_child(head)
	for col in _columns(kind):
		var l := UITheme.label(L.t(col[0]), 15, UITheme.MUTED)
		l.custom_minimum_size = Vector2(_cell_w(col), 0)
		l.clip_text = true
		head.add_child(l)
	_ed_rows = VBoxContainer.new()
	_ed_rows.add_theme_constant_override("separation", 4)
	all.add_child(_ed_rows)
	var recs := Content._records(Content.text_of(kind, id))
	for r in recs:
		_add_row(kind, r)
	# rodape
	var bk := UITheme.button(L.t("Back"), 22, Vector2(200, 60))
	bk.position = Vector2(40, 640)
	bk.pressed.connect(_on_back)
	add_child(bk)
	if not readonly:
		var add := UITheme.button(L.t("Add a line"), 19, Vector2(200, 60))
		add.position = Vector2(256, 640)
		add.pressed.connect(func(): _add_row(kind, {}))
		add_child(add)
		var save := UITheme.button(L.t("Save"), 20, Vector2(200, 60))
		save.position = Vector2(472, 640)
		save.add_theme_color_override("font_color", UITheme.GOLD)
		save.pressed.connect(_on_save_editor)
		add_child(save)
	_ed_errors = UITheme.label("", 15, Color(1.0, 0.6, 0.55))
	_ed_errors.position = Vector2(690, 636)
	_ed_errors.size = Vector2(550, 80)
	_ed_errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_ed_errors)


func _columns(kind: String) -> Array:
	## [titulo, largura, tipo, chave, minimo, maximo / itens]
	var elems := [["Air", 74, "spin", "air", 0, Content.MAX_COST], ["Water", 74, "spin", "water", 0, Content.MAX_COST],  # tr
		["Aether", 74, "spin", "aether", 0, Content.MAX_COST], ["Fire", 74, "spin", "fire", 0, Content.MAX_COST],  # tr
		["Earth", 74, "spin", "earth", 0, Content.MAX_COST]]  # tr
	match kind:
		"decks":
			return [["Group", 150, "opt", "group", ["1", "2", "3"], Defs.LEVEL_SHORT.slice(1)],  # tr
				["Points", 74, "spin", "points", Content.MIN_POINTS, Content.MAX_POINTS],  # tr
				["Bonus", 170, "text", "bonus"]] + elems + [  # tr
				["Spheres", 74, "spin", "sphere", 0, Content.MAX_COST],  # tr
				["Effect", 170, "opt", "effect", Content.EFFECTS, EFFECT_NAMES]]  # tr
		"philosophers":
			return [["Name", 260, "text", "name"]] + elems.map(func(e): return [e[0], e[1], e[2], e[3], 0, 20])  # tr
		"writers":
			return [["Name", 260, "text", "name"]] + elems.map(func(e): return [e[0], e[1], e[2], e[3], 0, 20]) + [
				["Points", 74, "spin", "points", -10, 10]]
		"governors":
			return [["Name", 200, "text", "name"],
				["Group", 150, "opt", "group", Governors.GROUPS, Governors.GROUPS.map(func(x): return Governors.GROUP_NAMES[x])],
				["Condition", 260, "opt", "condition", Governors.CONDITIONS, _texts(Governors.CONDITIONS, Governors.COND_TEXT)],  # tr
				["Value", 70, "spin", "condition_value", 0, 100],  # tr
				["Cost", 230, "opt", "cost", Governors.COSTS, _texts(Governors.COSTS, Governors.COST_TEXT)],  # tr
				["Value", 70, "spin", "cost_value", 0, 100],
				["Advantage", 260, "opt", "advantage", Governors.ADVANTAGES, _texts(Governors.ADVANTAGES, Governors.ADV_TEXT)],  # tr
				["Value", 70, "spin", "advantage_value", 0, 100],
				["Goal change", 90, "spin", "target_change", -50, 50],  # tr
				["Title", 200, "text", "title"]]  # tr
	return []


static func _cell_w(col: Array) -> float:
	return maxf(col[1], 118.0) if col[2] == "spin" else float(col[1])


static func _texts(codes: Array, texts: Dictionary) -> Array:
	return codes.map(func(x): return L.f(texts[x], {"n": "N"}) if texts[x] != "" else "—")


func _add_row(kind: String, rec: Dictionary) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for col in _columns(kind):
		var key: String = col[3]
		var val := str(rec.get(key, ""))
		var c: Control
		match col[2]:
			"text":
				var le := LineEdit.new()
				le.text = L.t(val) if key in ["name", "title"] and val != "" and _ed_id.begins_with(Content.USER) == false else val
				le.editable = not _ed_readonly
				if key == "bonus" and val == "":
					le.text = "air"
				c = le
			"spin":
				var sb := SpinBox.new()
				sb.min_value = col[4]
				sb.max_value = col[5]
				sb.value = Content._int(val, col[4], col[5], 0) if val != "" else (1 if key == "points" and kind == "writers" else 0)
				sb.editable = not _ed_readonly
				c = sb
			"opt":
				var vals: Array = col[4]
				var labels: Array = col[5]
				var ob := UITheme.option(labels.map(func(x): return L.t(str(x)) if str(x) != "" else "—"))
				var idx := vals.find(val.to_lower())
				if key == "group" and kind == "decks":
					idx = clampi(Content._int(val, 1, 3, 1) - 1, 0, 2)
				ob.select(maxi(0, idx))
				ob.disabled = _ed_readonly
				ob.fit_to_longest_item = false
				ob.clip_text = true
				c = ob
		c.custom_minimum_size = Vector2(_cell_w(col), 40)
		c.set_meta("key", key)
		c.set_meta("col", col)
		h.add_child(c)
	if not _ed_readonly:
		var x := UITheme.button("×", 20, Vector2(40, 40))
		x.pressed.connect(h.queue_free)
		h.add_child(x)
	_ed_rows.add_child(h)


func _row_values(h: Node) -> Array:
	var out: Array = []
	for c in h.get_children():
		if not c.has_meta("key"):
			continue
		var col: Array = c.get_meta("col")
		if c is LineEdit:
			out.append(c.text.strip_edges())
		elif c is SpinBox:
			out.append(int(c.value))
		elif c is OptionButton:
			out.append(col[4][c.selected])
	return out


func _on_save_editor() -> void:
	var cols := _columns(_ed_kind)
	var header: Array = cols.map(func(c): return c[3])
	var rows: Array = []
	for h in _ed_rows.get_children():
		if h.is_queued_for_deletion():
			continue
		rows.append(_row_values(h))
	var text := Content.to_csv(header, rows)
	var errs := Content.validate(_ed_kind, text)
	if not errs.is_empty():
		_ed_errors.text = " ".join(errs.slice(0, 4))
		Audio.play("error")
		return
	var nm := Content.clean_name(_ed_name.text)
	if nm == "":
		_ed_errors.text = L.t("Type a name first")
		return
	var old := _ed_id.trim_prefix(Content.USER)
	if nm != old:
		_ed_id = Content.rename_item(_ed_kind, _ed_id, nm)
	Content.save_text(_ed_kind, _ed_id.trim_prefix(Content.USER), text)
	Audio.play("reserve")
	_ed_kind = ""
	_build()
	_select_id(_ed_id)
	_say(L.t("Saved."))
