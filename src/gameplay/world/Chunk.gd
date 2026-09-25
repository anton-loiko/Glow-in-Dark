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
const MAX_GLOW: int = 6
const EMBER_TEX: Texture2D = preload("res://src/assets/vfx/ember.png")
var _glow_sprites: Array[Sprite2D] = []
var _fireflies: CPUParticles2D
static var _biolum_textures: Array[Texture2D] = []


## Hi-res ассеты мира (tools/art/gen_sprites.lua): серый альбедо + normal map, цвет главы — modulate.
static var _floor_by_biome: Dictionary = {} ## biome → Array[CanvasTexture]
static var _props_by_biome: Dictionary = {}
const BIOME_PROPS: Dictionary = {
	&"flooded_city": ["prop_slab", "prop_rubble"],
	&"sleeping_forest": ["prop_stump", "prop_boulder"],
	&"rusty_port": ["prop_crate", "prop_container"],
}
## Альбедо текстур ~0.45 серого — множитель приближает яркость к палитре главы (окружение ≤ 60% яркости врагов в свете).
const TEXTURE_TINT_GAIN: float = 1.6
var _tile_variant: PackedByteArray = PackedByteArray()
var _floor_textures: Array[CanvasTexture] = []
var _prop_textures: Array[CanvasTexture] = []


static func _canvas_texture(base: String) -> CanvasTexture:
	if not ResourceLoader.exists(base + ".png"):
		return null
	var tex: CanvasTexture = CanvasTexture.new()
	tex.diffuse_texture = load(base + ".png")
	if ResourceLoader.exists(base + "_n.png"):
		tex.normal_texture = load(base + "_n.png")
	return tex


## Текстуры биома (src/assets/world/<biome>/); чего нет — берётся из common (пол, плиты/обломки Затопленного города).
static func _load_biome(biome: StringName) -> void:
	if _floor_by_biome.has(biome):
		return
	var floors: Array[CanvasTexture] = []
	for dir: String in [String(biome), "common"]:
		for i: int in range(1, 5):
			var tex: CanvasTexture = _canvas_texture("res://src/assets/world/%s/floor_%d" % [dir, i])
			if tex != null:
				floors.append(tex)
		if not floors.is_empty():
			break
	var props: Array[CanvasTexture] = []
	for file: String in BIOME_PROPS.get(biome, BIOME_PROPS[&"flooded_city"]):
		for dir: String in [String(biome), "common"]:
			var tex: CanvasTexture = _canvas_texture("res://src/assets/world/%s/%s" % [dir, file])
			if tex != null:
				props.append(tex)
				break
	_floor_by_biome[biome] = floors
	_props_by_biome[biome] = props


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
	# Биолюминесценция: грибы и руны (спрайты цвета главы, не красный и не янтарный) + медленные светлячки.
	for i: int in MAX_GLOW:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.use_parent_material = true
		sprite.visible = false
		_glow.add_child(sprite)
		_glow_sprites.append(sprite)
	_fireflies = CPUParticles2D.new()
	_fireflies.use_parent_material = true
	_fireflies.amount = 4
	_fireflies.lifetime = 6.0
	_fireflies.preprocess = 6.0
	_fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies.direction = Vector2.UP
	_fireflies.spread = 180.0
	_fireflies.gravity = Vector2.ZERO
	_fireflies.initial_velocity_min = 3.0
	_fireflies.initial_velocity_max = 10.0
	_fireflies.scale_amount_min = 0.12
	_fireflies.scale_amount_max = 0.2
	_fireflies.texture = EMBER_TEX
	_glow.add_child(_fireflies)


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

	_load_biome(chapter.biome)
	_floor_textures.assign(_floor_by_biome[chapter.biome])
	_prop_textures.assign(_props_by_biome[chapter.biome])
	_floor_color = chapter.palette_color("floor", Color("#2A3A44"))
	_floor_alt = chapter.palette_color("floor_alt", _floor_color.darkened(0.1))
	_glow_color = chapter.palette_color("biolum", Color("#5FB3A1"))
	_tiles.resize(TILE_COUNT * TILE_COUNT)
	_tile_variant.resize(TILE_COUNT * TILE_COUNT)
	for i: int in _tiles.size():
		_tiles[i] = _floor_color.lerp(_floor_alt, rng.randf())
		_tile_variant[i] = rng.randi_range(0, maxi(0, _floor_textures.size() - 1))

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
				_place_prop(body, local, extent, prop_color, rng.randi_range(0, 1))
				_prop_rects.append(rect)
				placed = true
				break
		body.visible = placed
		body.process_mode = Node.PROCESS_MODE_INHERIT if placed else Node.PROCESS_MODE_DISABLED

	_glow_points.clear()
	for i: int in rng.randi_range(2, MAX_GLOW):
		_glow_points.append(Vector2(rng.randf() * size, rng.randf() * size))
	_place_biolum(rng)

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


