class_name Store
extends RefCounted
## Preferencias salvas em user://settings.cfg (volumes, ultima configuracao,
## predefinicoes criadas pelo jogador).

const PATH := "user://settings.cfg"


static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)
	return c


static func get_value(section: String, key: String, default = null):
	var c := _cfg()
	if not c.has_section_key(section, key):
		return default
	return c.get_value(section, key)


static func set_value(section: String, key: String, value) -> void:
	var c := _cfg()
	c.set_value(section, key, value)
	c.save(PATH)


static func custom_presets() -> Dictionary:
	## nome -> dicionario de regras
	return get_value("presets", "custom", {})


static func save_custom_preset(name: String, rules: RuleSet) -> void:
	var d := custom_presets()
	d[name] = rules.to_dict()
	set_value("presets", "custom", d)


static func delete_custom_preset(name: String) -> void:
	var d := custom_presets()
	d.erase(name)
	set_value("presets", "custom", d)
