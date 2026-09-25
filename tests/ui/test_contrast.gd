extends GdUnitTestSuite
## DS §08: контраст текста ≥ 4.5:1 (WCAG 2.x, относительная яркость sRGB) для пар токенов UITokens.
## TEXT_DISABLED — исключение WCAG для неактивных элементов; держим ≥ 3:1 на фонах экранов (INK_900–700).
## На INK_600 (листы, ячейки) — 2.79:1, вынесено на ревью дизайнера (tasks/BACKLOG.md).

const MIN_TEXT: float = 4.5
const MIN_DISABLED: float = 3.0


static func luminance(c: Color) -> float:
	var ch: Array[float] = [c.r, c.g, c.b]
	for i: int in 3:
		ch[i] = ch[i] / 12.92 if ch[i] <= 0.04045 else pow((ch[i] + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _assert_pair(fg: Color, bg: Color, min_ratio: float, label: String) -> void:
	var ratio: float = contrast(fg, bg)
	assert_float(ratio).override_failure_message("%s: %.2f < %.1f" % [label, ratio, min_ratio]).is_greater_equal(min_ratio)


func test_reference_ratio() -> void:
	assert_float(contrast(Color.WHITE, Color.BLACK)).is_equal_approx(21.0, 0.01)


func test_text_tokens_on_ink_backgrounds() -> void:
	var backgrounds: Dictionary = {
		"INK_900": UITokens.INK_900, "INK_800": UITokens.INK_800,
		"INK_700": UITokens.INK_700, "INK_600": UITokens.INK_600,
	}
	var texts: Dictionary = {
		"TEXT_PRIMARY": UITokens.TEXT_PRIMARY, "TEXT_SECONDARY": UITokens.TEXT_SECONDARY,
		"TEXT_MUTED": UITokens.TEXT_MUTED, "TEXT_SECONDARY_BUTTON": UITokens.TEXT_SECONDARY_BUTTON,
		"SPARK": UITokens.SPARK, "LIGHT_500": UITokens.LIGHT_500, "CRYSTAL_500": UITokens.CRYSTAL_500,
		"THREAT": UITokens.THREAT, "COLD": UITokens.COLD, "GAIN": UITokens.GAIN, "EPIC": UITokens.EPIC,
		"RUNE": UITokens.RUNE,
	}
	for bg_name: String in backgrounds:
		for fg_name: String in texts:
			_assert_pair(texts[fg_name] as Color, backgrounds[bg_name] as Color, MIN_TEXT, "%s on %s" % [fg_name, bg_name])
		if bg_name != "INK_600":
			_assert_pair(UITokens.TEXT_DISABLED, backgrounds[bg_name] as Color, MIN_DISABLED, "TEXT_DISABLED on %s" % bg_name)


func test_text_on_filled_buttons() -> void:
	_assert_pair(UITokens.TEXT_ON_LIGHT, UITokens.LIGHT_500, MIN_TEXT, "TEXT_ON_LIGHT on LIGHT_500")
	_assert_pair(UITokens.TEXT_ON_LIGHT, UITokens.LIGHT_300, MIN_TEXT, "TEXT_ON_LIGHT on LIGHT_300")
	_assert_pair(UITokens.TEXT_ON_CRYSTAL, UITokens.CRYSTAL_500, MIN_TEXT, "TEXT_ON_CRYSTAL on CRYSTAL_500")


func test_category_and_rarity_text_on_their_backgrounds() -> void:
	for cat: StringName in UITokens.CATEGORY:
		var c: Dictionary = UITokens.CATEGORY[cat]
		_assert_pair(c["300"] as Color, c["bg"] as Color, MIN_TEXT, "%s 300" % cat)
		_assert_pair(c["500"] as Color, c["bg"] as Color, MIN_TEXT, "%s 500" % cat)
	for rarity: StringName in UITokens.RARITY:
		var r: Dictionary = UITokens.RARITY[rarity]
		_assert_pair(r["300"] as Color, r["bg"] as Color, MIN_TEXT, "%s 300" % rarity)
