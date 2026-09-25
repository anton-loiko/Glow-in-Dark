extends GdUnitTestSuite
## Пикапы (слияние искр, срок жизни) и зона плавающего джойстика.


func test_sparks_merge_above_threshold() -> void:
	var system: PickupSystem = auto_free(PickupSystem.new())
	add_child(system)
	var player: Player = auto_free(preload("res://src/gameplay/player/Player.tscn").instantiate())
	add_child(player)
	player.stats = StatBlock.new()
	player.global_position = Vector2(10000, 10000)
	system.setup(player, ConfigDB.get_balance())
	for i: int in 80:
		system.spawn_spark(Vector2(i * 2.0, 0), 1, false)
	assert_int(system.active_sparks()).is_equal(system.merge_threshold)


func test_joystick_ignores_top_zone_and_releases_actions() -> void:
	var joystick: FloatingJoystick = auto_free(FloatingJoystick.new())
	add_child(joystick)
	joystick.size = Vector2(390, 844)
	joystick._on_press(0, Vector2(195, 200))
	assert_int(joystick._pointer).is_equal(FloatingJoystick.NO_POINTER)
	joystick._on_press(0, Vector2(195, 700))
	joystick._on_move(0, Vector2(243, 700))
	assert_float(Input.get_action_strength(&"move_right")).is_equal_approx(1.0, 0.01)
	assert_float(joystick.vector().x).is_equal_approx(1.0, 0.01)
	joystick._on_release(0)
	assert_float(Input.get_action_strength(&"move_right")).is_equal(0.0)


func test_xp_curve_first_levels() -> void:
	var director: RunDirector = auto_free(RunDirector.new())
	director.balance = ConfigDB.get_balance()
	assert_int(director.xp_to_next(1)).is_equal(5)
	assert_int(director.xp_to_next(2)).is_equal(6)
	assert_int(director.xp_to_next(5)).is_equal(12)
