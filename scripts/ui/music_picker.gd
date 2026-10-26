class_name MusicPicker
extends RefCounted
## Seletor de playlist (menu inicial e pausa): calma, animada, todas, desligada
## ou uma faixa especifica.

const MODES := ["calm", "lively", "all", "off"]
const MODE_NAMES := ["Calm", "Lively", "All (shuffled)", "Off"]  # tr


static func make() -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(120, 36)
	o.fit_to_longest_item = false
	o.clip_text = true
	o.add_theme_font_size_override("font_size", 15)
	var values: Array = []
	for i in range(MODES.size()):
		o.add_item(L.t(MODE_NAMES[i]))
		values.append(MODES[i])
	o.add_separator()
	values.append("")
	for t in Audio.tracks:
		o.add_item("%s — %s" % [t["composer"], t["title"]])
		values.append("track:" + t["id"])
	var idx := values.find(Audio.mode)
	o.select(maxi(idx, 0))
	o.item_selected.connect(func(i):
		if values[i] != "":
			Audio.set_mode(values[i])
			Audio.play("select"))
	return o
