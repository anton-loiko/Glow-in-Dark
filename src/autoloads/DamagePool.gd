extends Node
## Пул цифр урона (GDD 3.4, DS §02): 40 объектов без роста, не больше 12 видимых одновременно
## (старейшая гасится). Слушает EventBus.damage_dealt — враги не знают о пуле.
## Сцена забега вызывает bind_world(container) при старте и unbind() на выходе.

var pool_size: int = 40
var max_visible: int = 12

var _pool: ObjectPool
var _container: Node2D


func _ready() -> void:
	set_process(false)
	var cfg: Dictionary = ConfigDB.get_balance().get("damage_numbers", {}) as Dictionary
	pool_size = int(cfg.get("pool_size", pool_size))
	max_visible = int(cfg.get("max_visible", max_visible))
	EventBus.damage_dealt.connect(_on_damage_dealt)


func bind_world(container: Node2D) -> void:
	unbind()
	_container = container
	_pool = ObjectPool.new()
	_pool.prewarm(_create_number, pool_size, container)


func unbind() -> void:
	if _pool != null:
		_pool.clear()
	_pool = null
	_container = null


func show_damage(amount: int, world_pos: Vector2, style: DamageNumber.Style) -> void:
	if _pool == null:
		return
	var mode: int = GameManager.profile.settings.damage_numbers if GameManager.profile != null else 1
	if mode == 0:
		return
	if _pool.active_count() >= max_visible:
		_pool.release(_pool.oldest_active())
	var number: DamageNumber = _pool.acquire() as DamageNumber
	if number == null:
		return
	number.play(amount, world_pos, style, 1.25 if mode == 2 else 1.0)


func visible_count() -> int:
	return 0 if _pool == null else _pool.active_count()


func _create_number() -> Node:
	var number: DamageNumber = DamageNumber.new()
	number.finished.connect(_on_number_finished)
	return number


func _on_number_finished(number: DamageNumber) -> void:
	if _pool != null:
		_pool.release(number)


func _on_damage_dealt(amount: int, world_pos: Vector2, style: int) -> void:
	show_damage(amount, world_pos, style as DamageNumber.Style)
