class_name GlowButton
extends Button
## Кнопка DS §02, четыре веса: Primary (янтарь, одна на экран) · Secondary (контур) · Quiet (текст, выход)
## · Crystal (реальные деньги / ◆). Disabled — пунктир line.strong и причина («Нужно 2 000»), тап — покачивание 3pt.
## ad = true добавляет глиф ▶: любое действие с рекламой начинается с него, без ▶ реклама не показывается.

enum Variant { PRIMARY, SECONDARY, QUIET, CRYSTAL, ICON }

const VARIATIONS: Dictionary = {
	Variant.PRIMARY: &"ButtonPrimary",
	Variant.SECONDARY: &"ButtonSecondary",
	Variant.QUIET: &"ButtonQuiet",
	Variant.CRYSTAL: &"ButtonCrystal",
	Variant.ICON: &"ButtonIcon",
}

@export var variant: Variant = Variant.SECONDARY
@export var ad: bool = false
@export var disabled_reason: String = ""

## Плейсмент RV: кнопка сама следит за лимитом и готовностью рекламы и логирует ad_opportunity_shown.
var ad_placement: StringName = &""
## Причина блокировки от экрана (например, «Инвентарь полон») — важнее причин рекламы.
var ad_extra_reason: String = ""

var _label_text: String = ""
var _ad_poll_s: float = 0.0


func _ready() -> void:
	theme_type_variation = VARIATIONS[variant]
	var height: float = UITokens.BUTTON_PRIMARY_H if variant == Variant.PRIMARY else UITokens.BUTTON_H
	if variant == Variant.ICON:
		custom_minimum_size = Vector2(UITokens.TOUCH_MIN, UITokens.TOUCH_MIN)
	else:
		custom_minimum_size.y = maxf(custom_minimum_size.y, height)
	focus_mode = Control.FOCUS_NONE
	_label_text = text
	_refresh_text()
	pressed.connect(_on_pressed)
	gui_input.connect(_on_gui_input)
	set_process(ad_placement != &"")
	if ad_placement != &"":
		ad = true
		_refresh_text()
		refresh_ad()
		AdManager.note_opportunity(ad_placement)


func _process(delta: float) -> void:
	_ad_poll_s -= delta
	if _ad_poll_s <= 0.0:
		_ad_poll_s = 0.5
		refresh_ad()


## Пересчитать доступность ▶: причина экрана → лимит/таймер → «Реклама недоступна».
func refresh_ad() -> void:
	if ad_placement == &"":
		return
	var reason: String = ad_extra_reason if not ad_extra_reason.is_empty() else AdManager.blocked_reason(ad_placement)
	if disabled != not reason.is_empty() or disabled_reason != reason:
		set_blocked(not reason.is_empty(), reason)


func set_label(value: String) -> void:
	_label_text = value
	_refresh_text()


## Отключить с объяснением причины (DS: Disabled всегда объясняет, почему).
func set_blocked(blocked: bool, reason: String = "") -> void:
	disabled = blocked
	disabled_reason = reason
	_refresh_text()
	queue_redraw()


func _refresh_text() -> void:
	var value: String = _label_text
	if disabled and not disabled_reason.is_empty():
		value = disabled_reason
	if variant == Variant.PRIMARY:
		value = value.to_upper()
	text = ("▶ " + value) if ad and not value.begins_with("▶") else value


func _on_pressed() -> void:
	FeedbackManager.haptic(&"selection")


func _on_gui_input(event: InputEvent) -> void:
	if not disabled:
		return
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped:
		UIMotion.shake(self)
		FeedbackManager.haptic(&"rigid")


func _draw() -> void:
	if not disabled or variant == Variant.QUIET:
		return
	# Пунктирный контур line.strong вместо приглушённой заливки.
	var rect: Rect2 = Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
	var r: float = UITokens.R14
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 12
	for corner: int in 4:
		var center: Vector2 = [rect.position + Vector2(rect.size.x - r, r), rect.end - Vector2(r, r), rect.position + Vector2(r, rect.size.y - r), rect.position + Vector2(r, r)][corner]
		var start_angle: float = [-PI * 0.5, 0.0, PI * 0.5, PI][corner]
		for i: int in segments + 1:
			points.append(center + Vector2.from_angle(start_angle + PI * 0.5 * i / segments) * r)
	points.append(points[0])
	draw_dashed_polyline(points, UITokens.LINE_STRONG, 1.5)


func draw_dashed_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i: int in points.size() - 1:
		draw_dashed_line(points[i], points[i + 1], color, width, 6.0)
