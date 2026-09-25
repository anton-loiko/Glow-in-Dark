extends GdUnitTestSuite
## SkillsManager (применение, фолбэки, «Взять все три») и SkillHost (пересчёт статов без накопления).


func _run() -> RunContext:
	var stats: StatBlock = StatsResolver.build(PlayerProfile.new(), ConfigDB.get_balance(), ConfigDB.get_beacon_tiers(), null, ConfigDB.get_gear_config())
	return RunContext.new(1, 5, stats)


func _offer(id: StringName, fallback: bool = false) -> SkillOffer:
	var o: SkillOffer = SkillOffer.new()
	o.skill_id = id
	o.is_fallback = fallback
	return o


func test_apply_levels_up_and_caps() -> void:
	var run: RunContext = _run()
	for i: int in 7:
		SkillsManager.apply(run, _offer(&"aura"))
	assert_int(run.skill_level(&"aura")).is_equal(5)


func test_fallback_sparks_adds_run_sparks() -> void:
	var run: RunContext = _run()
	var before: int = run.run_sparks
	SkillsManager.apply(run, _offer(SkillsManager.FALLBACK_SPARKS, true))
	assert_int(run.run_sparks).is_equal(before + 50)
	assert_int(run.slots_used()).is_equal(0)


func test_take_all_replaces_new_skill_when_slots_full() -> void:
	var run: RunContext = _run()
	for id: StringName in [&"aura", &"pulsar", &"trail", &"beam", &"orbs", &"shield"]:
		run.skills[id] = 1
	run.current_offer = [_offer(&"aura"), _offer(&"magnet"), _offer(&"lens")]
	var sparks: int = run.run_sparks
	SkillsManager.take_all(run)
	assert_int(run.skill_level(&"aura")).is_equal(2)
	assert_int(run.skill_level(&"magnet")).is_equal(0)
	assert_int(run.run_sparks).is_equal(sparks + 100)
	assert_bool(run.take_all_used).is_true()


func test_choose_remembers_rejected_cards() -> void:
	var run: RunContext = _run()
	var chosen: SkillOffer = _offer(&"aura")
	run.current_offer = [chosen, _offer(&"shield"), _offer(&"lens")]
	SkillsManager.choose(run, chosen, 0, 1200)
	assert_array(run.last_rejected).contains_exactly_in_any_order([&"shield", &"lens"])


func test_skill_host_recompute_is_idempotent() -> void:
	var scene: RunScene = auto_free(preload("res://src/gameplay/run/RunScene.tscn").instantiate())
	var run: RunContext = _run()
	GameManager.current_run = run
	add_child(scene)
	scene.on_screen_enter({})
	var base_speed: float = scene.player.stats.move_speed
	var base_max: float = scene.player.stats.max_light
	EventBus.skill_selected.emit(&"haste", 2)
	EventBus.skill_selected.emit(&"capacity", 1)
	scene.skills.recompute_stats()
	scene.skills.recompute_stats()
	assert_float(scene.player.stats.move_speed).is_equal_approx(base_speed * 1.10, 0.01)
	assert_float(scene.player.stats.max_light).is_equal_approx(base_max * 1.10, 0.01)
	assert_float(scene.player.move_speed).is_equal_approx(base_speed * 1.10, 0.01)
	EventBus.skill_selected.emit(&"cooldown", 5)
	assert_float(scene.player.stats.cooldown_mult).is_equal_approx(0.6, 0.001)
	GameManager.current_run = null
	DamagePool.unbind()
