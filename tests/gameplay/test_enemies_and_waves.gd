extends GdUnitTestSuite
## Враги и волны: урон и сгорание, замедления, атаки, кольцо спавна, фазы директора.


func test_attack_factory_by_archetype() -> void:
	assert_object(EnemyAttack.create(ConfigDB.get_enemy(&"reaper").attack)).is_instanceof(DashAttack)
	assert_object(EnemyAttack.create(ConfigDB.get_enemy(&"devourer").attack)).is_instanceof(SlamAttack)
	assert_object(EnemyAttack.create(ConfigDB.get_enemy(&"extinguisher").attack)).is_instanceof(DarkAuraAttack)
	assert_str(String(EnemyAttack.create(ConfigDB.get_enemy(&"whisper").attack).marker_kind())).is_equal("none")


func test_slows_do_not_stack_max_wins() -> void:
	var enemy: Enemy = auto_free(Enemy.new())
	enemy.def = ConfigDB.get_enemy(&"whisper")
	enemy.base_speed = 100.0
	enemy.apply_slow(10.0, &"skin")
	enemy.apply_slow(25.0, &"freeze")
	assert_float(enemy.current_speed()).is_equal_approx(75.0, 0.01)
	enemy.clear_slow(&"freeze")
	assert_float(enemy.current_speed()).is_equal_approx(90.0, 0.01)


func test_spawn_ring_is_outside_screen_and_light() -> void:
	var ring: SpawnRing = SpawnRing.new()
	ring.setup(ConfigDB.get_config("waves"))
	var half: Vector2 = Vector2(195, 422)
	var radius: float = ring.ring_radius(half, 1.0, 107.0)
	assert_float(radius).is_greater(half.length())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in 50:
		var pos: Vector2 = ring.pick(Vector2.ZERO, Vector2.ZERO, radius, rng, func(_p: Vector2) -> bool: return false)
		assert_float(pos.length()).is_greater_equal(radius)


func test_spawn_ring_limits_one_side_share() -> void:
	var ring: SpawnRing = SpawnRing.new()
	ring.setup(ConfigDB.get_config("waves"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var sectors: Dictionary = {}
	for i: int in 200:
		# Сильное движение вправо: вес правой стороны ×1.5, но не больше 40% спавна с одной стороны.
		var pos: Vector2 = ring.pick(Vector2.ZERO, Vector2(110, 0), 600.0, rng, func(_p: Vector2) -> bool: return false)
		var sector: int = posmod(roundi(pos.angle() / (TAU / 8.0)), 8)
		sectors[sector] = int(sectors.get(sector, 0)) + 1
	for count: int in sectors.values():
		assert_float(float(count) / 200.0).is_less_equal(0.45)


func test_spawn_ring_skips_blocked_points() -> void:
	var ring: SpawnRing = SpawnRing.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var blocked_all: Callable = func(_p: Vector2) -> bool: return true
	assert_object(ring.pick(Vector2.ZERO, Vector2.ZERO, 500.0, rng, blocked_all)).is_equal(Vector2.INF)


func test_wave_phases_follow_loop_and_final_tension() -> void:
	var director: WaveDirector = auto_free(WaveDirector.new())
	director._cfg = ConfigDB.get_config("waves")
	director._loop.clear()
	director._loop_length = 0.0
	for entry: Variant in director._cfg["loop"]:
		director._loop.append(entry as Dictionary)
		director._loop_length += float((entry as Dictionary)["duration_s"])
	director._final_from = 540.0
	director.manager = null
	var expected: Dictionary = {10.0: "calm", 50.0: "tension", 80.0: "reward", 95.0: "calm", 560.0: "tension", 590.0: "tension"}
	for t: float in expected:
		director.phase = &"__"
		director._update_phase_for_test(t)
		assert_str(String(director.phase)).override_failure_message("t=%s" % t).is_equal(expected[t])
