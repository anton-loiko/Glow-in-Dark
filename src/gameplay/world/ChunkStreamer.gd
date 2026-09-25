class_name ChunkStreamer
extends Node2D
## Бесконечный мир из чанков вокруг игрока (task_2 §7): активное окно (2r+1)², чанки из пула,
## при переходе игрока в новую клетку уходящие чанки перестраиваются в приходящие.

signal chunk_built(chunk: Chunk)

var chunk_size: float = 480.0
var radius: int = 2
var run_seed: int = 0
var chapter: ChapterDef
var world_cfg: Dictionary = {}
var target: Node2D

var _chunks: Dictionary[Vector2i, Chunk] = {}
var _free: Array[Chunk] = []
var _center: Vector2i = Vector2i(2147483647, 0)


func setup(p_target: Node2D, p_chapter: ChapterDef, p_seed: int, balance: Dictionary) -> void:
	target = p_target
	chapter = p_chapter
	run_seed = p_seed
	world_cfg = balance.get("world", {}) as Dictionary
	chunk_size = float(world_cfg.get("chunk_size_pt", 480.0))
	radius = int(world_cfg.get("active_radius_chunks", 2))
	var window: int = (radius * 2 + 1) * (radius * 2 + 1)
	for i: int in window + (radius * 2 + 1):
		var chunk: Chunk = Chunk.new()
		chunk.visible = false
		chunk.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(chunk)
		_free.append(chunk)
	_refresh(cell_of(target.global_position))


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var cell: Vector2i = cell_of(target.global_position)
	if cell != _center:
		_refresh(cell)


func cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / chunk_size), floori(world_pos.y / chunk_size))


func chunk_at(world_pos: Vector2) -> Chunk:
	return _chunks.get(cell_of(world_pos))


## Точка внутри пропса (стены) — для правил спавна (task_3).
func is_point_blocked(world_pos: Vector2) -> bool:
	var chunk: Chunk = chunk_at(world_pos)
	return chunk != null and chunk.is_point_blocked(world_pos)


func active_chunks() -> Array[Chunk]:
	var list: Array[Chunk] = []
	list.assign(_chunks.values())
	return list


func _refresh(center: Vector2i) -> void:
	_center = center
	var needed: Dictionary[Vector2i, bool] = {}
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			needed[center + Vector2i(dx, dy)] = true
	for cell: Vector2i in _chunks.keys():
		if not needed.has(cell):
			var old: Chunk = _chunks[cell]
			_chunks.erase(cell)
			old.visible = false
			old.process_mode = Node.PROCESS_MODE_DISABLED
			_free.append(old)
	for cell: Vector2i in needed:
		if _chunks.has(cell):
			continue
		var chunk: Chunk = _free.pop_back()
		chunk.build(cell, chunk_size, run_seed, chapter, world_cfg)
		chunk.visible = true
		chunk.process_mode = Node.PROCESS_MODE_INHERIT
		_chunks[cell] = chunk
		chunk_built.emit(chunk)
