extends Node
## Рогалик-навыки (Skills DS): реестр, выборка оферов (OfferGenerator), реролл, выбор, «Взять все три».
## Эффекты навыков применяет SkillHost в сцене забега по факту EventBus.skill_selected.

const FALLBACK_SPARKS: StringName = &"fallback_sparks"
const FALLBACK_LIGHT: StringName = &"fallback_light"

var _generator: OfferGenerator


func _ready() -> void:
	set_process(false)


func get_def(id: StringName) -> SkillDef:
	return ConfigDB.get_skill(id)


func all_ids() -> Array[StringName]:
	return ConfigDB.get_skill_ids()


func get_tuning() -> Dictionary:
	return ConfigDB.get_skill_tuning()


func generator() -> OfferGenerator:
	if _generator == null:
		var defs: Dictionary = {}
		for id: StringName in all_ids():
			defs[id] = get_def(id)
		_generator = OfferGenerator.new(get_tuning(), defs)
	return _generator


## Три карточки для текущего левел-апа (run.level_up_idx уже увеличен RunDirector'ом).
func draw_offer(run: RunContext) -> Array[SkillOffer]:
	run.reroll_idx = 0
	var offer: Array[SkillOffer] = generator().draw(run.skills, run.level_up_idx, run.last_rejected,
			run.magnet_seen, [], _seed(run), false)
	_present(run, offer)
	return offer


## «Обновить»: те же веса, только что показанные карты исключены; гарантия Магнита не повторяется.
func reroll(run: RunContext, cost_type: StringName) -> Array[SkillOffer]:
	run.reroll_idx += 1
	run.reroll_count += 1
	var excluded: Array[StringName] = []
	for o: SkillOffer in run.current_offer:
		if not o.is_fallback:
			excluded.append(o.skill_id)
	var offer: Array[SkillOffer] = generator().draw(run.skills, run.level_up_idx, run.last_rejected,
			run.magnet_seen, excluded, _seed(run), true)
	Telemetry.log_event(&"skill_reroll", {"run_id": run.run_id, "cost_type": String(cost_type)})
	_present(run, offer)
	return offer


## Выбор карты игроком. position — индекс карты сверху (0–2).
func choose(run: RunContext, offer: SkillOffer, position: int, decision_ms: int, focus_used: bool = false) -> void:
	run.last_rejected.clear()
	for o: SkillOffer in run.current_offer:
		if o != offer and not o.is_fallback:
			run.last_rejected.append(o.skill_id)
	var level_to: int = apply(run, offer)
	_log_selected(run, offer, level_to, position, decision_ms, false, focus_used)
	run.current_offer.clear()


## «▶ Взять все три» (1 раз за забег): применяет все карты по порядку.
## Новый навык, который не помещается в слоты, заменяется на «+50 Искр».
func take_all(run: RunContext) -> void:
	run.take_all_used = true
	run.last_rejected.clear()
	var max_slots: int = int(get_tuning().get("max_slots", 6))
	for i: int in run.current_offer.size():
		var offer: SkillOffer = run.current_offer[i]
		if not offer.is_fallback and run.skill_level(offer.skill_id) == 0 and run.skills.size() >= max_slots:
			var replacement: SkillOffer = SkillOffer.new()
			replacement.skill_id = FALLBACK_SPARKS
			replacement.is_fallback = true
			offer = replacement
		var level_to: int = apply(run, offer)
		_log_selected(run, offer, level_to, i, 0, true, false)
	run.current_offer.clear()


## Применение одной карты. Возвращает новый уровень (0 для фолбэка).
func apply(run: RunContext, offer: SkillOffer) -> int:
	if offer.is_fallback:
		if offer.skill_id == FALLBACK_SPARKS:
			run.run_sparks += 50
			EventBus.run_sparks_changed.emit(run.run_sparks, 50)
		EventBus.skill_selected.emit(offer.skill_id, 0)
		return 0
	var def: SkillDef = get_def(offer.skill_id)
	if def == null:
		push_error("[SkillsManager] unknown skill '%s'" % offer.skill_id)
		return 0
	var level_to: int = mini(run.skill_level(offer.skill_id) + 1, def.max_level)
	run.skills[offer.skill_id] = level_to
	if level_to >= def.max_level:
		Telemetry.log_event(&"skill_maxed", {"run_id": run.run_id, "id": String(offer.skill_id), "run_time_s": roundi(run.elapsed_s)})
	EventBus.skill_selected.emit(offer.skill_id, level_to)
	return level_to


func _present(run: RunContext, offer: Array[SkillOffer]) -> void:
	run.current_offer = offer
	var telemetry_offer: Array = []
	for o: SkillOffer in offer:
		if o.skill_id == OfferGenerator.MAGNET:
			run.magnet_seen = true
		telemetry_offer.append(o.to_telemetry())
	run.offer_history.append(offer.duplicate())
	Telemetry.log_event(&"skill_offered", {
		"run_id": run.run_id,
		"level_up_idx": run.level_up_idx,
		"player_level": run.player_level,
		"offer": telemetry_offer,
		"reroll_idx": run.reroll_idx,
		"rules_fired": generator().rules_fired.map(func(r: StringName) -> String: return String(r)),
	})
	EventBus.skill_offer_presented.emit(offer)


func _log_selected(run: RunContext, offer: SkillOffer, level_to: int, position: int, decision_ms: int, took_all: bool, focus_used: bool) -> void:
	var def: SkillDef = get_def(offer.skill_id)
	Telemetry.log_event(&"skill_selected", {
		"run_id": run.run_id,
		"id": String(offer.skill_id),
		"level_to": level_to,
		"category": String(def.category) if def != null else "fallback",
		"position": position,
		"decision_ms": decision_ms,
		"took_all": took_all,
		"focus_used": focus_used,
	})


func _seed(run: RunContext) -> int:
	return run.run_seed + run.level_up_idx * 7 + run.reroll_idx
