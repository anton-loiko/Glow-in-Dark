extends GdUnitTestSuite
## DamagePool: 40 объектов без роста, не больше 12 видимых одновременно.

var _world: Node2D


func before_test() -> void:
	_world = auto_free(Node2D.new())
	add_child(_world)
	DamagePool.bind_world(_world)


func after_test() -> void:
	DamagePool.unbind()


func test_200_hits_keep_limits() -> void:
	for i: int in 200:
		EventBus.damage_dealt.emit(i, Vector2(i, 0), DamageNumber.Style.NORMAL)
	assert_int(DamagePool.visible_count()).is_less_equal(12)
	assert_int(_world.get_child_count()).is_equal(40)


func test_numbers_return_to_pool_after_animation() -> void:
	EventBus.damage_dealt.emit(42, Vector2.ZERO, DamageNumber.Style.LETHAL)
	assert_int(DamagePool.visible_count()).is_equal(1)
	await await_millis(800)
	assert_int(DamagePool.visible_count()).is_equal(0)


func test_object_pool_does_not_grow() -> void:
	var parent: Node = auto_free(Node.new())
	add_child(parent)
	var pool: ObjectPool = ObjectPool.new()
	pool.prewarm(Node2D.new, 3, parent)
	assert_object(pool.acquire()).is_not_null()
	assert_object(pool.acquire()).is_not_null()
	assert_object(pool.acquire()).is_not_null()
	assert_object(pool.acquire()).is_null()
	assert_int(parent.get_child_count()).is_equal(3)
	pool.clear()
