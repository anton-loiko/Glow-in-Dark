extends Node
## Фасад аналитики. Весь код игры логирует события только через него; имена — из docs/analytics_events.md.
## Бэкенд: Firebase Analytics на устройстве (godot-x/firebase), иначе Debug (консоль + оверлей F9 в debug-сборке).

var backend: TelemetryBackend
var _overlay: Label


func _ready() -> void:
	set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FirebaseAnalyticsBackend.is_supported():
		backend = FirebaseAnalyticsBackend.new()
	else:
		backend = DebugTelemetryBackend.new()
	EventBus.profile_loaded.connect(update_user_properties)
	EventBus.beacon_level_changed.connect(_on_beacon_level_changed)
	EventBus.skin_equipped.connect(_on_skin_equipped)
	EventBus.purchase_completed.connect(_on_purchase_completed)


func log_event(event_name: StringName, params: Dictionary = {}) -> void:
	backend.log_event(event_name, params)
	if _overlay != null and _overlay.visible:
		_refresh_overlay()


func screen_view(screen_id: StringName) -> void:
	log_event(&"screen_view", {"screen_id": String(screen_id)})


## Стандартные события Firebase earn_/spend_virtual_currency.
func log_economy(currency: StringName, delta: int, reason: StringName, balance: int) -> void:
	var event_name: StringName = &"earn_virtual_currency" if delta >= 0 else &"spend_virtual_currency"
	log_event(event_name, {
		"virtual_currency_name": String(currency),
		"value": absi(delta),
		"reason": String(reason),
		"balance": balance,
	})


func set_user_property(property: StringName, value: Variant) -> void:
	backend.set_user_property(property, str(value))


## Согласие на сбор (ConsentManager Appodeal → сюда; отказ и отзыв — тоже).
func set_consent(granted: bool) -> void:
	backend.set_consent(granted)


func update_user_properties() -> void:
	var profile: PlayerProfile = GameManager.profile
	if profile == null:
		return
	set_user_property(&"install_ts", profile.install_ts)
	set_user_property(&"beacon_level", _total_beacon_level(profile))
	set_user_property(&"chapter", profile.current_chapter)
	set_user_property(&"payer", 1 if not profile.receipts.is_empty() else 0)
	set_user_property(&"equipped_skin", String(profile.skin_equipped))


func _total_beacon_level(profile: PlayerProfile) -> int:
	var total: int = 0
	for chapter_id: int in profile.beacons:
		total += profile.beacons[chapter_id].level
	return total


func _on_beacon_level_changed(_chapter_id: int, _level: int) -> void:
	set_user_property(&"beacon_level", _total_beacon_level(GameManager.profile))


func _on_skin_equipped(skin_id: StringName) -> void:
	set_user_property(&"equipped_skin", String(skin_id))


func _on_purchase_completed(_product_id: StringName) -> void:
	set_user_property(&"payer", 1 if not GameManager.profile.receipts.is_empty() else 0)


# --- Debug-оверлей последних 20 событий (F9, только debug-сборка) ---

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not backend is DebugTelemetryBackend:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F9:
		_toggle_overlay()


func _toggle_overlay() -> void:
	if _overlay == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 120
		add_child(layer)
		_overlay = Label.new()
		_overlay.add_theme_font_size_override(&"font_size", 10)
		_overlay.add_theme_color_override(&"font_color", Color(0.7, 1.0, 0.7))
		_overlay.position = Vector2(4, 48)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.visible = false
		layer.add_child(_overlay)
	_overlay.visible = not _overlay.visible
	_refresh_overlay()


func _refresh_overlay() -> void:
	var debug: DebugTelemetryBackend = backend as DebugTelemetryBackend
	if debug != null:
		_overlay.text = "\n".join(debug.history)
