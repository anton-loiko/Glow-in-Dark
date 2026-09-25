extends GdUnitTestSuite
## OfferGenerator: правила Skills DS §04 и Монте-Карло на примере «левел-ап 3».

var gen: OfferGenerator


func before() -> void:
	gen = SkillsManager.generator()


func _ids(offer: Array[SkillOffer]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for o: SkillOffer in offer:
		ids.append(o.skill_id)
	return ids


func test_three_cards_sorted_by_category() -> void:
	var offer: Array[SkillOffer] = gen.draw({}, 3, [], true, [], 11, false)
	assert_int(offer.size()).is_equal(3)
	var ranks: Array[int] = []
	for o: SkillOffer in offer:
		ranks.append(int(OfferGenerator.CATEGORY_ORDER[SkillsManager.get_def(o.skill_id).category]))
	var sorted_ranks: Array[int] = ranks.duplicate()
	sorted_ranks.sort()
	assert_array(ranks).is_equal(sorted_ranks)


func test_rule4_maxed_skill_never_offered() -> void:
	for s: int in 300:
		var offer: Array[SkillOffer] = gen.draw({&"pulsar": 5}, 3, [], true, [], s, false)
		assert_bool(_ids(offer).has(&"pulsar")).is_false()


func test_full_slots_only_upgrades() -> void:
	var skills: Dictionary = {&"aura": 1, &"pulsar": 2, &"trail": 1, &"beam": 1, &"shield": 1, &"magnet": 3}
	for s: int in 200:
		for id: StringName in _ids(gen.draw(skills, 8, [], true, [], s, false)):
			assert_bool(skills.has(id)).override_failure_message(String(id)).is_true()


func test_magnet_guarantee_on_fifth_level_up() -> void:
	for s: int in 100:
		assert_bool(_ids(gen.draw({&"aura": 1}, 5, [], false, [], s, false)).has(&"magnet")).is_true()


func test_magnet_guarantee_not_on_reroll() -> void:
	var seen_without: bool = false
	for s: int in 200:
		if not _ids(gen.draw({&"aura": 1}, 5, [], false, [&"magnet"], s, true)).has(&"magnet"):
			seen_without = true
	assert_bool(seen_without).is_true()


func test_active_rule_on_first_level_ups() -> void:
	for s: int in 500:
		for idx: int in [1, 2]:
			var offer: Array[SkillOffer] = gen.draw({}, idx, [], true, [], s, false)
			var passives: int = 0
			for o: SkillOffer in offer:
				if not SkillsManager.get_def(o.skill_id).is_active():
					passives += 1
			assert_int(passives).is_less_equal(2)


func test_fallbacks_fill_empty_pool() -> void:
	var skills: Dictionary = {}
	for id: StringName in SkillsManager.all_ids():
		skills[id] = 5
	var offer: Array[SkillOffer] = gen.draw(skills, 20, [], true, [], 1, false)
	assert_int(offer.size()).is_equal(3)
	for o: SkillOffer in offer:
		assert_bool(o.is_fallback).is_true()


func test_same_seed_same_offer() -> void:
	var a: Array[StringName] = _ids(gen.draw({&"aura": 2}, 4, [&"lens"], true, [], 77, false))
	var b: Array[StringName] = _ids(gen.draw({&"aura": 2}, 4, [&"lens"], true, [], 77, false))
	assert_array(a).is_equal(b)


## Пример DS: Пульсар ур.1, Магнита нет, на прошлом левел-апе отвергнуты Щит и Линза.
## Точные доли попадания в тройку (перебор): Магнит 55.6%, Пульсар 28.9%, новый навык 22.8%, Щит 16.4%.
func test_monte_carlo_matches_design_example() -> void:
	var skills: Dictionary = {&"pulsar": 1}
	var rejected: Array[StringName] = [&"shield", &"lens"]
	var hits: Dictionary = {}
	var runs: int = 100000
	for s: int in runs:
		for id: StringName in _ids(gen.draw(skills, 3, rejected, true, [], s, false)):
			hits[id] = int(hits.get(id, 0)) + 1
	var share: Callable = func(id: StringName) -> float: return float(hits.get(id, 0)) / runs
	assert_float(share.call(&"magnet")).is_equal_approx(0.556, 0.015)
	assert_float(share.call(&"pulsar")).is_equal_approx(0.289, 0.015)
	assert_float(share.call(&"trail")).is_equal_approx(0.228, 0.015)
	assert_float(share.call(&"shield")).is_equal_approx(0.164, 0.015)
	# Правило 2: дубликат на +25–30% чаще нового навыка.
	var ratio: float = share.call(&"pulsar") / share.call(&"trail")
	assert_float(ratio).is_between(1.20, 1.35)
