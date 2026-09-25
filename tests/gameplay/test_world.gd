extends GdUnitTestSuite
## Мир: детерминизм чанков, окно стриминга, безопасная зона старта.

var _chapter: ChapterDef
var _world_cfg: Dictionary


func before() -> void:
	_chapter = ConfigDB.get_chapter(1)
	_world_cfg = ConfigDB.get_balance()["world"]


func _build(cell: Vector2i, run_seed: int) -> Chunk:
	var chunk: Chunk = auto_free(Chunk.new())
	add_child(chunk)
	chunk.build(cell, 480.0, run_seed, _chapter, _world_cfg)
	return chunk


func test_same_cell_and_seed_give_same_chunk() -> void:
	var a: Chunk = _build(Vector2i(3, -2), 42)
	var b: Chunk = _build(Vector2i(3, -2), 42)
	assert_array(a._prop_rects).is_equal(b._prop_rects)
	assert_array(a.fuel_markers).is_equal(b.fuel_markers)


func test_different_seed_changes_layout() -> void:
	var same: int = 0
	for i: int in 10:
		var a: Chunk = _build(Vector2i(i, 1), 1)
		var b: Chunk = _build(Vector2i(i, 1), 2)
		if a._prop_rects == b._prop_rects:
			same += 1
	assert_int(same).is_less(10)


func test_start_area_is_free_of_props() -> void:
	var safe: float = float(_world_cfg["safe_start_radius_pt"])
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		for run_seed: int in 20:
			var chunk: Chunk = _build(cell, run_seed)
			for rect: Rect2 in chunk._prop_rects:
				assert_bool(rect.grow(safe).has_point(Vector2.ZERO)).is_false()


func test_streamer_keeps_window_and_reuses_chunks() -> void:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	var streamer: ChunkStreamer = auto_free(ChunkStreamer.new())
	add_child(streamer)
	streamer.setup(target, _chapter, 7, ConfigDB.get_balance())
	var total_children: int = streamer.get_child_count()
	assert_int(streamer.active_chunks().size()).is_equal(25)
	target.global_position = Vector2(480 * 3 + 10, 480 * -2 + 10)
	streamer._physics_process(0.016)
	assert_int(streamer.active_chunks().size()).is_equal(25)
	assert_int(streamer.get_child_count()).is_equal(total_children)
	assert_object(streamer.chunk_at(target.global_position)).is_not_null()
