extends GdUnitTestSuite
## UI-фундамент task_5: форматирование, моушен, дар дня, кнопки, локализация.


func test_numbers_use_space_separator() -> void:
	assert_str(UIKit.format_number(12480)).is_equal("12 480")
	assert_str(UIKit.format_number(1240)).is_equal("1 240")
	assert_str(UIKit.format_number(74720)).is_equal("74 720")
	assert_str(UIKit.format_number(999)).is_equal("999")
	assert_str(UIKit.format_time(408.0)).is_equal("06:48")


func test_ease_settle_overshoots_and_ends_at_one() -> void:
	assert_float(UIMotion.settle(0.0)).is_equal(0.0)
	assert_float(UIMotion.settle(1.0)).is_equal(1.0)
	var peak: float = 0.0
	for i: int in 101:
		peak = maxf(peak, UIMotion.settle(i / 100.0))
	assert_float(peak).is_greater(1.0)
	assert_float(UIMotion.exit(0.5)).is_less(0.5)


func test_daily_streak_continues_and_resets() -> void:
	var p: PlayerProfile = PlayerProfile.new()
	var today: int = DailyGiftService.today()
	assert_int(DailyGiftService.current_day(p)).is_equal(1)
	p.daily_last_claim_day = today - 1
	p.daily_streak_day = 3
	assert_int(DailyGiftService.current_day(p)).is_equal(4)
	p.daily_last_claim_day = today - 2
	assert_int(DailyGiftService.current_day(p)).is_equal(1)
	p.daily_last_claim_day = today - 1
	p.daily_streak_day = 7
	assert_int(DailyGiftService.current_day(p)).is_equal(1)
	p.daily_last_claim_day = today
	assert_bool(DailyGiftService.is_available(p)).is_false()


func test_blocked_button_shows_reason() -> void:
	var b: GlowButton = auto_free(UIKit.button("Внести", GlowButton.Variant.SECONDARY, Callable()))
	add_child(b)
	b.set_blocked(true, "Нужно 2 000")
	assert_str(b.text).is_equal("Нужно 2 000")
	b.set_blocked(false)
	assert_str(b.text).is_equal("Внести")


func test_ad_button_gets_play_glyph() -> void:
	var b: GlowButton = auto_free(UIKit.button("Забрать ×2", GlowButton.Variant.SECONDARY, Callable()))
	b.ad = true
	add_child(b)
	assert_str(b.text).starts_with("▶ ")


func test_every_tr_string_has_translation() -> void:
	var keys: Dictionary = {}
	var csv: FileAccess = FileAccess.open("res://src/ui/localization/strings.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() >= 3:
			keys[row[0]] = row[2]
	var regex: RegEx = RegEx.create_from_string("(?:\\btr|translate)\\(\"([^\"]+)\"\\)")
	var missing: Array[String] = []
	for path: String in _scripts("res://src"):
		for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			var key: String = m.get_string(1)
			if not keys.has(key) or String(keys[key]).is_empty():
				missing.append(key)
	assert_array(missing).is_empty()


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
