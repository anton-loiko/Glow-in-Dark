class_name RunHUD
extends Control
## HUD забега S05 (DS правило 8): только полоса XP с уровнем, Искры забега, таймер и пауза.
## HP — радиусом света и виньеткой, без полосок. Временная вёрстка до task_5 (компоненты DS).
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = preload("res://src/ui/theme/shaders/vignette.gdshader")
	_vignette.material = _vignette_material
	add_child(_vignette)

	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	safe.add_theme_constant_override(&"margin_top", 44 + UITokens.S2)
	safe.add_theme_constant_override(&"margin_left", UITokens.S5)
	safe.add_theme_constant_override(&"margin_right", UITokens.S5)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", UITokens.S2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)

	var xp_row: HBoxContainer = HBoxContainer.new()
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(xp_row)
	_level_label = _label("1", UITokens.SPARK)
	xp_row.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 8)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = UITokens.SPARK
	fill.set_corner_radius_all(4)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = UITokens.INK_600
	bg.set_corner_radius_all(4)
	_xp_bar.add_theme_stylebox_override(&"fill", fill)
	_xp_bar.add_theme_stylebox_override(&"background", bg)
	xp_row.add_child(_xp_bar)

	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(info_row)
	_sparks_label = _label("● 0", UITokens.SPARK)
	info_row.add_child(_sparks_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(spacer)
	_timer_label = _label("00:00", UITokens.TEXT_SECONDARY)
	info_row.add_child(_timer_label)
	var pause: Button = Button.new()
	pause.text = "II"
	pause.custom_minimum_size = Vector2(44, 44)
	pause.pressed.connect(_on_pause_pressed)
	info_row.add_child(pause)


func _label(text: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_xp_changed(current: int, needed: int, level: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = current
	_level_label.text = str(level)
	_xp_flicker = needed > 0 and float(current) / needed >= 0.9


func _on_sparks_changed(total: int, _delta: int) -> void:
	_sparks_label.text = "● %d" % total


func _on_timer_tick(elapsed_s: float) -> void:
	var s: int = floori(elapsed_s)
	_timer_label.text = "%02d:%02d" % [floori(s / 60.0), s % 60]


func _on_light_changed(current: float, max_value: float) -> void:
	_light_ratio = 0.0 if max_value <= 0.0 else current / max_value


func _on_player_damaged(_amount: float, _source: StringName) -> void:
	_damage_flash = 1.0


func _on_pause_pressed() -> void:
	SceneRouter.open_modal(&"S07")
