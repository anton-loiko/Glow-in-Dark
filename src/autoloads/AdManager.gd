extends Node
## Rewarded Video по плейсментам (GDD 5.3, D15, D17). Интерстишалов нет.
## Каждый потребитель получает только СВОЙ плейсмент: EventBus.ad_reward_granted(placement).
## Лимиты (1 за забег, 3 в день, раз в 8 ч) — task_7.

var backend: AdsBackend = MockAdsBackend.new()
var _showing: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_backend(backend)


func set_backend(new_backend: AdsBackend) -> void:
	if backend != null and backend.rewarded_finished.is_connected(_on_rewarded_finished):
		backend.rewarded_finished.disconnect(_on_rewarded_finished)
		backend.rewarded_failed.disconnect(_on_rewarded_failed)
	backend = new_backend
	backend.rewarded_finished.connect(_on_rewarded_finished)
	backend.rewarded_failed.connect(_on_rewarded_failed)
	backend.initialize()


func is_known_placement(placement: StringName) -> bool:
	var placements: Dictionary = ConfigDB.get_config("ads").get("placements", {}) as Dictionary
	return placements.has(String(placement))


func is_rewarded_ready(placement: StringName) -> bool:
	return is_known_placement(placement) and _showing == &"" and backend.is_rewarded_ready()


## Показывается только из кнопок с глифом ▶ (DS правило 4).
func show_rewarded(placement: StringName) -> void:
	if not is_known_placement(placement):
		push_error("[AdManager] unknown placement '%s'" % placement)
		EventBus.ad_failed.emit(placement)
		return
	if _showing != &"":
		EventBus.ad_failed.emit(placement)
		return
	_showing = placement
	Telemetry.log_event(&"ad_started", {"placement": String(placement)})
	TimeService.pause_world(&"ad")
	backend.show_rewarded(placement)


func _on_rewarded_finished(placement: StringName, rewarded: bool) -> void:
	_showing = &""
	TimeService.resume_world(&"ad")
	Telemetry.log_event(&"ad_completed", {"placement": String(placement), "rewarded": rewarded})
	if rewarded:
		EventBus.ad_reward_granted.emit(placement)
	else:
		EventBus.ad_failed.emit(placement)


func _on_rewarded_failed(placement: StringName, reason: String) -> void:
	_showing = &""
	TimeService.resume_world(&"ad")
	Telemetry.log_event(&"ad_failed", {"placement": String(placement), "reason": reason})
	EventBus.ad_failed.emit(placement)
