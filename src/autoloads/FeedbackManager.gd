extends Node
## Отклик на события (DS §06): реплика = звук (AudioManager) + хаптика. Таблица — configs/audio.json → cues.
## Хаптика троттлится по виду и уважает тоггл «Вибрация»; iOS/Android — Input.vibrate_handheld
## (уровни UIFeedbackGenerator через нативный плагин — в бэклоге). Сам слушает факты без явного вызова:
## спавн Шёпота (глаза) и Гасителя, воскрешение, свет < 25% (сердцебиение + low-pass каждые 1.2 с).

## Вид → [длительность мс, амплитуда 0..1].
const PATTERNS: Dictionary = {
	&"selection": [10, 0.2],
	&"light": [15, 0.35],
	&"medium": [25, 0.55],
	&"heavy": [40, 0.9],
	&"rigid": [20, 0.8],
	&"soft": [30, 0.3],
	&"success": [35, 0.6],
}
## Минимальный интервал между вибрациями одного вида, мс (DS §06: искра ≤ 1/80 мс, сожжён ≤ 1/120 мс).
const THROTTLE_MS: Dictionary = {
	&"selection": 80,
	&"light": 120,
	&"soft": 300,
}

var haptics_sent: int = 0 ## для тестов
var _last_ms: Dictionary = {}
var _low_light: bool = false
var _low_light_timer_s: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.player_revived.connect(_on_player_revived)
	EventBus.player_light_changed.connect(_on_light_changed)
	EventBus.run_ended.connect(_on_run_ended)


## Реплика по имени из configs/audio.json → cues. pitch — множитель высоты звука.
func cue(cue_name: StringName, pitch: float = 1.0) -> void:
	var cues: Dictionary = ConfigDB.get_config("audio").get("cues", {}) as Dictionary
	var entry: Dictionary = cues.get(String(cue_name), {}) as Dictionary
	if entry.is_empty():
		push_warning("[FeedbackManager] unknown cue '%s'" % cue_name)
		return
	if entry.has("sfx"):
		var sfx: StringName = StringName(str(entry["sfx"]))
		if bool(entry.get("series", false)):
			AudioManager.play_series(sfx)
		else:
			AudioManager.play(sfx, pitch)
	if entry.has("haptic"):
		haptic(StringName(str(entry["haptic"])))


func haptic(kind: StringName) -> void:
	if not PATTERNS.has(kind):
		push_warning("[FeedbackManager] unknown haptic '%s'" % kind)
		return
	if GameManager.profile == null or not GameManager.profile.settings.vibration:
		return
	var now: int = Time.get_ticks_msec()
	var min_gap: int = THROTTLE_MS.get(kind, 0)
	if now - int(_last_ms.get(kind, -100000)) < min_gap:
		return
	_last_ms[kind] = now
	haptics_sent += 1
	var pattern: Array = PATTERNS[kind]
	Input.vibrate_handheld(int(pattern[0]), float(pattern[1]))


## Сожжён враг: «пшш», высота по размеру (S выше, XL ниже).
func enemy_burned(archetype: StringName) -> void:
	var def: EnemyDef = ConfigDB.get_enemy(archetype)
	var by_size: Dictionary = ConfigDB.get_config("audio").get("burn_pitch_by_size", {}) as Dictionary
	cue(&"enemy_burned", float(by_size.get(String(def.size_class) if def != null else "M", 1.0)))


## Урон игроку: звук + хаптика (Щит → soft) + искажение музыки 200 мс.
func player_hit(shielded: bool) -> void:
	cue(&"player_hit_shield" if shielded else &"player_hit")
	AudioManager.hit_distortion()


## Телеграф атаки врага (E-атаки): у Жнеца — замах, у Пожирателя — «клац».
func telegraph(archetype: StringName) -> void:
	match archetype:
		&"reaper":
			cue(&"reaper_windup")
		&"devourer":
			cue(&"devourer_bite")


func _process(delta: float) -> void:
	_low_light_timer_s -= delta
	if _low_light_timer_s <= 0.0:
		_low_light_timer_s = float((ConfigDB.get_config("audio").get("low_light", {}) as Dictionary).get("heartbeat_every_s", 1.2))
		cue(&"low_light")


func _on_light_changed(current: float, max_value: float) -> void:
	var threshold: float = float((ConfigDB.get_config("audio").get("low_light", {}) as Dictionary).get("threshold", 0.25))
	var low: bool = max_value > 0.0 and current > 0.0 and current / max_value < threshold
	if low == _low_light:
		return
	_low_light = low
	_low_light_timer_s = 0.0
	set_process(low)
	AudioManager.set_low_light(low)


func _on_run_ended(_result: RunResult) -> void:
	_low_light = false
	set_process(false)
	AudioManager.set_low_light(false)


func _on_enemy_spawned(archetype: StringName) -> void:
	match archetype:
		&"whisper":
			cue(&"enemy_eyes")
		&"extinguisher":
			cue(&"extinguisher")


func _on_player_revived(_source: StringName) -> void:
	cue(&"revive")
