extends Node
## Звук (DS §06): шины Master/Music/SFX/UI/Ambience (default_bus_layout.tres), пул SFX-плееров без создания
## узлов в бою, лимит одновременных одинаковых звуков, кулдауны, приоритеты (при нехватке плееров новый звук
## вытесняет самый низкоприоритетный), серия искр +1 полутон. Таблица — configs/audio.json.
## Музыка: тема хаба; в забеге — синхронные слои (база + ударные), громкость слоёв по фазе волны,
## аккорд-разрешение на Награде. Low-pass при свете < 25%, дисторсия 200 мс на урон, −60% на время RV.

const SFX_DIR: String = "res://src/assets/audio/sfx/"
const MUSIC_DIR: String = "res://src/assets/audio/music/"
const BUS_MUSIC: StringName = &"Music"

var _cfg: Dictionary = {}
var _streams: Dictionary = {} ## event -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _player_event: Array[StringName] = []
var _player_priority: Array[int] = []
var _last_play_ms: Dictionary = {}
var _series_steps: int = 0
var _series_last_ms: int = -100000

var _music_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _run_music: AudioStreamSynchronized
var _music_state: StringName = &""
var _duck_tween: Tween
var _layer_tween: Tween
var _distortion_until_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = ConfigDB.get_config("audio")
	for i: int in int(_cfg.get("pool_size", 24)):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
		_player_event.append(&"")
		_player_priority.append(0)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.bus = BUS_MUSIC
	add_child(_stinger_player)
	_load_streams()
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.profile_loaded.connect(apply_settings)
	EventBus.wave_phase_changed.connect(_on_wave_phase)
	EventBus.run_started.connect(_on_run_started)
	EventBus.screen_changed.connect(_on_screen_changed)
	apply_settings()


func _notification(what: int) -> void:
	# Стоп при сворачивании (DS §06), продолжение при возврате.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_music_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_music_player.stream_paused = false


func _process(_delta: float) -> void:
	if _distortion_until_ms > 0 and Time.get_ticks_msec() >= _distortion_until_ms:
		_distortion_until_ms = 0
		_set_music_effect(1, false)


# --- SFX -----------------------------------------------------------------------

## Проиграть звук события. pitch — множитель высоты (серия искр, размер врага). false — отброшен лимитами.
func play(event: StringName, pitch: float = 1.0) -> bool:
	var ev: Dictionary = (_cfg.get("events", {}) as Dictionary).get(String(event), {}) as Dictionary
	var stream: AudioStream = _streams.get(event) as AudioStream
	if ev.is_empty() or stream == null or not _settings().sfx:
		return false
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play_ms.get(event, -100000)) < int(ev.get("cooldown_ms", 0)):
		return false
	if _active_voices(event) >= int(ev.get("voices", 2)):
		return false
	var priority: int = int(ev.get("priority", 1))
	var index: int = _free_player(priority)
	if index < 0:
		return false
	_last_play_ms[event] = now
	var player: AudioStreamPlayer = _players[index]
	player.stop()
	player.stream = stream
	player.bus = StringName(str(ev.get("bus", "SFX")))
	player.volume_db = float(ev.get("volume_db", 0.0))
	var spread: float = float(ev.get("pitch_random", 0.0))
	var jitter: float = pow(2.0, randf_range(-spread, spread) / 12.0) if spread > 0.0 else 1.0
	player.pitch_scale = clampf(pitch * jitter, 0.25, 4.0)
	player.play()
	_player_event[index] = event
	_player_priority[index] = priority
	return true


## Серия искр: +1 полутон за искру в окне 400 мс, до +12 (DS §06).
func play_series(event: StringName) -> bool:
	var series: Dictionary = _cfg.get("spark_series", {}) as Dictionary
	var now: int = Time.get_ticks_msec()
	if now - _series_last_ms <= int(series.get("window_ms", 400)):
		_series_steps = mini(_series_steps + 1, int(series.get("max_steps", 12)))
	else:
		_series_steps = 0
	_series_last_ms = now
	return play(event, pow(2.0, _series_steps / 12.0))


func series_step() -> int:
	return _series_steps


func _active_voices(event: StringName) -> int:
	var n: int = 0
	for i: int in _players.size():
		if _players[i].playing and _player_event[i] == event:
			n += 1
	return n


## Свободный плеер или вытеснение самого низкоприоритетного (не выше нового).
func _free_player(priority: int) -> int:
	var victim: int = -1
	for i: int in _players.size():
		if not _players[i].playing:
			return i
		if _player_priority[i] <= priority and (victim < 0 or _player_priority[i] < _player_priority[victim]):
			victim = i
	return victim


func _load_streams() -> void:
	for event: String in (_cfg.get("events", {}) as Dictionary):
		var path: String = SFX_DIR + str(((_cfg["events"] as Dictionary)[event] as Dictionary).get("file", event)) + ".ogg"
		if ResourceLoader.exists(path):
			_streams[StringName(event)] = load(path)


# --- Музыка --------------------------------------------------------------------

