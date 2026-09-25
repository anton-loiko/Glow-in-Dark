extends Node
## Хаптика (Design System §06). Троттлинг по виду, уважает тоггл «Вибрация».
## Уровни iOS/Android через нативный плагин — task_8; сейчас фолбэк на Input.vibrate_handheld.

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
## Минимальный интервал между вибрациями одного вида, мс.
const THROTTLE_MS: Dictionary = {
	&"selection": 80,
	&"light": 120,
}

var _last_ms: Dictionary = {}


func _ready() -> void:
	set_process(false)


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
	var pattern: Array = PATTERNS[kind]
	Input.vibrate_handheld(int(pattern[0]), float(pattern[1]))
