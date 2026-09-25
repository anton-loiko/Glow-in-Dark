class_name GlowTabBar
extends Control
## Таб-бар DS §02: Маяк · Магазин · [В БОЙ] · Навыки (Книга) · Экипировка (Шлем).
## Иконки 26pt в зоне 64×56; активная — заливка light 20% + контур + G1. Ember «В БОЙ» выше панели.
## Вкладки переключаются кроссфейдом 160 мс (SceneRouter). Красная точка — «есть что забрать».

const TABS: Array[StringName] = [&"S02", &"S10", &"", &"S11", &"S12"]
const LABELS: Dictionary = {&"S02": "Маяк", &"S10": "Магазин", &"S11": "Навыки", &"S12": "Экипировка"}

@export var active: StringName = &"S02"

var ember: EmberButton
var _dots: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(0, UITokens.TAB_BAR_H)
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = UIKit.hbox(0, BoxContainer.ALIGNMENT_CENTER)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 18
	add_child(row)
	for id: StringName in TABS:
		if id == &"":
			var slot: Control = Control.new()
			slot.custom_minimum_size = Vector2(UITokens.EMBER_HUB, 0)
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(slot)
			continue
		var tab: Button = Button.new()
		tab.theme_type_variation = &"ButtonQuiet"
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(64, 56)
		tab.focus_mode = Control.FOCUS_NONE
		tab.text = ""
		tab.pressed.connect(_on_tab.bind(id))
		tab.draw.connect(_draw_tab.bind(tab, id))
		row.add_child(tab)
	var hub: bool = active == &"S02"
	ember = EmberButton.new()
	ember.diameter = UITokens.EMBER_HUB if hub else UITokens.EMBER_TAB
	ember.glow_enabled = hub
	ember.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ember.position = Vector2(-ember.diameter * 0.5, -ember.diameter * 0.35)
	ember.pressed.connect(_on_fight)
	add_child(ember)
	refresh_dots()
	EventBus.inventory_changed.connect(refresh_dots)
	EventBus.skin_equipped.connect(_on_skin_equipped)
	EventBus.ad_reward_granted.connect(_on_ad_reward)


## Красные точки «есть что забрать»: Магазин — бесплатный дар ▶; Экипировка — новые Огоньки и предметы.
func refresh_dots() -> void:
	if GameManager.profile == null:
		return
	set_dot(&"S10", StoreManager.free_gift_ready())
	var has_new: bool = not GameManager.profile.skins_new_badge.is_empty()
	for item: PlayerProfile.GearItem in GameManager.profile.gear_inventory:
		has_new = has_new or item.is_new
	set_dot(&"S12", has_new)


func _on_skin_equipped(_id: StringName) -> void:
	refresh_dots()


func _on_ad_reward(_placement: StringName) -> void:
	refresh_dots()


func set_dot(tab_id: StringName, shown: bool) -> void:
	_dots[tab_id] = shown
	queue_redraw()
	for child: Node in get_children():
		if child is HBoxContainer:
			for tab: Node in child.get_children():
				(tab as Control).queue_redraw()


func _on_tab(id: StringName) -> void:
	if id != active:
		SceneRouter.go(id)


func _on_fight() -> void:
	GameManager.start_run(GameManager.profile.current_chapter)


func _draw() -> void:
	draw_rect(Rect2(Vector2(0, 18), Vector2(size.x, size.y - 18)), UITokens.INK_800)
	draw_line(Vector2(0, 18), Vector2(size.x, 18), UITokens.LINE, 1.0)


func _draw_tab(tab: Button, id: StringName) -> void:
	var is_active: bool = id == active
	var center: Vector2 = Vector2(tab.size.x * 0.5, 22)
	if is_active:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(UITokens.LIGHT_500, 0.2)
		box.border_color = UITokens.LIGHT_500
		box.set_border_width_all(1)
		box.set_corner_radius_all(UITokens.R14)
		box.shadow_color = Color(UITokens.LIGHT_500, 0.25)
		box.shadow_size = 6
		tab.draw_style_box(box, Rect2(center - Vector2(24, 18), Vector2(48, 36)))
	var color: Color = UITokens.LIGHT_500 if is_active else UITokens.TEXT_MUTED
	_draw_icon(tab, id, center, color)
	var font: Font = UIFonts.font(&"label")
	var text: String = tr(LABELS[id])
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10).x
	tab.draw_string(font, Vector2(center.x - w * 0.5, 52), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	if bool(_dots.get(id, false)):
		tab.draw_circle(center + Vector2(14, -12), 4.0, UITokens.THREAT)


## Временные глифы вкладок до SVG-иконок (task_8): Маяк — ромб, Магазин — сундук, Навыки — книга, Экипировка — шлем.
func _draw_icon(tab: Button, id: StringName, c: Vector2, color: Color) -> void:
	match id:
		&"S02":
			tab.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(8, -2), c + Vector2(0, 6), c + Vector2(-8, -2)]), color)
			tab.draw_rect(Rect2(c + Vector2(-9, 7), Vector2(18, 4)), color)
		&"S10":
			tab.draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 15)), color)
			tab.draw_rect(Rect2(c + Vector2(-11, -11), Vector2(22, 6)), color.darkened(0.25))
		&"S11":
			tab.draw_rect(Rect2(c + Vector2(-11, -10), Vector2(10, 20)), color)
			tab.draw_rect(Rect2(c + Vector2(1, -10), Vector2(10, 20)), color.darkened(0.2))
		&"S12":
			tab.draw_circle(c + Vector2(0, -2), 10.0, color)
			tab.draw_rect(Rect2(c + Vector2(-10, -2), Vector2(20, 10)), color)
			tab.draw_rect(Rect2(c + Vector2(-6, 0), Vector2(12, 4)), UITokens.INK_800)
