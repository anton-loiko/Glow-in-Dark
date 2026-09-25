extends SceneTree
## Генерирует src/ui/theme/glow_theme.tres из UITokens/UIFonts (единый источник правды — токены).
## Запуск после изменения токенов: godot --headless --script res://tools/build_theme.gd

const OUT: String = "res://src/ui/theme/glow_theme.tres"


func _init() -> void:
	var tokens: GDScript = load("res://src/ui/theme/UITokens.gd")
	var fonts: GDScript = load("res://src/ui/theme/UIFonts.gd")
	var t: Theme = Theme.new()
	t.default_font = fonts.call("font", &"body")
	t.default_font_size = 15
	var c: Dictionary = tokens.get_script_constant_map()

	# Базовые Label / Button.
	t.set_color(&"font_color", &"Label", c["TEXT_PRIMARY"])
	for v: Array in [["LabelDisplay", &"display"], ["LabelH1", &"h1"], ["LabelH2", &"h2"], ["LabelBody", &"body"],
			["LabelBodyS", &"body_s"], ["LabelMono", &"label"], ["LabelNumber", &"number"]]:
		t.set_type_variation(v[0], &"Label")
		t.set_font(&"font", v[0], fonts.call("font", v[1]))
		t.set_font_size(&"font_size", v[0], fonts.call("size", v[1]))
	t.set_color(&"font_color", &"LabelBodyS", c["TEXT_SECONDARY"])
	t.set_color(&"font_color", &"LabelMono", c["TEXT_MUTED"])

	_button(t, &"ButtonPrimary", c["TEXT_ON_LIGHT"], fonts.call("font", &"button"), 16, c)
	_button(t, &"ButtonCrystal", c["TEXT_ON_CRYSTAL"], fonts.call("font", &"button"), 15, c)
	# Secondary: контур 1.5pt light.500, без свечения.
	t.set_type_variation(&"ButtonSecondary", &"Button")
	var sec: StyleBoxFlat = _box(Color(0, 0, 0, 0), c["R14"])
	sec.set_border_width_all(2)
	sec.border_color = c["LIGHT_500"]
	_margins(sec, 16, 10)
	var sec_pressed: StyleBoxFlat = sec.duplicate()
	sec_pressed.bg_color = Color(c["LIGHT_500"], 0.12)
	for state: StringName in [&"normal", &"hover", &"focus"]:
		t.set_stylebox(state, &"ButtonSecondary", sec)
	t.set_stylebox(&"pressed", &"ButtonSecondary", sec_pressed)
	t.set_stylebox(&"disabled", &"ButtonSecondary", _empty())
	t.set_font(&"font", &"ButtonSecondary", fonts.call("font", &"quiet"))
	t.set_font_size(&"font_size", &"ButtonSecondary", 15)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		t.set_color(key, &"ButtonSecondary", c["TEXT_SECONDARY_BUTTON"])
	t.set_color(&"font_disabled_color", &"ButtonSecondary", c["TEXT_DISABLED"])
	# Quiet: только текст, зона касания ≥ 44pt.
	t.set_type_variation(&"ButtonQuiet", &"Button")
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		t.set_stylebox(state, &"ButtonQuiet", _empty())
	t.set_font(&"font", &"ButtonQuiet", fonts.call("font", &"quiet"))
	t.set_font_size(&"font_size", &"ButtonQuiet", 14)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		t.set_color(key, &"ButtonQuiet", c["TEXT_SECONDARY"])
	t.set_color(&"font_pressed_color", &"ButtonQuiet", c["TEXT_PRIMARY"])
	t.set_color(&"font_disabled_color", &"ButtonQuiet", c["TEXT_DISABLED"])
	# Icon: ink.600 85%, r14.
	t.set_type_variation(&"ButtonIcon", &"Button")
	var icon: StyleBoxFlat = _box(Color(c["INK_600"], 0.85), c["R14"])
	for state: StringName in [&"normal", &"hover", &"focus", &"disabled"]:
		t.set_stylebox(state, &"ButtonIcon", icon)
	var icon_pressed: StyleBoxFlat = icon.duplicate()
	icon_pressed.bg_color = c["LINE_STRONG"]
	t.set_stylebox(&"pressed", &"ButtonIcon", icon_pressed)
	t.set_color(&"font_color", &"ButtonIcon", c["TEXT_PRIMARY"])

	# Панели.
	t.set_type_variation(&"PanelCard", &"PanelContainer")
	var card: StyleBoxFlat = _box(c["INK_700"], c["R16"])
	_margins(card, c["S4"], c["S4"])
	t.set_stylebox(&"panel", &"PanelCard", card)
	t.set_type_variation(&"PanelModal", &"PanelContainer")
	var modal: StyleBoxFlat = _box(c["INK_700"], c["R22"])
	modal.set_border_width_all(1)
	modal.border_color = c["LINE_STRONG"]
	_margins(modal, c["S5"], c["S6"])
	t.set_stylebox(&"panel", &"PanelModal", modal)
	t.set_type_variation(&"PanelPill", &"PanelContainer")
	var pill: StyleBoxFlat = _box(c["INK_600"], 16)
	_margins(pill, 10, 4)
	t.set_stylebox(&"panel", &"PanelPill", pill)
	t.set_stylebox(&"panel", &"PanelContainer", _empty())

	# ProgressBar по умолчанию — XP (spark на ink.600).
	var bar_bg: StyleBoxFlat = _box(c["INK_600"], 4)
	var bar_fill: StyleBoxFlat = _box(c["SPARK"], 4)
	t.set_stylebox(&"background", &"ProgressBar", bar_bg)
	t.set_stylebox(&"fill", &"ProgressBar", bar_fill)

	var err: int = ResourceSaver.save(t, OUT)
	print("[theme] saved %s: %s" % [OUT, error_string(err)])
	quit()


func _button(t: Theme, variation: StringName, text: Color, font: Font, size: int, c: Dictionary) -> void:
	t.set_type_variation(variation, &"Button")
	# Тело, цоколь и свечение рисует ButtonFace (градиент 300 → 500 → 700); здесь только поля контента.
	var normal: StyleBoxEmpty = _empty()
	_margins(normal, 18, 10)
	normal.content_margin_bottom += 4 # цоколь
	var pressed: StyleBoxEmpty = normal.duplicate()
	pressed.content_margin_top += 4
	pressed.content_margin_bottom -= 4
	for state: StringName in [&"normal", &"hover", &"focus"]:
		t.set_stylebox(state, variation, normal)
	t.set_stylebox(&"pressed", variation, pressed)
	t.set_stylebox(&"disabled", variation, _empty())
	t.set_font(&"font", variation, font)
	t.set_font_size(&"font_size", variation, size)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		t.set_color(key, variation, text)
	t.set_color(&"font_disabled_color", variation, c["TEXT_DISABLED"])


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


func _margins(box: StyleBox, horizontal: float, vertical: float) -> void:
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical


func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
