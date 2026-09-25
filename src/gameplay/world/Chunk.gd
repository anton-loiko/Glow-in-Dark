class_name Chunk
extends Node2D
## Блок мира (GDD 3.2, Art Direction §02 «Свет раскрашивает мир»). Содержимое детерминировано
## от (координаты, seed забега): возврат в ту же клетку показывает тот же чанк.
## Слои: пол (приглушённый) · пропсы с тенью (LightOccluder2D) и коллизией · биолюминесценция.
## Пропсы заранее созданы в пуле чанка — при перестройке узлы не создаются.

const MAX_PROPS: int = 4
const TILE_COUNT: int = 4

var coord: Vector2i
var size: float = 480.0
var fuel_markers: Array[Vector2] = []

var _floor_color: Color
var _floor_alt: Color
var _tiles: PackedColorArray = PackedColorArray()
var _props: Array[StaticBody2D] = []
var _prop_rects: Array[Rect2] = []
var _glow: Node2D
var _glow_points: PackedVector2Array = PackedVector2Array()
var _glow_color: Color


func _init() -> void:
	z_index = -10
	for i: int in MAX_PROPS:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		body.add_child(shape)
		var occluder: LightOccluder2D = LightOccluder2D.new()
		occluder.occluder = OccluderPolygon2D.new()
		body.add_child(occluder)
		var poly: Polygon2D = Polygon2D.new()
		body.add_child(poly)
		body.visible = false
		body.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(body)
		_props.append(body)
	_glow = Node2D.new()
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = unshaded
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _ready() -> void:
	set_process(false)


static func seed_for(cell: Vector2i, run_seed: int) -> int:
	return hash([cell.x, cell.y, run_seed])


func build(cell: Vector2i, p_size: float, run_seed: int, chapter: ChapterDef, world_cfg: Dictionary) -> void:
	coord = cell
	size = p_size
	position = Vector2(cell) * size
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_for(cell, run_seed)

	_floor_color = chapter.palette_color("floor", Color("#2A3A44"))
	_floor_alt = chapter.palette_color("floor_alt", _floor_color.darkened(0.1))
	_glow_color = chapter.palette_color("biolum", Color("#5FB3A1"))
	_tiles.resize(TILE_COUNT * TILE_COUNT)
	for i: int in _tiles.size():
		_tiles[i] = _floor_color.lerp(_floor_alt, rng.randf())

	var prop_range: Array = world_cfg.get("props_per_chunk", [1, 4])
	var prop_count: int = rng.randi_range(int(prop_range[0]), mini(int(prop_range[1]), MAX_PROPS))
	var safe_radius: float = float(world_cfg.get("safe_start_radius_pt", 160.0))
	var prop_color: Color = chapter.palette_color("prop", Color("#1B2630"))
	_prop_rects.clear()
	for i: int in MAX_PROPS:
		var body: StaticBody2D = _props[i]
		var placed: bool = false
		if i < prop_count:
			for attempt: int in 6:
				var extent: Vector2 = Vector2(rng.randf_range(24, 70), rng.randf_range(24, 70))
				var local: Vector2 = Vector2(rng.randf_range(extent.x + 16, size - extent.x - 16), rng.randf_range(extent.y + 16, size - extent.y - 16))
				var rect: Rect2 = Rect2(position + local - extent, extent * 2.0)
				if rect.grow(safe_radius).has_point(Vector2.ZERO) or _overlaps(rect):
					continue
				_place_prop(body, local, extent, prop_color)
				_prop_rects.append(rect)
				placed = true
				break
		body.visible = placed
		body.process_mode = Node.PROCESS_MODE_INHERIT if placed else Node.PROCESS_MODE_DISABLED

	_glow_points.clear()
	for i: int in rng.randi_range(2, 6):
		_glow_points.append(Vector2(rng.randf() * size, rng.randf() * size))

	fuel_markers.clear()
	if rng.randf() < float(world_cfg.get("fuel_marker_chance", 0.35)):
		var marker: Vector2 = position + Vector2(rng.randf_range(40, size - 40), rng.randf_range(40, size - 40))
		if not is_point_blocked(marker):
			fuel_markers.append(marker)
	queue_redraw()
	_glow.queue_redraw()


func is_point_blocked(world_point: Vector2) -> bool:
	for rect: Rect2 in _prop_rects:
		if rect.has_point(world_point):
			return true
	return false


func _overlaps(rect: Rect2) -> bool:
	for other: Rect2 in _prop_rects:
		if other.grow(24.0).intersects(rect):
			return true
	return false


func _place_prop(body: StaticBody2D, local: Vector2, extent: Vector2, color: Color) -> void:
	body.position = local
	var shape: CollisionShape2D = body.get_child(0) as CollisionShape2D
	(shape.shape as RectangleShape2D).size = extent * 2.0
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-extent.x, -extent.y), Vector2(extent.x, -extent.y), Vector2(extent.x, extent.y), Vector2(-extent.x, extent.y),
	])
	var occluder: LightOccluder2D = body.get_child(1) as LightOccluder2D
	occluder.occluder.polygon = outline
	var poly: Polygon2D = body.get_child(2) as Polygon2D
	poly.polygon = outline
	poly.color = color


func _draw() -> void:
	var tile: float = size / TILE_COUNT
	for y: int in TILE_COUNT:
		for x: int in TILE_COUNT:
			draw_rect(Rect2(Vector2(x, y) * tile, Vector2(tile, tile)), _tiles[y * TILE_COUNT + x])
	var seam: Color = _floor_color.darkened(0.25)
	for i: int in TILE_COUNT + 1:
		draw_line(Vector2(i * tile, 0), Vector2(i * tile, size), seam, 1.0)
		draw_line(Vector2(0, i * tile), Vector2(size, i * tile), seam, 1.0)


func _draw_glow() -> void:
	for point: Vector2 in _glow_points:
		_glow.draw_circle(point, 7.0, Color(_glow_color, 0.18))
		_glow.draw_circle(point, 2.5, Color(_glow_color, 0.85))
