class_name PerfOverlay
extends CanvasLayer
## Перф-оверлей забега (task_8 §5), только debug-сборка и флаг features.perf_overlay.
## FPS, время кадра, draw calls, активные враги / искры / цифры урона, свет, мс систем (PerfStats).
## Переключение: F10 или тап тремя пальцами.

const REFRESH_S: float = 0.25

var enemies: EnemyManager
var pickups: PickupSystem
var run: RunContext
var _label: Label
var _acc: float = 0.0
var _touches: Dictionary = {}


static func is_allowed() -> bool:
	return OS.is_debug_build() and ConfigDB.feature("perf_overlay")


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(6, 52)
	_label.add_theme_font_size_override(&"font_size", 10)
	_label.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.7))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F10:
		visible = not visible
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touches[touch.index] = true
			if _touches.size() >= 3:
				visible = not visible
				_touches.clear()
		else:
			_touches.erase(touch.index)


func _process(delta: float) -> void:
	if not visible:
		return
	_acc -= delta
	if _acc > 0.0:
		return
	_acc = REFRESH_S
	_label.text = report()


func report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS %d · кадр %.1f мс · физика %.1f мс" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("draw calls %d · объекты %d · узлы %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var counts: PackedStringArray = PackedStringArray()
	if enemies != null:
		counts.append("враги %d" % enemies.active_count())
	if pickups != null:
		counts.append("искры %d" % pickups.active_sparks())
	counts.append("цифры %d" % DamagePool.active_count())
	if run != null:
		counts.append("свет +%d/%d" % [run.light_budget.active_count(), run.light_budget.max_extra])
	lines.append(" · ".join(counts))
	var systems: PackedStringArray = PackedStringArray()
	for system: Variant in PerfStats.systems():
		systems.append("%s %.2f" % [system, PerfStats.avg_ms(StringName(str(system)))])
	lines.append("мс: " + " · ".join(systems))
	lines.append("VRAM %.0f МБ · static %.0f МБ" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	return "\n".join(lines)
