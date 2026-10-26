extends Node
## Gerenciador de audio (autoload "Audio").
## Efeitos: res://assets/sfx/<nome>.ogg (personalizado) ou <nome>.wav (provisorio).
## Musica: as faixas listadas em res://data/music.json (gravadas a partir de partituras
## em dominio publico; veja tools/musica/). Modos: "calm", "lively", "all", "off"
## ou "track:<id>" (uma faixa so, repetida).

signal track_started(info: Dictionary)
signal state_changed

const SFX := ["click", "select", "token", "chip", "buy", "reserve", "noble", "error", "turn", "win", "discard"]
const POOL := 16

var _streams := {}
var _pool: Array = []
var _next := 0
var _music: AudioStreamPlayer
var tracks: Array = []        # registros de data/music.json
var mode := "all"
var current: Dictionary = {}
var _queue: Array = []
var _history: Array = []      # faixas ja tocadas (para "anterior")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SFX:
		for ext in ["ogg", "wav"]:
			var path := "res://assets/sfx/%s.%s" % [n, ext]
			if ResourceLoader.exists(path):
				_streams[n] = load(path)
				break
	for i in range(POOL):
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(_next_track)
	if FileAccess.file_exists("res://data/music.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/music.json"))
		if data is Array:
			for t in data:
				if ResourceLoader.exists(t["file"]):
					tracks.append(t)
	mode = str(Store.get_value("audio", "playlist", "all"))
	set_volume("Music", Store.get_value("audio", "music", 0.6))
	set_volume("SFX", Store.get_value("audio", "sfx", 0.8))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")


func play(sfx_name: String, pitch_var := 0.06, volume_db := 0.0) -> void:
	if not _streams.has(sfx_name):
		return
	var pl: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL
	pl.stream = _streams[sfx_name]
	pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	pl.volume_db = volume_db
	pl.play()


func start_music() -> void:
	if _music.playing or mode == "off":
		return
	_next_track()


func set_mode(m: String) -> void:
	## Troca a playlist e comeca imediatamente.
	mode = m
	Store.set_value("audio", "playlist", m)
	_queue = []
	_history = []
	_music.stop()
	current = {}
	if m != "off":
		_next_track()


func _pool_for(m: String) -> Array:
	if m.begins_with("track:"):
		return tracks.filter(func(t): return t["id"] == m.substr(6))
	if m == "all":
		return tracks.duplicate()
	return tracks.filter(func(t): return t["playlist"] == m)


func _next_track() -> void:
	if mode == "off" or tracks.is_empty():
		return
	if _queue.is_empty():
		_queue = _pool_for(mode)
		if _queue.is_empty():
			return
		_queue.shuffle()
		# nao repete a ultima faixa logo em seguida
		if _queue.size() > 1 and not current.is_empty() and _queue[0]["id"] == current["id"]:
			_queue.push_back(_queue.pop_front())
	if not current.is_empty():
		_history.append(current)
	current = _queue.pop_front()
	_play_current()


func _play_current() -> void:
	_music.stream = load(current["file"])
	_music.stream_paused = false
	_music.play()
	track_started.emit(current)
	state_changed.emit()


# --- controles do tocador (tela de jogo) -------------------------------------
func next_track() -> void:
	if mode == "off":
		return
	_next_track()


func prev_track() -> void:
	## Volta para a faixa anterior; se a atual ja tocou mais de 5 s, recomeca a atual.
	if mode == "off" or current.is_empty():
		return
	if _music.get_playback_position() > 5.0 or _history.is_empty():
		_music.play(0.0)
		_music.stream_paused = false
		state_changed.emit()
		return
	_queue.push_front(current)
	current = _history.pop_back()
	_play_current()


func toggle_pause() -> void:
	if mode == "off":
		return
	if current.is_empty():
		_next_track()
		return
	_music.stream_paused = not _music.stream_paused
	state_changed.emit()


func is_paused() -> bool:
	return mode == "off" or current.is_empty() or _music.stream_paused


func set_volume(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)


func get_volume(bus_name: String) -> float:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


func save_volumes() -> void:
	Store.set_value("audio", "music", get_volume("Music"))
	Store.set_value("audio", "sfx", get_volume("SFX"))
