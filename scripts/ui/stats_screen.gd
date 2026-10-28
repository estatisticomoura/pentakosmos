class_name StatsScreen
extends Control
## Estatisticas: resumo, lista de partidas e detalhe, por jogador humano, periodo e regras.
## Exporta JSON (completo, reimportavel) e CSV (planilha); importa JSON sem duplicar.

signal back

const PERIODS := [[7, "1 week"], [14, "2 weeks"], [30, "1 month"], [91, "3 months"], [182, "6 months"],  # tr
	[365, "1 year"], [0, "All time"]]  # tr

var _player := ""
var _days := 30
var _rules := ""
var _games: Array = []
var _sel := 0
var _list: VBoxContainer
var _detail: VBoxContainer
var _tiles: HBoxContainer
var _msg: Label
var _period_btns: Array = []


func _init() -> void:
	size = Vector2(1280, 720)


func _ready() -> void:
	var names := Stats.human_names()
	_player = str(Store.get_value("stats", "player", names[0] if not names.is_empty() else ""))
	if not names.has(_player) and not names.is_empty():
		_player = names[0]
	_days = int(Store.get_value("stats", "days", 30))
	_build()
	_reload()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back.emit()


func _build() -> void:
	var title := UITheme.label(L.t("Statistics"), 38, UITheme.GOLD)
	title.position = Vector2(0, 12)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	# jogador
	var names := Stats.human_names()
	var po := UITheme.option(names if not names.is_empty() else [L.t("No games yet")], maxi(0, names.find(_player)))
	po.position = Vector2(920, 14)
	po.custom_minimum_size = Vector2(320, 48)
	po.add_theme_font_size_override("font_size", UITheme.fs(20))
	po.item_selected.connect(func(i):
		if i < names.size():
			_player = names[i]
			Store.set_value("stats", "player", _player)
			_reload())
	add_child(po)
	# periodo e regras
	var row := HBoxContainer.new()
	row.position = Vector2(40, 72)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for pr in PERIODS:
		var b := UITheme.button(L.t(pr[1]), 18, Vector2(118, 46))
		b.clip_text = true
		var d: int = pr[0]
		b.pressed.connect(func():
			_days = d
			Store.set_value("stats", "days", d)
			_reload())
		row.add_child(b)
		_period_btns.append([b, d])
	var rnames: Array = [""]
	var rlabels: Array = [L.t("Rules: all")]
	for gm in Stats.games():
		var rn: String = gm.get("rules_name", "")
		if rn != "" and not rnames.has(rn):
			rnames.append(rn)
			rlabels.append(_rules_label(rn))
	var ro := UITheme.option(rlabels, 0)
	ro.custom_minimum_size = Vector2(320, 46)
	ro.add_theme_font_size_override("font_size", UITheme.fs(18))
	ro.clip_text = true
	ro.fit_to_longest_item = false
	ro.item_selected.connect(func(i):
		_rules = rnames[i]
		_reload())
	row.add_child(ro)
	# resumo
	_tiles = HBoxContainer.new()
	_tiles.position = Vector2(40, 130)
	_tiles.size = Vector2(1200, 92)
	_tiles.add_theme_constant_override("separation", 10)
	add_child(_tiles)
	# lista
	var lp := PanelContainer.new()
	lp.position = Vector2(40, 236)
	lp.size = Vector2(700, 400)
	add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(_list_row([L.t("Date"), L.t("Rules"), L.t("Opponents"), L.t("Result"), L.t("Pts")], UITheme.GOLD, false))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(660, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	sc.add_child(_list)
	# detalhe
	var dp := PanelContainer.new()
	dp.position = Vector2(756, 236)
	dp.size = Vector2(484, 400)
	add_child(dp)
	var dsc := ScrollContainer.new()
	dsc.custom_minimum_size = Vector2(450, 368)
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dp.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	_detail.custom_minimum_size = Vector2(440, 0)
	dsc.add_child(_detail)
	# rodape
	var bk := UITheme.button(L.t("Back"), 22, Vector2(180, 56))
	bk.position = Vector2(40, 652)
	bk.pressed.connect(func(): back.emit())
	add_child(bk)
	_msg = UITheme.label("", 15, UITheme.MUTED)
	_msg.position = Vector2(236, 664)
	_msg.size = Vector2(380, 40)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_msg)
	var foot := HBoxContainer.new()
	foot.position = Vector2(640, 652)
	foot.add_theme_constant_override("separation", 10)
	add_child(foot)
	var ej := UITheme.button(L.t("Export JSON"), 18, Vector2(190, 56))
	ej.pressed.connect(func(): _export("pentakosmos-estatisticas.json", Stats.export_json()))
	foot.add_child(ej)
	var ec := UITheme.button(L.t("Export CSV"), 18, Vector2(190, 56))
	ec.pressed.connect(func(): _export("pentakosmos-estatisticas.csv", Stats.export_csv()))
	foot.add_child(ec)
	var im := UITheme.button(L.t("Import"), 18, Vector2(190, 56))
	im.pressed.connect(_import)
	foot.add_child(im)


