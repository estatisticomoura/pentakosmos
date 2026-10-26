extends SceneTree
## Grava os parametros padrao e as faixas da IA em JSON (usado por tools/evoluir.py).
## Uso: godot --headless --path . --script res://tests/exportar_parametros.gd -- saida.json
func _init() -> void:
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify({"defaults": AIProfiles.DEFAULTS, "ranges": AIProfiles.RANGES, "ints": AIProfiles.INT_PARAMS}))
	f.close()
	quit()
