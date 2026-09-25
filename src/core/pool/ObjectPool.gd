class_name ObjectPool
extends RefCounted
## Пул узлов фиксированного размера. Узлы не удаляются: при возврате они скрываются
## и отключаются (process_mode = DISABLED — вместе с процессом из физики выпадают и коллизии).
## Необязательные хуки у пулового узла: pool_acquired() и pool_released().

var _parent: Node
var _free: Array[Node] = []
var _active: Array[Node] = []
var _capacity: int = 0


## Создаёт count узлов фабрикой factory (Callable -> Node) под parent.
func prewarm(factory: Callable, count: int, parent: Node) -> void:
	_parent = parent
	for i: int in count:
		var node: Node = factory.call()
		parent.add_child(node)
		_deactivate(node)
		_free.append(node)
	_capacity += count


func prewarm_scene(scene: PackedScene, count: int, parent: Node) -> void:
	prewarm(scene.instantiate, count, parent)


## Возвращает свободный узел или null, если пул исчерпан (пул не растёт).
func acquire() -> Node:
	if _free.is_empty():
		if OS.is_debug_build():
			push_warning("[ObjectPool] exhausted (capacity %d)" % _capacity)
		return null
	var node: Node = _free.pop_back()
	_active.append(node)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if node.has_method(&"pool_acquired"):
		node.call(&"pool_acquired")
	return node


func release(node: Node) -> void:
	var idx: int = _active.find(node)
	if idx == -1:
		return
	_active.remove_at(idx)
	if node.has_method(&"pool_released"):
		node.call(&"pool_released")
	_deactivate(node)
	_free.append(node)


## Самый давно выданный активный узел (для вытеснения при лимите видимых).
func oldest_active() -> Node:
	return null if _active.is_empty() else _active[0]


## Активные узлы в порядке выдачи. Не изменять массив снаружи.
func active_nodes() -> Array[Node]:
	return _active


func active_count() -> int:
	return _active.size()


func capacity() -> int:
	return _capacity


func clear() -> void:
	for node: Node in _free + _active:
		if is_instance_valid(node):
			node.queue_free()
	_free.clear()
	_active.clear()
	_capacity = 0


func _deactivate(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
