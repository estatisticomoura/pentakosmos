extends Node
## Gerenciador de audio (autoload "Audio").
## Efeitos: res://assets/sfx/<nome>.ogg (personalizado) ou <nome>.wav (provisorio).
## Musica: res://assets/music/trilha_01.ogg ... trilha_20.ogg, tocadas em sequencia.
## Sem trilhas proprias, toca a ambientacao provisoria (ambiente_provisorio.wav).

const SFX := ["click", "select", "token", "chip", "buy", "reserve", "noble", "error", "turn", "win", "discard"]
const POOL := 16

var _streams := {}
var _pool: Array = []
var _next := 0
var _music: AudioStreamPlayer
var _tracks: Array = []
var _track_i := 0


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
	_music.finished.connect(_on_music_finished)
	for i in range(1, 21):
		var path := "res://assets/music/trilha_%02d.ogg" % i
		if ResourceLoader.exists(path):
			_tracks.append(path)
	if _tracks.is_empty() and ResourceLoader.exists("res://assets/music/ambiente_provisorio.wav"):
		_tracks.append("res://assets/music/ambiente_provisorio.wav")
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
	if _tracks.is_empty() or _music.playing:
		return
	_music.stream = load(_tracks[_track_i])
	_music.play()


func _on_music_finished() -> void:
	_track_i = (_track_i + 1) % _tracks.size()
	_music.stream = load(_tracks[_track_i])
	_music.play()


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
