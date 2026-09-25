class_name ShopProductDef
extends Resource
## Товар магазина. kind: iap (реальные деньги) | crystals | sparks.

@export var id: StringName
@export var kind: StringName
@export var store_sku: String = ""
@export var price: Dictionary = {}
@export var grants: Dictionary = {}
@export var one_time: bool = false
@export var badge: StringName


func apply_dict(d: Dictionary) -> void:
	id = StringName(d.get("id", id))
	kind = StringName(d.get("kind", kind))
	store_sku = str(d.get("store_sku", store_sku))
	price = d.get("price", price) as Dictionary
	grants = d.get("grants", grants) as Dictionary
	one_time = bool(d.get("one_time", one_time))
	badge = StringName(d.get("badge", badge))


func is_real_money() -> bool:
	return kind == &"iap"