func _place_prop(body: StaticBody2D, local: Vector2, extent: Vector2, color: Color, variant: int = 0) -> void:
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
	if not _prop_textures.is_empty():
		var tex: CanvasTexture = _prop_textures[variant % _prop_textures.size()]
		poly.texture = tex
		var px: Vector2 = Vector2(256, 256)
		poly.uv = PackedVector2Array([Vector2.ZERO, Vector2(px.x, 0), px, Vector2(0, px.y)])
		poly.color = Color(color.r * TEXTURE_TINT_GAIN, color.g * TEXTURE_TINT_GAIN, color.b * TEXTURE_TINT_GAIN, 1.0)


func _draw() -> void:
	var tile: float = size / TILE_COUNT
	for y: int in TILE_COUNT:
		for x: int in TILE_COUNT:
			var i: int = y * TILE_COUNT + x
			var rect: Rect2 = Rect2(Vector2(x, y) * tile, Vector2(tile, tile))
			if _floor_textures.is_empty():
				draw_rect(rect, _tiles[i])
			else:
				var c: Color = _tiles[i]
				draw_texture_rect(_floor_textures[_tile_variant[i]], rect, false, Color(c.r * TEXTURE_TINT_GAIN, c.g * TEXTURE_TINT_GAIN, c.b * TEXTURE_TINT_GAIN, 1.0))


func _place_biolum(rng: RandomNumberGenerator) -> void:
	if _biolum_textures.is_empty():
		for file: String in ["biolum_mushrooms_1", "biolum_mushrooms_2", "biolum_rune"]:
			var path: String = "res://src/assets/world/common/%s.png" % file
			if ResourceLoader.exists(path):
				_biolum_textures.append(load(path) as Texture2D)
	for i: int in _glow_sprites.size():
		var sprite: Sprite2D = _glow_sprites[i]
		sprite.visible = i < _glow_points.size() and not _biolum_textures.is_empty()
		if not sprite.visible:
			continue
		sprite.texture = _biolum_textures[rng.randi_range(0, _biolum_textures.size() - 1)]
		sprite.position = _glow_points[i]
		sprite.scale = Vector2.ONE * rng.randf_range(0.45, 0.7)
		sprite.modulate = Color(_glow_color, 0.85)
	_fireflies.emission_rect_extents = Vector2(size, size) * 0.5
	_fireflies.position = Vector2(size, size) * 0.5
	var fly: Color = _glow_color.lightened(0.4)
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fade.colors = PackedColorArray([Color(fly, 0.0), Color(fly, 0.9), Color(fly, 0.0)])
	_fireflies.color_ramp = fade


func _draw_glow() -> void:
	for point: Vector2 in _glow_points:
		_glow.draw_circle(point, 16.0, Color(_glow_color, 0.08))
		_glow.draw_circle(point, 9.0, Color(_glow_color, 0.1))
