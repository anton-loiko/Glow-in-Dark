extends Node
## Rewarded Video по плейсментам (GDD 5.3, D15, D17). Интерстишалов нет.
## Каждый потребитель получает только СВОЙ плейсмент: EventBus.ad_reward_granted(placement).
## Лимиты из configs/ads.json: per_run (по run_id), per_day (локальные сутки), cooldown_h, shared (общий с другим).
## Награда за один показ выдаётся ровно один раз: повторный колбэк бэкенда по тому же показу игнорируется.

var backend: AdsBackend
var _showing: StringName = &""
var _run_id: String = ""
var _run_counts: Dictionary[String, int] = {}
var _opportunities: Dictionary[String, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_backend(_default_backend())
	EventBus.screen_changed.connect(_on_screen_changed)


func _on_screen_changed(_screen_id: StringName) -> void:
	reset_opportunities()


## Appodeal на устройстве; Mock — только в debug (редактор); в релизе без плагина реклама просто недоступна.
func _default_backend() -> AdsBackend:
	if AppodealBackend.is_supported():
		return AppodealBackend.new()
	return MockAdsBackend.new() if OS.is_debug_build() else AdsBackend.new()


func set_backend(new_backend: AdsBackend) -> void:
	if backend != null and backend.rewarded_finished.is_connected(_on_rewarded_finished):
		backend.rewarded_finished.disconnect(_on_rewarded_finished)
		backend.rewarded_failed.disconnect(_on_rewarded_failed)
	backend = new_backend
	backend.rewarded_finished.connect(_on_rewarded_finished)
	backend.rewarded_failed.connect(_on_rewarded_failed)
	backend.initialize()


func config() -> Dictionary:
	return ConfigDB.get_config("ads")


func placement_cfg(placement: StringName) -> Dictionary:
	return (config().get("placements", {}) as Dictionary).get(String(placement), {}) as Dictionary


func is_known_placement(placement: StringName) -> bool:
	return not placement_cfg(placement).is_empty()


## Реклама готова И лимит плейсмента не исчерпан. Кнопка ▶ без готовой рекламы — Disabled с причиной.
func is_rewarded_ready(placement: StringName) -> bool:
	return is_known_placement(placement) and _showing == &"" and remaining(placement) > 0 and backend.is_rewarded_ready()


## Причина, по которой ▶ недоступна (для Disabled-кнопки), или пустая строка.
func blocked_reason(placement: StringName) -> String:
	if remaining(placement) <= 0:
		var left: int = seconds_until_available(placement)
		if left > 0:
			return tr("Через %d ч %d мин") % [floori(left / 3600.0), floori((left % 3600) / 60.0)]
		return tr("Лимит исчерпан")
	if not backend.is_rewarded_ready():
		return tr("Реклама недоступна")
	return ""


## Сколько показов с наградой ещё доступно по лимиту.
func remaining(placement: StringName) -> int:
	var key: String = _limit_key(placement)
	var cfg: Dictionary = placement_cfg(StringName(key))
	var count: int = int(cfg.get("count", 1))
	match str(cfg.get("limit", "")):
		"per_run":
			_sync_run()
			return maxi(0, count - _run_counts.get(key, 0))
		"per_day":
			var profile: PlayerProfile = GameManager.profile
			if profile.ads_day_stamp != DailyGiftService.today():
				return count
			return maxi(0, count - profile.ads_today.get(key, 0))
		"cooldown_h":
			return 1 if seconds_until_available(placement) <= 0 else 0
	return 1


## Для cooldown-плейсментов: секунд до следующего показа (0 — доступен).
func seconds_until_available(placement: StringName) -> int:
	var key: String = _limit_key(placement)
	var cfg: Dictionary = placement_cfg(StringName(key))
	if str(cfg.get("limit", "")) != "cooldown_h":
		return 0
	var last: int = GameManager.profile.ad_cooldowns.get(key, 0)
	var cooldown: int = int(float(cfg.get("hours", 8)) * 3600.0)
	return maxi(0, last + cooldown - int(Time.get_unix_time_from_system()))


## Кнопка ▶ показана игроку — событие ad_opportunity_shown (один раз на плейсмент за показ экрана).
func note_opportunity(placement: StringName) -> void:
	var key: String = "%s/%s" % [placement, SceneRouter.top_screen_id()]
	if _opportunities.has(key):
		return
	_opportunities[key] = true
	Telemetry.log_event(&"ad_opportunity_shown", {"placement": String(placement), "ready": is_rewarded_ready(placement)})


func reset_opportunities() -> void:
	_opportunities.clear()


## Показывается только из кнопок с глифом ▶ (DS правило 4).
func show_rewarded(placement: StringName) -> void:
	if not is_known_placement(placement):
		push_error("[AdManager] unknown placement '%s'" % placement)
		EventBus.ad_failed.emit(placement)
		return
	if _showing != &"" or remaining(placement) <= 0:
		EventBus.ad_failed.emit(placement)
		return
	_showing = placement
	Telemetry.log_event(&"ad_started", {"placement": String(placement)})
	TimeService.pause_world(&"ad")
	AudioManager.duck_music(float(config().get("music_duck", 0.6)))
	backend.show_rewarded(placement)


func _on_rewarded_finished(placement: StringName, rewarded: bool) -> void:
	if placement != _showing:
		return # повторный или чужой колбэк — награда уже обработана
	_end_show()
	Telemetry.log_event(&"ad_completed", {"placement": String(placement), "rewarded": rewarded})
	if rewarded:
		_note_use(placement)
		EventBus.ad_reward_granted.emit(placement)
	else:
		EventBus.ad_failed.emit(placement)


func _on_rewarded_failed(placement: StringName, reason: String) -> void:
	if placement != _showing:
		return
	_end_show()
	Telemetry.log_event(&"ad_failed", {"placement": String(placement), "reason": reason})
	EventBus.ad_failed.emit(placement)


func _end_show() -> void:
	_showing = &""
	TimeService.resume_world(&"ad")
	AudioManager.duck_music(0.0)


func _note_use(placement: StringName) -> void:
	var key: String = _limit_key(placement)
	var cfg: Dictionary = placement_cfg(StringName(key))
	var profile: PlayerProfile = GameManager.profile
	match str(cfg.get("limit", "")):
		"per_run":
			_sync_run()
			_run_counts[key] = _run_counts.get(key, 0) + 1
		"per_day":
			if profile.ads_day_stamp != DailyGiftService.today():
				profile.ads_day_stamp = DailyGiftService.today()
				profile.ads_today.clear()
			profile.ads_today[key] = profile.ads_today.get(key, 0) + 1
			SaveManager.request_save()
		"cooldown_h":
			profile.ad_cooldowns[key] = int(Time.get_unix_time_from_system())
			SaveManager.request_save()


func _limit_key(placement: StringName) -> String:
	var cfg: Dictionary = placement_cfg(placement)
	if str(cfg.get("limit", "")) == "shared":
		return str(cfg.get("with", placement))
	return String(placement)


func _sync_run() -> void:
	var run_id: String = GameManager.current_run.run_id if GameManager.current_run != null else ""
	if run_id != _run_id:
		_run_id = run_id
		_run_counts.clear()
