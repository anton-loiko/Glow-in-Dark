extends Node
## Время мира: hit-stop, плавное изменение time_scale, пауза мира со стеком причин
## (левел-ап, пауза, «Свет угас» не конфликтуют). UI-анимации обязаны игнорировать time_scale
## (Tween.set_ignore_time_scale(true)) и работать при паузе (PROCESS_MODE_ALWAYS).

## Общий такт «дыхания» (t.breath, DS §05): Огонёк, Ember «В БОЙ» и Маяк дышат синхронно.
const BREATH_PERIOD_S: float = 1.2

var _pause_reasons: Array[StringName] = []
var _hit_stop_active: bool = false
var _ramp_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _notification(what: int) -> void:
	# Единственная точка автопаузы при сворачивании приложения (DS S05 → S07).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if GameManager.is_run_active() and not is_world_paused():
			SceneRouter.open_modal(&"S07")


func pause_world(reason: StringName) -> void:
	if _pause_reasons.has(reason):
		return
	_pause_reasons.append(reason)
	if _pause_reasons.size() == 1:
		get_tree().paused = true
		EventBus.run_paused.emit(reason)


func resume_world(reason: StringName) -> void:
	_pause_reasons.erase(reason)
	if _pause_reasons.is_empty() and get_tree().paused:
		get_tree().paused = false
		EventBus.run_resumed.emit()


func is_world_paused() -> bool:
	return not _pause_reasons.is_empty()


func pause_reasons() -> Array[StringName]:
	return _pause_reasons.duplicate()


## Полная остановка мира на ms миллисекунд реального времени.
func hit_stop(ms: int) -> void:
	if _hit_stop_active or ms <= 0:
		return
	_hit_stop_active = true
	var previous: float = Engine.time_scale
	Engine.time_scale = 0.0
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = previous
	_hit_stop_active = false


## Плавный переход time_scale к target за ms миллисекунд реального времени.
func ramp_time_scale(target: float, ms: int) -> Tween:
	if _ramp_tween != null and _ramp_tween.is_valid():
		_ramp_tween.kill()
	_ramp_tween = create_tween().set_ignore_time_scale(true)
	_ramp_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ramp_tween.tween_method(_set_time_scale, Engine.time_scale, target, ms / 1000.0)
	return _ramp_tween


## Фаза дыхания 0..1 (синус), по реальному времени.
func breath_phase() -> float:
	var t: float = Time.get_ticks_msec() / 1000.0
	return 0.5 + 0.5 * sin(t * TAU / BREATH_PERIOD_S)


func reset() -> void:
	_pause_reasons.clear()
	get_tree().paused = false
	Engine.time_scale = 1.0


func _set_time_scale(value: float) -> void:
	Engine.time_scale = value