static func _rules_label(rn: String) -> String:
	if rn == "Custom" or rn == "Pentakosmos" or rn == "Archaic":
		return L.t(rn)
	return rn + " ★"


func _list_row(cells: Array, col: Color, button := true, selected := false) -> Control:
	var widths := [130, 150, 190, 130, 40]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for i in range(cells.size()):
		var c: Variant = cells[i]
		var l := UITheme.label(c if c is String else c[0], 17, col if c is String else c[1])
		l.custom_minimum_size = Vector2(widths[i], 0)
		l.clip_text = true
		h.add_child(l)
	if not button:
		return h
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(656, 40)
	if selected:
		b.add_theme_stylebox_override("normal", UITheme.box(Color(0.25, 0.21, 0.12, 0.85), UITheme.GOLD, 1))
	h.position = Vector2(10, 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in h.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	return b


func _reload() -> void:
	for pb in _period_btns:
		pb[0].add_theme_color_override("font_color", UITheme.GOLD if pb[1] == _days else UITheme.TEXT)
	_games = Stats.filtered(_player, _days, _rules)
	_sel = 0
	# resumo
	for ch in _tiles.get_children():
		ch.queue_free()
	var s := Stats.summary(_games, _player)
	var hours := int(s["secs"]) / 3600
	var mins := (int(s["secs"]) / 60) % 60
	var tiles := [[L.t("Games"), str(s["games"])],
		[L.t("Wins"), "%d%%  (%d)" % [roundi(s["win_pct"]), s["wins"]]],
		[L.t("Time played"), ("%d h %02d min" % [hours, mins]) if hours > 0 else ("%d min" % mins)],
		[L.t("Average points in wins"), "%.1f" % s["avg_win_pts"] if s["wins"] > 0 else "—"],
		[L.t("Specialization wins"), str(s["spec_wins"])],
		[L.t("Average time per move"), ("%.0f s" % s["avg_action"]) if s["avg_action"] > 0 else "—"]]
	for t in tiles:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(150, 100)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		p.add_child(v)
		var cap := UITheme.label(t[0], 15, UITheme.MUTED)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.custom_minimum_size = Vector2(110, 0)
		v.add_child(cap)
		v.add_child(UITheme.label(t[1], 26, UITheme.TEXT))
		_tiles.add_child(p)
	_fill_list()
	_fill_detail()


func _fill_list() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	if _games.is_empty():
		_list.add_child(UITheme.label(L.t("No games in this period."), 18, UITheme.MUTED))
		return
	for i in range(_games.size()):
		var gm: Dictionary = _games[i]
		var p := Stats.me(gm, _player)
		var opp: Array = []
		for q in gm["players"]:
			if q["name"] != _player or not q.get("human", false):
				opp.append(q["name"])
		var res: String
		var rcol := UITheme.MUTED
		if p.get("winner", false):
			res = L.t("Win (spec.)") if p.get("win_type", "") == "especializacao" else L.t("Win")
			rcol = Color(0.55, 0.9, 0.6)
		else:
			res = L.f("Place {n} of {total}", {"n": int(p.get("place", 0)), "total": gm["players"].size()})
		var date := Time.get_datetime_string_from_unix_time(int(gm["date"]) + _tz(), true)
		var row := _list_row([date.substr(8, 2) + "/" + date.substr(5, 2) + " " + date.substr(11, 5),
			[_rules_label(gm.get("rules_name", "")), UITheme.GOLD], ", ".join(opp), [res, rcol], str(int(p.get("points", 0)))],
			UITheme.TEXT, true, i == _sel)
		var k := i
		row.pressed.connect(func():
			_sel = k
			_fill_list()
			_fill_detail())
		_list.add_child(row)


static func _tz() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _fill_detail() -> void:
	for ch in _detail.get_children():
		ch.queue_free()
	if _games.is_empty():
		return
	var gm: Dictionary = _games[_sel]
	var p := Stats.me(gm, _player)
	var res := L.t("Win") if p.get("winner", false) else L.f("Place {n} of {total}", {"n": int(p.get("place", 0)), "total": gm["players"].size()})
	_detail.add_child(UITheme.label("%s · %d %s · %s" % [res, int(p.get("points", 0)), L.t("pts"),
		TimerView.clock(float(gm["secs"]))], 20, UITheme.GOLD))
	var acts: int = p.get("actions", 0)
	if acts > 0:
		_detail.add_child(UITheme.label(L.f("{n} s per move", {"n": "%.0f" % (float(p["action_secs"]) / acts)}), 16, UITheme.MUTED))
	_detail.add_child(UITheme.label(L.t("Cards bought"), 17, UITheme.MUTED))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	_detail.add_child(grid)
	grid.add_child(Control.new())
	for c in range(5):
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(28, 26)
		var cc := c
		ic.draw.connect(func(): GemDraw.draw_gem(ic, cc, Vector2(14, 13), 11))
		grid.add_child(ic)
	for lv in [1, 2, 3]:
		grid.add_child(UITheme.label(L.t(Defs.LEVEL_SHORT[lv]), 16, UITheme.TEXT))
		for c in range(5):
			grid.add_child(UITheme.label(str(int(p["bought"][str(lv)][c])), 18, UITheme.TEXT))
	grid.add_child(UITheme.label(L.t("Points"), 16, UITheme.GOLD))
	for c in range(5):
		grid.add_child(UITheme.label(str(int(p["color_pts"][c])), 18, UITheme.GOLD))
	var acad := L.f("Philosophers: {a} (+{b})", {"a": int(p.get("philosophers", 0)), "b": int(p.get("philosopher_pts", 0))})
	if int(p.get("writers", 0)) > 0 or gm["rules"].get("patrons", "") in ["ambos", "escritores"]:
		acad += "   ·   " + L.f("Writers: {a} (+{b})", {"a": int(p.get("writers", 0)), "b": int(p.get("writer_pts", 0))})
	_detail.add_child(UITheme.label(acad, 17, UITheme.TEXT))
	var rl := UITheme.label(L.t("Rules") + ": " + RuleSet.from_dict(gm["rules"]).summary(), 14, UITheme.MUTED)
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.custom_minimum_size = Vector2(430, 0)
	_detail.add_child(rl)


# --- arquivos ---------------------------------------------------------------------
func _export(fname: String, text: String) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(L.t("Export"), OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), fname, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*." + fname.get_extension()]),
			func(ok: bool, paths: PackedStringArray, _f: int):
				if ok and not paths.is_empty():
					_write(paths[0], text))
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	fd.current_file = fname
	fd.size = Vector2i(900, 560)
	fd.file_selected.connect(func(path: String): _write(path, text))
	add_child(fd)
	fd.popup_centered()


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		# sem permissao para aquele lugar: salva na pasta do jogo e avisa onde
		path = "user://" + path.get_file()
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_msg.text = L.t("Could not save the file.")
		return
	f.store_string(text)
	f.close()
	_msg.text = L.f("Saved: {path}", {"path": ProjectSettings.globalize_path(path)})


func _import() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(L.t("Import"), OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.json"]),
			func(ok: bool, paths: PackedStringArray, _f: int):
				if ok and not paths.is_empty():
					_read(paths[0]))
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	fd.filters = PackedStringArray(["*.json"])
	fd.size = Vector2i(900, 560)
	fd.file_selected.connect(_read)
	add_child(fd)
	fd.popup_centered()


func _read(path: String) -> void:
	var n := Stats.import_json(FileAccess.get_file_as_string(path))
	if n < 0:
		_msg.text = L.t("This file is not a Pentakosmos statistics file.")
		return
	_msg.text = L.f("{n} games imported.", {"n": n})
	var names := Stats.human_names()
	if _player == "" and not names.is_empty():
		_player = names[0]
	for ch in get_children():
		ch.queue_free()
	_period_btns = []
	_build()
	_reload()
	_msg.text = L.f("{n} games imported.", {"n": n})
