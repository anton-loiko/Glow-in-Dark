class_name AppodealBackend
extends AdsBackend
## Appodeal Rewarded Video через нашу тонкую обёртку (D17): Android — JNI-синглтон «GodotAppodeal»
## (plugins/appodeal/android), iOS — GDExtension-класс «AppodealPlugin» (plugins/appodeal/ios).
## Контракт обёртки — docs/research/appodeal_wrapper.md. Согласия (ConsentManager/UMP) и ATT
## обёртка выполняет до инициализации SDK; наружу — только Rewarded.
## Награда засчитывается по rewarded_finished; rewarded_closed без finished — отказ от награды.

const ANDROID_SINGLETON: String = "GodotAppodeal"
const IOS_CLASS: StringName = &"AppodealPlugin"

var _plugin: Object
var _placement: StringName = &""
var _finished: bool = false


static func is_supported() -> bool:
	return (OS.get_name() == "Android" and Engine.has_singleton(ANDROID_SINGLETON)) \
		or (OS.get_name() == "iOS" and ClassDB.class_exists(IOS_CLASS))


func initialize() -> void:
	if OS.get_name() == "Android" and Engine.has_singleton(ANDROID_SINGLETON):
		_plugin = Engine.get_singleton(ANDROID_SINGLETON)
	elif OS.get_name() == "iOS" and ClassDB.class_exists(IOS_CLASS):
		_plugin = ClassDB.instantiate(IOS_CLASS)
	if _plugin == null:
		return
	_plugin.connect(&"rewarded_finished", _on_finished)
	_plugin.connect(&"rewarded_closed", _on_closed)
	_plugin.connect(&"rewarded_show_failed", _on_show_failed)
	var cfg: Dictionary = ConfigDB.get_config("ads")
	var keys: Dictionary = cfg.get("app_keys", {}) as Dictionary
	var app_key: String = str(keys.get(OS.get_name().to_lower(), ""))
	var testing: bool = OS.is_debug_build() and bool(cfg.get("test_mode_in_debug", true))
	_plugin.call(&"initialize", app_key, testing)


func is_rewarded_ready() -> bool:
	return _plugin != null and bool(_plugin.call(&"is_rewarded_loaded"))


func show_rewarded(placement: StringName) -> void:
	if not is_rewarded_ready():
		rewarded_failed.emit(placement, "not_loaded")
		return
	_placement = placement
	_finished = false
	_plugin.call(&"show_rewarded", String(placement))


## Открыть форму настроек конфиденциальности (S13), если ConsentManager её требует.
func show_privacy_options() -> void:
	if _plugin != null and _plugin.has_method(&"show_privacy_options"):
		_plugin.call(&"show_privacy_options")


func privacy_options_required() -> bool:
	return _plugin != null and _plugin.has_method(&"privacy_options_required") and bool(_plugin.call(&"privacy_options_required"))


func _on_finished(_amount: float, _currency: String) -> void:
	_finished = true


func _on_closed(finished: bool) -> void:
	var placement: StringName = _placement
	_placement = &""
	if placement != &"":
		rewarded_finished.emit(placement, finished or _finished)


func _on_show_failed() -> void:
	var placement: StringName = _placement
	_placement = &""
	if placement != &"":
		rewarded_failed.emit(placement, "show_failed")