func play_hub_music() -> void:
	if _music_state == &"hub":
		return
	_music_state = &"hub"
	var hub: Dictionary = (_cfg.get("music", {}) as Dictionary).get("hub", {}) as Dictionary
	_switch_music(_loop_stream(str(hub.get("file", "hub"))), float(hub.get("volume_db", -6.0)))


func play_run_music() -> void:
	_music_state = &"run"
	var music: Dictionary = _cfg.get("music", {}) as Dictionary
	_run_music = AudioStreamSynchronized.new()
	var layers: Array = music.get("run_layers", [])
	_run_music.stream_count = layers.size()
	for i: int in layers.size():
		_run_music.set_sync_stream(i, _loop_stream(str(layers[i])))
	_switch_music(_run_music, 0.0)
	_apply_layers(&"calm", 0.0)


## Громкость слоёв по фазе волны: Напряжение добавляет ударные; Награда — аккорд-разрешение.
func _on_wave_phase(phase: StringName) -> void:
	if _music_state != &"run":
		return
	_apply_layers(phase, float((_cfg.get("music", {}) as Dictionary).get("fade_s", 1.5)))
	if phase == &"reward":
		var stinger: String = str((_cfg.get("music", {}) as Dictionary).get("reward_stinger", ""))
		var path: String = MUSIC_DIR + stinger + ".ogg"
		if not stinger.is_empty() and ResourceLoader.exists(path) and _settings().music:
			_stinger_player.stream = load(path)
			_stinger_player.volume_db = -6.0
			_stinger_player.play()


func _apply_layers(phase: StringName, fade_s: float) -> void:
	if _run_music == null:
		return
	var table: Dictionary = (_cfg.get("music", {}) as Dictionary).get("run_layer_volume_db", {}) as Dictionary
	var volumes: Array = table.get(String(phase), table.get("calm", [0, -60]))
	if _layer_tween != null and _layer_tween.is_valid():
		_layer_tween.kill()
	if fade_s <= 0.0:
		for i: int in mini(volumes.size(), _run_music.stream_count):
			_run_music.set_sync_stream_volume(i, float(volumes[i]))
		return
	_layer_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i: int in mini(volumes.size(), _run_music.stream_count):
		_layer_tween.parallel().tween_method(_set_layer_volume.bind(i), _run_music.get_sync_stream_volume(i), float(volumes[i]), fade_s)


func _set_layer_volume(volume_db: float, index: int) -> void:
	if _run_music != null:
		_run_music.set_sync_stream_volume(index, volume_db)


func _switch_music(stream: AudioStream, volume_db: float) -> void:
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	if _settings().music:
		_music_player.play()


func _loop_stream(file_name: String) -> AudioStream:
	var path: String = MUSIC_DIR + file_name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStreamOggVorbis = (load(path) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	stream.loop = true
	return stream


func _on_run_started(_run_id: String, _chapter_id: int) -> void:
	play_run_music()


func _on_screen_changed(screen_id: StringName) -> void:
	if screen_id in [&"S01", &"S02", &"S04", &"S10", &"S11", &"S12", &"S13"] and not GameManager.is_run_active():
		set_low_light(false)
		play_hub_music()


## Свет < 25%: low-pass на музыке (DS §06).
func set_low_light(on: bool) -> void:
	_set_music_effect(0, on)


## Урон: искажение музыки на 200 мс.
func hit_distortion() -> void:
	_set_music_effect(1, true)
	_distortion_until_ms = Time.get_ticks_msec() + int(_cfg.get("hit_distortion_ms", 200))


func _set_music_effect(effect_index: int, enabled: bool) -> void:
	var bus: int = AudioServer.get_bus_index(BUS_MUSIC)
	if bus >= 0 and effect_index < AudioServer.get_bus_effect_count(bus):
		AudioServer.set_bus_effect_enabled(bus, effect_index, enabled)


## Приглушить музыку (RV-реклама — на 60%, DS §06). amount 0 — вернуть громкость.
func duck_music(amount: float, duration_s: float = 0.3) -> void:
	var bus: int = AudioServer.get_bus_index(BUS_MUSIC)
	if bus < 0:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var target_db: float = -4.0 + linear_to_db(clampf(1.0 - amount, 0.001, 1.0))
	_duck_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_duck_tween.tween_method(_set_music_bus_db.bind(bus), AudioServer.get_bus_volume_db(bus), target_db, duration_s)


func _set_music_bus_db(value: float, bus: int) -> void:
	AudioServer.set_bus_volume_db(bus, value)


# --- Настройки -----------------------------------------------------------------

func apply_settings() -> void:
	if _music_player == null:
		return
	if _settings().music:
		if not _music_player.playing and _music_player.stream != null:
			_music_player.play()
	else:
		_music_player.stop()
		_stinger_player.stop()


func _settings() -> PlayerProfile.Settings:
	return GameManager.profile.settings if GameManager.profile != null else PlayerProfile.Settings.new()


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == &"music":
		apply_settings()
