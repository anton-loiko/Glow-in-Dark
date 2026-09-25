class_name OfferGenerator
extends RefCounted
## Выборка трёх карточек левел-апа (Skills DS §04): взвешенная выборка без возвращения,
## W(s) = B · E · M_owned · M_magnet · M_active · M_fresh. Чистая логика без узлов — покрыта тестами.
## Порядок правил: E → гарантия Магнита → W → выборка → правило актива → фолбэк → сортировка ▲ ■ ●.

const MAGNET: StringName = &"magnet"
const CATEGORY_ORDER: Dictionary = {&"attack": 0, &"defense": 1, &"utility": 2}

var tuning: Dictionary = {}
var defs: Dictionary = {} ## StringName -> SkillDef
## Какие правила сработали в последней выборке (для телеметрии skill_offered).
var rules_fired: Array[StringName] = []


func _init(p_tuning: Dictionary, p_defs: Dictionary) -> void:
	tuning = p_tuning
	defs = p_defs


## skills — текущие уровни навыков; level_up_idx — номер левел-апа (1, 2, …);
## rejected — показанные и не выбранные на прошлом левел-апе; excluded — не показывать (реролл).
func draw(skills: Dictionary, level_up_idx: int, rejected: Array[StringName], magnet_seen: bool,
		excluded: Array[StringName], rng_seed: int, is_reroll: bool) -> Array[SkillOffer]:
	rules_fired.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var pool: Array[StringName] = eligible(skills)
	for id: StringName in excluded:
		pool.erase(id)
	var offer: Array[SkillOffer] = []

	# Правило 1: гарантия Магнита на N-м левел-апе, если он ни разу не выпадал.
	if not is_reroll and level_up_idx == int(tuning.get("magnet_guarantee_level", 5)) and not magnet_seen and pool.has(MAGNET):
		offer.append(_make_offer(MAGNET, skills, weight(MAGNET, skills, level_up_idx, rejected), 1.0))
		pool.erase(MAGNET)
		rules_fired.append(&"magnet_guarantee")

	var active_rule: bool = level_up_idx <= int(tuning.get("active_boost_until_levelup", 2))
	var max_passive: int = int(tuning.get("max_passive_in_offer", 2))
	while offer.size() < 3 and not pool.is_empty():
		var pick: StringName = _weighted_pick(pool, skills, level_up_idx, rejected, rng)
		if active_rule and not _def(pick).is_active() and _passive_count(offer) >= max_passive:
			var attacks: Array[StringName] = []
			for id: StringName in pool:
				if _def(id).is_active():
					attacks.append(id)
			if not attacks.is_empty():
				pick = _weighted_pick(attacks, skills, level_up_idx, rejected, rng)
				if not rules_fired.has(&"active_rule"):
					rules_fired.append(&"active_rule")
		var total: float = _total_weight(pool, skills, level_up_idx, rejected)
		var w: float = weight(pick, skills, level_up_idx, rejected)
		offer.append(_make_offer(pick, skills, w, w / total if total > 0.0 else 0.0))
		pool.erase(pick)

	_fill_fallbacks(offer)
	offer.sort_custom(_compare)
	return offer


## E(s): навык не на максимуме и (уже есть в слотах или есть свободный слот).
func eligible(skills: Dictionary) -> Array[StringName]:
	var max_slots: int = int(tuning.get("max_slots", 6))
	var slots_full: bool = skills.size() >= max_slots
	var result: Array[StringName] = []
	for id: StringName in defs:
		var level: int = int(skills.get(id, 0))
		if level >= _def(id).max_level:
			continue
		if level == 0 and slots_full:
			continue
		result.append(id)
	result.sort()
	return result


func weight(id: StringName, skills: Dictionary, level_up_idx: int, rejected: Array[StringName]) -> float:
	var w: float = _def(id).base_weight
	var owned: bool = int(skills.get(id, 0)) > 0
	if owned:
		w *= float(tuning.get("owned_mul", 1.3))
	var magnet_period: bool = level_up_idx <= int(tuning.get("magnet_mul_until_player_level", 5))
	if id == MAGNET and magnet_period:
		var muls: Array = tuning.get("magnet_mul", [3.0, 1.5, 1.0])
		var level: int = int(skills.get(MAGNET, 0))
		w *= float(muls[0]) if level == 0 else (float(muls[1]) if level <= 2 else float(muls[2]))
	if level_up_idx <= int(tuning.get("active_boost_until_levelup", 2)) and _def(id).is_active() and _active_count(skills) == 0:
		w *= float(tuning.get("active_boost", 2.5))
	if rejected.has(id) and not (id == MAGNET and magnet_period):
		w *= float(tuning.get("fresh_mul", 0.7))
	return w


func _weighted_pick(pool: Array[StringName], skills: Dictionary, level_up_idx: int, rejected: Array[StringName], rng: RandomNumberGenerator) -> StringName:
	var total: float = _total_weight(pool, skills, level_up_idx, rejected)
	var roll: float = rng.randf() * total
	for id: StringName in pool:
		roll -= weight(id, skills, level_up_idx, rejected)
		if roll <= 0.0:
			return id
	return pool.back()


func _total_weight(pool: Array[StringName], skills: Dictionary, level_up_idx: int, rejected: Array[StringName]) -> float:
	var total: float = 0.0
	for id: StringName in pool:
		total += weight(id, skills, level_up_idx, rejected)
	return total


func _make_offer(id: StringName, skills: Dictionary, w: float, p: float) -> SkillOffer:
	var def: SkillDef = _def(id)
	var offer: SkillOffer = SkillOffer.new()
	offer.skill_id = id
	offer.level_to = int(skills.get(id, 0)) + 1
	offer.weight = w
	offer.probability = p
	offer.is_new = offer.level_to == 1
	offer.is_max = offer.level_to == def.max_level
	for synergy: StringName in def.synergies:
		if int(skills.get(synergy, 0)) > 0:
			offer.has_synergy = true
	return offer


## Пул меньше трёх — нейтральные карты «Искры +50» и «Разжечь +30% света» (не занимают слоты).
func _fill_fallbacks(offer: Array[SkillOffer]) -> void:
	var fallbacks: Array = tuning.get("fallbacks", [])
	var i: int = 0
	while offer.size() < 3 and not fallbacks.is_empty():
		var entry: Dictionary = fallbacks[i % fallbacks.size()]
		var fallback: SkillOffer = SkillOffer.new()
		fallback.skill_id = StringName(str(entry.get("id")))
		fallback.is_fallback = true
		fallback.is_new = false
		offer.append(fallback)
		i += 1


func _compare(a: SkillOffer, b: SkillOffer) -> bool:
	var ca: int = _category_rank(a)
	var cb: int = _category_rank(b)
	if ca != cb:
		return ca < cb
	return a.weight > b.weight


func _category_rank(offer: SkillOffer) -> int:
	if offer.is_fallback:
		return 3
	return int(CATEGORY_ORDER.get(_def(offer.skill_id).category, 3))


func _passive_count(offer: Array[SkillOffer]) -> int:
	var count: int = 0
	for o: SkillOffer in offer:
		if not o.is_fallback and not _def(o.skill_id).is_active():
			count += 1
	return count


func _active_count(skills: Dictionary) -> int:
	var count: int = 0
	for id: Variant in skills:
		if defs.has(id) and _def(id).is_active() and int(skills[id]) > 0:
			count += 1
	return count


func _def(id: StringName) -> SkillDef:
	return defs[id] as SkillDef
