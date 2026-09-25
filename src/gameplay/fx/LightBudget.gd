class_name LightBudget
extends RefCounted
## Бюджет света в бою (task_8 §2): 1 PointLight2D игрока + до max_extra дополнительных источников
## (топливо, взрывы, сферы, след). Запрос сверх бюджета вытесняет источник с самым низким приоритетом,
## если новый важнее; иначе отклоняется (свет остаётся выключенным — спрайт светится сам).

var max_extra: int = 6
var _active: Array[PointLight2D] = []
var _priority: Dictionary = {} ## PointLight2D -> int


func _init(p_max_extra: int = 6) -> void:
	max_extra = p_max_extra


## Включить свет, если позволяет бюджет. true — включён.
func acquire(light: PointLight2D, priority: int) -> bool:
	if light == null:
		return false
	if _active.has(light):
		return true
	if _active.size() >= max_extra:
		var weakest: PointLight2D = _weakest()
		if weakest == null or int(_priority[weakest]) >= priority:
			return false
		release(weakest)
	_active.append(light)
	_priority[light] = priority
	light.enabled = true
	return true


func release(light: PointLight2D) -> void:
	if light == null or not _active.has(light):
		return
	_active.erase(light)
	_priority.erase(light)
	if is_instance_valid(light):
		light.enabled = false


func active_count() -> int:
	return _active.size()


func clear() -> void:
	for light: PointLight2D in _active.duplicate():
		release(light)


func _weakest() -> PointLight2D:
	var weakest: PointLight2D = null
	for light: PointLight2D in _active:
		if not is_instance_valid(light):
			continue
		if weakest == null or int(_priority[light]) < int(_priority[weakest]):
			weakest = light
	return weakest
