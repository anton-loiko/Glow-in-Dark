class_name GearCell
extends Control
## Ячейка предмета (Gear DS §01): фон редкости + рамка 300→700 + ореол (Редкий/Эпический G1, Эпический — пульс
## α 0.5↔0.9 за 2.4 с, Легендарный G2 + блик-полоса раз в 3 с). Иконка слота, уровень справа снизу,
## звёзды редкости слева снизу, бейджи ↑ (можно улучшить) / 3× (можно слить) / точка «новый».
## item = null — пустой слот куклы (пунктир + «+»). Временная отрисовка до 9-slice-рамок task_8.

signal pressed(cell: GearCell)

var item: PlayerProfile.GearItem
var slot: StringName = &"head"
var cell_size: float = 62.0
var equipped: bool = false
var selected: bool = false
var dimmed: bool = false
var badge_up: bool = false
var badge_merge: bool = false

var _down: bool = false


func setup(p_item: PlayerProfile.GearItem, p_size: float = 62.0) -> GearCell:
	item = p_item
	cell_size = p_size
	if item != null:
		slot = item.slot
	custom_minimum_size = Vector2(cell_size, cell_size)
	return self


func _ready() -> void:
	custom_minimum_size = Vector2(cell_size, cell_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var animated: bool = item != null and item.rarity in [&"epic", &"legendary"]
	set_process(animated)


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var down: bool = false
	var up: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = (event as InputEventMouseButton).pressed
		up = not down
	elif event is InputEventScreenTouch:
		down = (event as InputEventScreenTouch).pressed
		up = not down
	if down:
		_down = true
	elif up and _down:
		_down = false
		if Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
			FeedbackManager.haptic(&"selection")
			pressed.emit(self)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-1.0)
	var t: float = Time.get_ticks_msec() / 1000.0
	if item == null:
		_draw_empty(rect)
		return
	var tokens: Dictionary = UITokens.RARITY.get(item.rarity, UITokens.RARITY[&"common"]) as Dictionary
	var c300: Color = tokens["300"]
	var c700: Color = tokens["700"]
	var glow: int = int(tokens["glow"])
	if glow > 0:
		# Ореол: мягкая текстура gear_glow цвета 300 (Эпический — пульс α 0.5↔0.9 за 2.4 с).
		var alpha: float = 0.55
		if item.rarity == &"epic":
			alpha = lerpf(0.5, 0.9, 0.5 + 0.5 * sin(t * TAU / 2.4))
		var glow_tex: Texture2D = frame_texture(&"glow")
		var grow: float = glow * 0.5
		if glow_tex != null:
			draw_texture_rect(glow_tex, rect.grow(grow), false, Color(c300, alpha * 0.45))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = tokens["bg"]
	box.set_corner_radius_all(UITokens.R14)
	box.draw(get_canvas_item(), rect)
	# Рамка редкости: 9-slice 96px (texture_margin 24), рисуется в 2× и масштабируется 0.5 — углы остаются чёткими.
	var frame: Texture2D = frame_texture(item.rarity)
	if frame != null:
		var sb: StyleBoxTexture = StyleBoxTexture.new()
		sb.texture = frame
		sb.set_texture_margin_all(24)
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		draw_set_transform(rect.position, 0.0, Vector2(0.5, 0.5))
		draw_style_box(sb, Rect2(Vector2.ZERO, rect.size * 2.0))
		draw_set_transform(Vector2.ZERO)
	else:
		var border: StyleBoxFlat = StyleBoxFlat.new()
		border.draw_center = false
		border.border_color = c700
		border.set_border_width_all(2)
		border.set_corner_radius_all(UITokens.R14)
		border.draw(get_canvas_item(), rect)
	if selected or equipped:
		var outline: StyleBoxFlat = StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = UITokens.LIGHT_500 if selected else Color(UITokens.LIGHT_500, 0.6)
		outline.set_border_width_all(2)
		outline.set_corner_radius_all(UITokens.R14 + 2)
		outline.draw(get_canvas_item(), rect.grow(3.0))
	if item.rarity == &"legendary":
		var phase: float = fmod(t, 3.0) / 0.6
		if phase < 1.0:
			var x: float = lerpf(rect.position.x - 10.0, rect.end.x + 10.0, phase)
			draw_line(Vector2(x, rect.end.y - 4), Vector2(x + 12, rect.position.y + 4), Color(1, 1, 1, 0.35), 5.0)
	var icon: Texture2D = item_icon(item.base_id)
	if icon != null:
		var side: float = size.x * 0.56
		draw_texture_rect(icon, Rect2(rect.get_center() - Vector2(side * 0.5, side * 0.5 + size.y * 0.05), Vector2(side, side)), false, c300)
	else:
		draw_slot_icon(self, slot, rect.get_center() - Vector2(0, size.y * 0.06), size.x * 0.2, c300)
	var font: Font = UIFonts.font(&"number")
	var fs: int = 10 if cell_size < 70.0 else 12
	var lv_text: String = str(item.level)
	var lv_w: float = font.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, rect.end - Vector2(lv_w + 6, 5), lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.TEXT_PRIMARY)
	for i: int in int(tokens["stars"]):
		draw_circle(Vector2(rect.position.x + 7 + i * 5, rect.end.y - 8), 1.6, c300)
	if item.is_new:
		draw_circle(Vector2(rect.end.x - 5, rect.position.y + 5), 4.0, UITokens.THREAT)
	if badge_up:
		draw_string(font, rect.position + Vector2(5, 13), "↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITokens.GAIN)
	if badge_merge:
		draw_string(font, Vector2(rect.end.x - 20, rect.position.y + 13), "3×", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITokens.SPARK)
	if dimmed:
		draw_rect(rect, Color(UITokens.INK_900, 0.6))


func _draw_empty(rect: Rect2) -> void:
	var pts: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i: int in 4:
		draw_dashed_line(pts[i], pts[i + 1], UITokens.LINE_STRONG, 1.5, 6.0)
	# Пустой слот — силуэт базовой вещи слота, приглушённо.
	var bases: Array = (ConfigDB.get_gear_config().get("slot_items", {}) as Dictionary).get(String(&"amulet" if slot == &"amulet_2" else slot), [])
	var icon: Texture2D = item_icon(StringName(str(bases[0]))) if not bases.is_empty() else null
	if icon != null:
		var side: float = size.x * 0.46
		draw_texture_rect(icon, Rect2(rect.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color(UITokens.TEXT_DISABLED, 0.6))
	else:
		draw_slot_icon(self, slot, rect.get_center(), size.x * 0.18, UITokens.TEXT_DISABLED)


static var _icons: Dictionary = {}
static var _frames: Dictionary = {}


## Рамка редкости или ореол (&"glow") из src/assets/ui/gear (tools/brand/make_ui_icons.py).
static func frame_texture(rarity: StringName) -> Texture2D:
	if not _frames.has(rarity):
		var file: String = "gear_glow" if rarity == &"glow" else "frame_" + String(rarity)
		var path: String = "res://src/assets/ui/gear/%s.png" % file
		_frames[rarity] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _frames[rarity]


## Иконка предмета (tools/brand/make_skill_icons.py → src/assets/ui/gear/<base_id>.png), белая под modulate.
static func item_icon(base_id: StringName) -> Texture2D:
	if _icons.has(base_id):
		return _icons[base_id]
	var path: String = "res://src/assets/ui/gear/%s.png" % base_id
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icons[base_id] = tex
	return tex


## Силуэт слота: шлем · ядро · ботинок · амулет.
static func draw_slot_icon(canvas: CanvasItem, slot_id: StringName, c: Vector2, r: float, color: Color) -> void:
	match slot_id:
		&"head":
			canvas.draw_arc(c + Vector2(0, r * 0.3), r, PI, TAU, 16, color, 2.5)
			canvas.draw_line(c + Vector2(-r * 1.1, r * 0.3), c + Vector2(r * 1.1, r * 0.3), color, 2.5)
		&"core":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), color)
		&"feet":
			canvas.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, -r), c + Vector2(-r * 0.4, r * 0.6), c + Vector2(r, r * 0.6)]), color, 3.0)
		_:
			canvas.draw_arc(c - Vector2(0, r * 0.5), r * 0.6, PI * 0.1, PI * 0.9, 10, color, 2.0)
			canvas.draw_circle(c + Vector2(0, r * 0.35), r * 0.5, color)
