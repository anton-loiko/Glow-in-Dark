class_name RunHUD
extends Control
## HUD забега S05 (DS правило 8): только полоса XP с уровнем, Искры забега, таймер и пауза.
## HP — радиусом света и виньеткой, без полосок.
## Слушает только EventBus, в узлы геймплея не лезет.

const DANGER_RATIO: float = 0.25
const HEARTBEAT_S: float = 1.2

var _xp_bar: ProgressBar
var _level_label: Label
var _sparks_label: Label
var _timer_label: Label
var _vignette: ColorRect
var _vignette_material: ShaderMaterial
var _light_ratio: float = 1.0
var _damage_flash: float = 0.0
var _xp_flicker: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.run_sparks_changed.connect(_on_sparks_changed)
	EventBus.chapter_timer_tick.connect(_on_timer_tick)
	EventBus.player_light_changed.connect(_on_light_changed)
	EventBus.player_damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta / 0.2)
	var danger: bool = _light_ratio < DANGER_RATIO
	var intensity: float = 0.15 + (1.0 - _light_ratio) * 0.55
	var tint: Color = UITokens.INK_900
	if danger:
		var beat: float = pow(maxf(0.0, sin(Time.get_ticks_msec() / 1000.0 * TAU / HEARTBEAT_S)), 8.0)
		intensity += 0.15 * beat
		tint = UITokens.INK_900.lerp(UITokens.COLD, 0.35)
	if _damage_flash > 0.0:
		tint = tint.lerp(UITokens.THREAT, 0.6 * _damage_flash)
	_vignette_material.set_shader_parameter(&"intensity", clampf(intensity, 0.0, 1.0))
	_vignette_material.set_shader_parameter(&"tint", tint)
	if _xp_flicker:
		_xp_bar.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU)
	else:
		_xp_bar.modulate.a = 1.0


func _build() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = preload("res://src/ui/theme/shaders/vignette.gdshader")
	_vignette.material = _vignette_material
	add_child(_vignette)

	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.side_margin = UITokens.S5
	add_child(safe)
	var column: VBoxContainer = UIKit.vbox(UITokens.S2)
	safe.add_child(column)

	# XP-полоса 8pt spark с номером уровня в кольце (DS S05).
	var xp_row: HBoxContainer = UIKit.hbox(UITokens.S2)
	column.add_child(xp_row)
	var badge: Control = Control.new()
	badge.custom_minimum_size = Vector2(28, 28)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var c: Vector2 = badge.size * 0.5
		badge.draw_circle(c, 13.0, UITokens.INK_700, true, -1.0, true)
		badge.draw_arc(c, 13.0, 0.0, TAU, 32, UITokens.SPARK, 2.0, true))
	xp_row.add_child(badge)
	_level_label = UIKit.label("1", &"number", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override(&"font_size", 13)
	_level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 8)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(_xp_bar)

	# Искры забега слева · таймер строго по центру · пауза 44pt справа.
	var info: Control = Control.new()
	info.custom_minimum_size = Vector2(0, UITokens.TOUCH_MIN)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(info)
	var info_row: HBoxContainer = UIKit.hbox(UITokens.S2)
	info_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_row.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(info_row)
	var pill: PanelContainer = UIKit.panel(&"PanelPill")
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_row.add_child(pill)
	var pill_row: HBoxContainer = UIKit.hbox(UITokens.S1)
	pill.add_child(pill_row)
	var spark_icon: TextureRect = TextureRect.new()
	spark_icon.texture = preload("res://src/assets/ui/icons/cur_spark.png")
	spark_icon.custom_minimum_size = Vector2(18, 18)
	spark_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spark_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spark_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spark_icon.modulate = UITokens.SPARK
	pill_row.add_child(spark_icon)
	_sparks_label = UIKit.label("0", &"number", UITokens.TEXT_PRIMARY)
	pill_row.add_child(_sparks_label)
	info_row.add_child(UIKit.spacer(false))
	var pause: GlowButton = UIKit.button("", GlowButton.Variant.ICON, _on_pause_pressed)
	pause.draw.connect(func() -> void:
		var c: Vector2 = pause.size * 0.5
		var bar: StyleBoxFlat = StyleBoxFlat.new()
		bar.bg_color = UITokens.TEXT_PRIMARY
		bar.set_corner_radius_all(2)
		pause.draw_style_box(bar, Rect2(c + Vector2(-6, -8), Vector2(4, 16)))
		pause.draw_style_box(bar, Rect2(c + Vector2(2, -8), Vector2(4, 16))))
	info_row.add_child(pause)
	_timer_label = UIKit.label("00:00", &"number", UITokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER)
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_label.add_theme_font_size_override(&"font_size", 16)
	info.add_child(_timer_label)


func _on_xp_changed(current: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = current
	_level_label.text = str(level)
	_xp_flicker = needed > 0 and float(current) / needed >= 0.9


func _on_sparks_changed(total: int, _delta: int) -> void:
	_sparks_label.text = UIKit.format_number(total)


func _on_timer_tick(elapsed_s: float) -> void:
	var s: int = floori(elapsed_s)
	_timer_label.text = UIKit.format_time(s)


func _on_light_changed(current: float, max_value: float) -> void:
	_light_ratio = 0.0 if max_value <= 0.0 else current / max_value


func _on_player_damaged(_amount: float, _source: StringName) -> void:
	_damage_flash = 1.0


func _on_pause_pressed() -> void:
	SceneRouter.open_modal(&"S07")
