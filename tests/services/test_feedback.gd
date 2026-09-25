extends GdUnitTestSuite
## task_8 §3–4: звук и хаптика по событиям DS §06.

var _prev_profile: PlayerProfile


func before_test() -> void:
	_prev_profile = GameManager.profile
	GameManager.set_profile(PlayerProfile.new())


func after_test() -> void:
	AudioManager.set_low_light(false)
	GameManager.set_profile(_prev_profile)


func test_every_cue_points_to_existing_sound_and_haptic() -> void:
	var audio: Dictionary = ConfigDB.get_config("audio")
	var events: Dictionary = audio.get("events", {}) as Dictionary
	for cue_name: String in audio.get("cues", {}):
		if cue_name.begins_with("_"):
			continue
		var entry: Dictionary = (audio["cues"] as Dictionary)[cue_name]
		if entry.has("sfx"):
			assert_bool(events.has(str(entry["sfx"]))).override_failure_message("cue %s → no event" % cue_name).is_true()
		if entry.has("haptic"):
			assert_bool(FeedbackManager.PATTERNS.has(StringName(str(entry["haptic"])))).is_true()
	for event: String in events:
		var file: String = "res://src/assets/audio/sfx/%s.ogg" % str((events[event] as Dictionary).get("file", event))
		assert_bool(ResourceLoader.exists(file)).override_failure_message("missing " + file).is_true()


func test_spark_series_rises_and_resets() -> void:
	AudioManager.play_series(&"spark")
	var first: int = AudioManager.series_step()
	for i: int in 20:
		AudioManager._last_play_ms.erase(&"spark")
		AudioManager.play_series(&"spark")
	assert_int(AudioManager.series_step()).is_equal(12)
	AudioManager._series_last_ms -= 1000
	AudioManager.play_series(&"spark")
	assert_int(AudioManager.series_step()).is_equal(0)
	assert_int(first).is_less_equal(12)


func test_cooldown_drops_repeated_sound() -> void:
	AudioManager._last_play_ms.erase(&"ui_disabled")
	assert_bool(AudioManager.play(&"ui_disabled")).is_true()
	assert_bool(AudioManager.play(&"ui_disabled")).is_false()


func test_sfx_toggle_mutes() -> void:
	GameManager.profile.settings.sfx = false
	AudioManager._last_play_ms.erase(&"level_up")
	assert_bool(AudioManager.play(&"level_up")).is_false()


func test_haptic_throttle_and_toggle() -> void:
	FeedbackManager._last_ms.clear()
	var before: int = FeedbackManager.haptics_sent
	FeedbackManager.haptic(&"selection")
	FeedbackManager.haptic(&"selection") # < 80 мс — отброшено
	assert_int(FeedbackManager.haptics_sent - before).is_equal(1)
	GameManager.profile.settings.vibration = false
	FeedbackManager.haptic(&"heavy")
	assert_int(FeedbackManager.haptics_sent - before).is_equal(1)


func test_low_light_enables_music_lowpass() -> void:
	var bus: int = AudioServer.get_bus_index(&"Music")
	assert_int(bus).is_greater(0)
	EventBus.player_light_changed.emit(20.0, 100.0)
	assert_bool(AudioServer.is_bus_effect_enabled(bus, 0)).is_true()
	EventBus.player_light_changed.emit(80.0, 100.0)
	assert_bool(AudioServer.is_bus_effect_enabled(bus, 0)).is_false()


func test_buses_exist() -> void:
	for bus_name: StringName in [&"Music", &"SFX", &"UI", &"Ambience"]:
		assert_int(AudioServer.get_bus_index(bus_name)).is_greater(0)


func test_feature_flags() -> void:
	assert_bool(ConfigDB.feature("mourner_enabled")).is_false()
	assert_bool(ConfigDB.get_enemy(&"mourner").enabled).is_false()
	assert_bool(ConfigDB.feature("no_such_flag")).is_false()
