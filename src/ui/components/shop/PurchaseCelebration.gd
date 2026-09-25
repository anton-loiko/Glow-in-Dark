class_name PurchaseCelebration
extends CanvasLayer
## Шоу покупки за реальные деньги (task_7 §2): 1.5 с — экран пульсирует голубым, «+N ◆» влетает в счётчик
## Кристаллов (правый верх), хаптика success, затем тост. «Без вспышек» — пульс вдвое слабее.

const SHOW_S: float = 1.5


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.purchase_completed.connect(_on_purchase_completed)


func _on_purchase_completed(product_id: StringName) -> void:
	var product: ShopProductDef = ConfigDB.get_product(product_id)
	if product == null or not product.is_real_money():
		return
	play(int(product.grants.get("crystals", 0)))


func play(crystals: int) -> void:
	FeedbackManager.haptic(&"success")
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var pulse: ColorRect = ColorRect.new()
	pulse.color = Color(UITokens.CRYSTAL_500, 0.0)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.size = viewport
	add_child(pulse)
	var peak: float = 0.12 if GameManager.profile.settings.no_flashes else 0.25
	var t: Tween = UIMotion.tween(pulse)
	for i: int in 2:
		t.tween_property(pulse, ^"color:a", peak, 0.2)
		t.tween_property(pulse, ^"color:a", 0.0, 0.35)
	t.tween_callback(pulse.queue_free)
	if crystals > 0:
		var label: Label = UIKit.label("+%s ◆" % UIKit.format_number(crystals), &"display", UITokens.CRYSTAL_300, HORIZONTAL_ALIGNMENT_CENTER)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = Vector2(viewport.x, 48)
		label.position = Vector2(0, viewport.y * 0.42)
		label.pivot_offset = label.size * 0.5
		add_child(label)
		var fly: Tween = UIMotion.tween(label)
		fly.tween_property(label, ^"scale", Vector2.ONE * 1.15, 0.25).set_custom_interpolator(UIMotion.settle)
		fly.tween_interval(0.5)
		fly.tween_property(label, ^"position", Vector2(viewport.x * 0.35, UITokens.SAFE_TOP), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.parallel().tween_property(label, ^"scale", Vector2.ONE * 0.3, 0.6)
		fly.parallel().tween_property(label, ^"modulate:a", 0.0, 0.6)
		fly.tween_callback(label.queue_free)
	await get_tree().create_timer(SHOW_S, true, false, true).timeout
	EventBus.toast_requested.emit(tr("Покупка завершена · спасибо!"), &"shop")
