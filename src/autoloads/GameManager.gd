extends Node
## Фасад профиля игрока, экономики и жизненного цикла забега.
## Единственное место, где меняются валюты (grant/spend); сериализацией занимается SaveManager.

const SPARKS: StringName = &"sparks"
const CRYSTALS: StringName = &"crystals"

var profile: PlayerProfile
## Текущий забег; null вне забега.
var current_run: RunContext


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_profile(SaveManager.load_profile())
	EventBus.ad_reward_granted.connect(_on_ad_reward_granted)


## Подменяет профиль (загрузка, слияние с облаком).
func set_profile(new_profile: PlayerProfile) -> void:
	profile = new_profile
	SaveManager.bind_profile(profile)
	EventBus.profile_loaded.emit()


# --- Экономика ---------------------------------------------------------------

func get_balance(currency: StringName) -> int:
	match currency:
		SPARKS:
			return profile.sparks
		CRYSTALS:
			return profile.crystals
	push_error("[GameManager] unknown currency '%s'" % currency)
	return 0


func can_afford(currency: StringName, amount: int) -> bool:
	return amount >= 0 and get_balance(currency) >= amount


## Списание валюты. Возвращает false, если не хватает. Трата Кристаллов сохраняется сразу,
## даже во время забега (реальная ценность), Искры — по обычным правилам SaveManager.
func spend(currency: StringName, amount: int, reason: StringName) -> bool:
	if amount < 0 or not can_afford(currency, amount):
		return false
	_change(currency, -amount, reason)
	return true


func grant(currency: StringName, amount: int, reason: StringName) -> void:
	if amount <= 0:
		return
	_change(currency, amount, reason)


func _change(currency: StringName, delta: int, reason: StringName) -> void:
	match currency:
		SPARKS:
			profile.sparks += delta
		CRYSTALS:
			profile.crystals += delta
		_:
			push_error("[GameManager] unknown currency '%s'" % currency)
			return
	var total: int = get_balance(currency)
	EventBus.currency_changed.emit(currency, total, delta)
	Telemetry.log_economy(currency, delta, reason, total)
	SaveManager.request_save(currency == CRYSTALS)


# --- Настройки ---------------------------------------------------------------

func set_setting(key: StringName, value: Variant) -> void:
	if not key in profile.settings:
		push_error("[GameManager] unknown setting '%s'" % key)
		return
	profile.settings.set(key, value)
	EventBus.settings_changed.emit(key, value)
	Telemetry.log_event(&"settings_changed", {"key": String(key), "value": str(value)})
	SaveManager.request_save()


# --- Забег -------------------------------------------------------------------

func is_run_active() -> bool:
	return current_run != null and current_run.result == null


## Создаёт RunContext со статами из профиля и переводит игру в S05.
func start_run(chapter_id: int, run_seed: int = -1) -> RunContext:
	if current_run != null:
		push_warning("[GameManager] previous run was not finished, discarding it")
	if run_seed < 0:
		run_seed = randi()
	var stats: StatBlock = StatsResolver.build_for(profile)
	current_run = RunContext.new(chapter_id, run_seed, stats)
	profile.current_chapter = chapter_id
	SaveManager.flush()
	SaveManager.set_run_active(true)
	EventBus.run_started.emit(current_run.run_id, chapter_id)
	Telemetry.log_event(&"run_started", {
		"run_id": current_run.run_id,
		"chapter": chapter_id,
		"skin": String(profile.skin_equipped),
	})
	SceneRouter.go(&"S05")
	return current_run


## Воскрешение на S08 (DS S08, GDD 5.3): один раз за забег, за рекламу или Кристаллы.
## При успехе публикует факт EventBus.player_revived — эффект применяет RunDirector.
func request_revive(source: StringName) -> bool:
	if not is_run_active() or current_run.revive_used:
		return false
	if source == &"crystal":
		var cost: int = int((ConfigDB.get_balance().get("run", {}) as Dictionary).get("revive_crystal_cost", 30))
		if not spend(CRYSTALS, cost, &"revive"):
			return false
	current_run.revive_used = true
	Telemetry.log_event(&"revive_used", {"run_id": current_run.run_id, "source": String(source)})
	EventBus.player_revived.emit(source)
	return true


func _on_ad_reward_granted(placement: StringName) -> void:
	if placement == &"revive":
		request_revive(&"ad")


## Фиксирует итог забега. Награды зачисляются отдельно, после выбора на S09.
func end_run(result: RunResult) -> void:
	if not is_run_active():
		return
	result.run_sparks = current_run.run_sparks
	result.kills = current_run.kills
	result.player_level = current_run.player_level
	result.chests = current_run.run_chests.duplicate()
	var best: float = profile.best_time_s.get(current_run.chapter_id, 0.0)
	result.is_record = result.time_s > best
	current_run.result = result
	TimeService.reset()
	var params: Dictionary = result.to_telemetry()
	params["run_id"] = current_run.run_id
	EventBus.run_ended.emit(result)
	Telemetry.log_event(&"run_ended", params)
	SceneRouter.go(&"S09")


## Зачисляет награды забега (×1 или ×3 за рекламу) одной транзакцией и закрывает забег.
func apply_run_rewards(multiplier: int) -> void:
	if current_run == null or current_run.result == null:
		push_warning("[GameManager] no finished run to reward")
		return
	var run: RunContext = current_run
	SaveManager.set_run_active(false)
	var best: float = profile.best_time_s.get(run.chapter_id, 0.0)
	profile.best_time_s[run.chapter_id] = maxf(best, run.result.time_s)
	for skill_id: StringName in run.skills:
		if not profile.skills_seen.has(skill_id):
			profile.skills_seen.append(skill_id)
	grant(SPARKS, run.run_sparks * maxi(1, multiplier), &"run_x3" if multiplier > 1 else &"run")
	Telemetry.log_event(&"reward_multiplier", {"run_id": run.run_id, "multiplier": multiplier})
	current_run = null
	SaveManager.flush(true)
