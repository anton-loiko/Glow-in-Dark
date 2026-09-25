extends Node
## Музыка и короткие звуки. Настройки берутся из профиля и применяются по EventBus.settings_changed.
## SFX играют из фиксированного пула плееров (без создания узлов на каждый звук).
## Шины, pitch-серии и ducking — task_8.

const SFX_POOL_SIZE: int = 16

var playlist: Array[AudioStream] = [
	preload("res://src/assets/audio/Piano_1.ogg"),
	preload("res://src/assets/audio/Piano_2.ogg"),
	preload("res://src/assets/audio/Piano_3.ogg"),
	preload("res://src/assets/audio/Piano_4.ogg"),
	preload("res://src/assets/audio/Piano_5.ogg"),
	preload("res://src/assets/audio/Piano_6.ogg"),
	preload("res://src/assets/audio/Piano_7.ogg"),
	preload("res://src/assets/audio/Piano_8.ogg"),
]

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _track_index: int = 0
var _next_sfx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)
	playlist.shuffle()
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.profile_loaded.connect(apply_settings)
	apply_settings()


func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null or not _settings().sfx:
		return
	var player: AudioStreamPlayer = _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func apply_settings() -> void:
	if _music_player == null:
		return
	if _settings().music:
		if not _music_player.playing:
			if _music_player.stream == null:
				_play_current_track()
			else:
				_music_player.play()
	else:
		_music_player.stop()


func _settings() -> PlayerProfile.Settings:
	return GameManager.profile.settings if GameManager.profile != null else PlayerProfile.Settings.new()


func _play_current_track() -> void:
	_music_player.stream = playlist[_track_index]
	if _settings().music:
		_music_player.play()


func _on_music_finished() -> void:
	_track_index += 1
	if _track_index >= playlist.size():
		_track_index = 0
		playlist.shuffle()
	_play_current_track()


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == &"music":
		apply_settings()
