class_name SkillCard
extends Control
## Карточка навыка S06 (Skills DS §01–§02): 358×112, рамка цвета категории, превью слева,
## «глиф · КАТЕГОРИЯ · ТИП · НОВЫЙ», название, 5 сегментов уровня, строка «было → станет».
## Тап (< 250 мс) — выбор; удержание ≥ 250 мс — Focus с описанием всех уровней. Карты не бывают Disabled.

signal chosen(card: SkillCard, focus_used: bool)

const SIZE: Vector2 = Vector2(358, 112)
const HOLD_MS: int = 250

var offer: SkillOffer
var def: SkillDef
var locked: bool = true
var current_level: int = 0

var _tokens: Dictionary = {}
var _pressed_at: int = -1
var _focus: bool = false
var _focus_used: bool = false
var _pressed: bool = false
var _meta: Label
var _title: Label
var _effect: Label
var _details: Label


func setup(p_offer: SkillOffer, p_current_level: int) -> void:
	offer = p_offer
	current_level = p_current_level
	def = null if offer.is_fallback else SkillsManager.get_def(offer.skill_id)


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tokens = UITokens.CATEGORY.get(_category(), UITokens.CATEGORY[&"utility"])
	_meta = _add_label(Vector2(104, 12), 10, _tokens["300"])
	_title = _add_label(Vector2(104, 28), 16, UITokens.TEXT_PRIMARY)
	_effect = _add_label(Vector2(104, 78), 13, UITokens.TEXT_SECONDARY)
	_details = _add_label(Vector2(12, SIZE.y + 4), 12, UITokens.TEXT_SECONDARY)
	_details.visible = false
	_fill_texts()


func _process(_delta: float) -> void:
	if _pressed and not _focus and Time.get_ticks_msec() - _pressed_at >= HOLD_MS:
		_focus = true
		_focus_used = true
		_details.visible = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	var press: bool = false
	var release: bool = false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		press = touch.pressed
		release = not touch.pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = (event as InputEventMouseButton).pressed
		release = not press
	if press:
		_pressed = true
		_pressed_at = Time.get_ticks_msec()
		scale = Vector2.ONE * 0.97
		FeedbackManager.haptic(&"selection")
		accept_event()
	elif release and _pressed:
		_pressed = false
		scale = Vector2.ONE
		_details.visible = false
		var inside: bool = Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		if inside:
			chosen.emit(self, _focus_used)
		_focus = false
		accept_event()


func _category() -> StringName:
	if offer.is_fallback:
		var fallbacks: Array = SkillsManager.get_tuning().get("fallbacks", [])
		for entry: Variant in fallbacks:
			if StringName(str((entry as Dictionary).get("id"))) == offer.skill_id:
				return StringName(str((entry as Dictionary).get("category", "utility")))
		return &"utility"
	return def.category


func _fill_texts() -> void:
	if offer.is_fallback:
		var entry: Dictionary = _fallback_entry()
		_meta.text = "%s · БОНУС" % _tokens["glyph"]
		_title.text = str(entry.get("name", ""))
		_effect.text = "%s %s" % [entry.get("label", ""), entry.get("value", "")]
		return
	var tags: Array[String] = [str(_tokens["glyph"]) + " " + str(_tokens["name"]), "АКТИВ" if def.is_active() else "ПАССИВ"]
	if offer.is_new:
		tags.append("НОВЫЙ")
	elif offer.is_max:
		tags.append("МАКС")
	else:
		tags.append("УР. %d → %d" % [current_level, offer.level_to])
	if offer.has_synergy:
		tags.append("СИНЕРГИЯ")
	_meta.text = " · ".join(tags)
	_title.text = def.display_name
	var now: String = def.level_value(offer.level_to)
	var note: String = def.level_note(offer.level_to)
	if offer.is_new:
		_effect.text = "%s: %s" % [def.label, now]
	else:
		_effect.text = "%s: %s → %s" % [def.label, def.level_value(current_level), now]
	if not note.is_empty():
		_effect.text += " · " + note
	var lines: Array[String] = []
	for lvl: int in range(1, def.max_level + 1):
		var line: String = "Ур. %d: %s" % [lvl, def.level_value(lvl)]
		if not def.level_note(lvl).is_empty():
			line += " · " + def.level_note(lvl)
		lines.append(line)
	_details.text = "\n".join(lines)


func _fallback_entry() -> Dictionary:
	for entry: Variant in SkillsManager.get_tuning().get("fallbacks", []):
		if StringName(str((entry as Dictionary).get("id"))) == offer.skill_id:
			return entry as Dictionary
	return {}


func _add_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = (_tokens["bg"] as Color).lightened(0.08 if _pressed else 0.0)
	box.set_corner_radius_all(20)
	box.set_border_width_all(2)
	var border: Color = _tokens["500"] if _focus else _tokens["700"]
	if offer.is_max:
		border = UITokens.GOLD_300.lerp(UITokens.GOLD_700, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * PI))
	box.border_color = border
	draw_style_box(box, rect)
	# Превью навыка (до hi-res иконок task_8): глиф категории на подсветке.
	var center: Vector2 = Vector2(54, SIZE.y * 0.5)
	var breath: float = 1.0 + 0.04 * TimeService.breath_phase()
	draw_circle(center, 34.0 * breath, Color(_tokens["500"], 0.18))
	draw_circle(center, 22.0 * breath, Color(_tokens["500"], 0.9))
	if def != null:
		_draw_segments()


func _draw_segments() -> void:
	var origin: Vector2 = Vector2(104, 60)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU)
	for i: int in def.max_level:
		var seg: Rect2 = Rect2(origin + Vector2(i * 30, 0), Vector2(26, 6))
		var color: Color = Color(_tokens["bg"]).lightened(0.12)
		if i < current_level:
			color = _tokens["500"]
		elif i == offer.level_to - 1:
			color = UITokens.GOLD_300.lerp(_tokens["500"], pulse * 0.5)
		draw_rect(seg, color)
