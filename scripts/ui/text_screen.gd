class_name TextScreen
extends Control
## Tela de textos: "Como jogar" (com abas) e "Processo criativo".
## Os textos ficam em res://data/texts/<nome>_<idioma>.txt (BBCode do Godot);
## sem o arquivo do idioma atual, usa o ingles.

signal back

const PAGES := {
	"rules": [["Pentakosmos", "rules_pentakosmos"], ["Legacy", "rules_legacy"], ["Opponents", "opponents"]],  # tr
	"story": [["Creative process", "story"], ["Music", "music"]],  # tr
}

var which := "rules"
var _text: RichTextLabel
var _tabs: Array = []


func _init() -> void:
	size = Vector2(1280, 720)


func _ready() -> void:
	var title := UITheme.label(L.t("How to play") if which == "rules" else L.t("Creative process"), 34, UITheme.GOLD)
	title.position = Vector2(0, 14)
	title.size = Vector2(1280, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var pages: Array = PAGES[which]
	if pages.size() > 1:
		var bar := HBoxContainer.new()
		bar.position = Vector2(60, 66)
		bar.add_theme_constant_override("separation", 8)
		add_child(bar)
		for i in range(pages.size()):
			var b := UITheme.button(L.t(pages[i][0]), 17, Vector2(200, 40))
			b.toggle_mode = true
			b.pressed.connect(_open.bind(i))
			bar.add_child(b)
			_tabs.append(b)
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 114 if pages.size() > 1 else 70)
	panel.size = Vector2(1160, 530 if pages.size() > 1 else 574)
	add_child(panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.selection_enabled = false
	_text.add_theme_font_size_override("normal_font_size", 18)
	_text.add_theme_font_size_override("bold_font_size", 18)
	_text.add_theme_color_override("default_color", UITheme.TEXT)
	_text.meta_clicked.connect(func(m): OS.shell_open(str(m)))
	panel.add_child(_text)
	var b2 := UITheme.button(L.t("Back"), 19, Vector2(200, 48))
	b2.position = Vector2(540, 660)
	b2.pressed.connect(func(): back.emit())
	add_child(b2)
	_open(0)


func _open(i: int) -> void:
	for k in range(_tabs.size()):
		_tabs[k].set_pressed_no_signal(k == i)
	var page: String = PAGES[which][i][1]
	_text.text = load_text(page)
	_text.scroll_to_line(0)


static func load_text(page: String) -> String:
	if page == "music":
		return music_credits()
	for code in [L.code, "en"]:
		var path := "res://data/texts/%s_%s.txt" % [page, code]
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_string(path)
	return ""


static func music_credits() -> String:
	## Creditos gerados a partir de data/music.json (nomes proprios; o texto curto e traduzido).
	var out := "[font_size=26][color=#f0c96a][b]%s[/b][/color][/font_size]\n" % L.t("Music")
	out += L.t("Every track was synthesized for Pentakosmos from public-domain compositions, using freely licensed scores from the Mutopia Project and the GeneralUser GS sound bank (by S. Christian Collins). No commercial recording was used.") + "\n\n"
	for t in Audio.tracks:
		out += "[b]%s[/b] — %s (%s)\n" % [t["title"], t["composer"], t["year"]]
		out += "[color=#9aa0b0]%s · %s: %s · %s: %s[/color]\n" % [t["score"], L.t("score"), t["score_license"],
			L.t("recording"), t["recording_license"]]
		out += "[url=%s][color=#8fb8ff]%s[/color][/url]\n\n" % [t["score_url"], t["score_url"].replace("https://", "")]
	return out
