class_name Files
extends RefCounted
## Janelas de "salvar como" e "abrir": a do sistema quando existe (Android, Windows, macOS,
## Linux com portal), senao a do Godot. Sem permissao para gravar onde o jogador escolheu,
## grava na pasta do jogo e avisa onde.


static func save_dialog(parent: Node, title: String, fname: String, on_path: Callable) -> void:
	var ext := fname.get_extension()
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(title, OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), fname, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*." + ext]),
			func(ok: bool, paths: PackedStringArray, _f: int):
				if ok and not paths.is_empty():
					on_path.call(paths[0]))
		return
	var fd := FileDialog.new()
	fd.title = title
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	fd.current_file = fname
	fd.filters = PackedStringArray(["*." + ext])
	fd.size = Vector2i(900, 560)
	fd.file_selected.connect(func(path: String): on_path.call(path))
	parent.add_child(fd)
	fd.popup_centered()


static func open_dialog(parent: Node, title: String, exts: Array, on_path: Callable) -> void:
	var filters := PackedStringArray()
	for e in exts:
		filters.append("*." + str(e))
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(title, OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			func(ok: bool, paths: PackedStringArray, _f: int):
				if ok and not paths.is_empty():
					on_path.call(paths[0]))
		return
	var fd := FileDialog.new()
	fd.title = title
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	fd.filters = filters
	fd.size = Vector2i(900, 560)
	fd.file_selected.connect(func(path: String): on_path.call(path))
	parent.add_child(fd)
	fd.popup_centered()


static func write_text(path: String, text: String) -> String:
	## Grava; devolve o caminho onde ficou ("" se nao deu).
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		path = "user://" + path.get_file()
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return ProjectSettings.globalize_path(path)


static func writable(path: String) -> String:
	## Caminho onde e possivel gravar: o escolhido, ou um na pasta do jogo.
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.close()
		return path
	return "user://" + path.get_file()
