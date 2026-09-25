class_name FirebaseAnalyticsBackend
extends TelemetryBackend
## Firebase Analytics + Crashlytics через godot-x/firebase 3.x (D16): синглтоны GodotxFirebaseCore/Analytics/Crashlytics.
## Сбор выключен до согласия (Privacy-safe defaults плагина); set_consent() включает его после ConsentManager.
## До инициализации события копятся в очереди (≤ 200). Параметры приводятся к ограничениям Firebase:
## имя ≤ 40 символов, строка ≤ 100, bool → 0/1.
## Пробел плагина: нет setUserProperty/setUserId — вызываем, только если метод появился (форк/PR, task_7 §7).

const CORE: String = "GodotxFirebaseCore"
const ANALYTICS: String = "GodotxFirebaseAnalytics"
const CRASHLYTICS: String = "GodotxFirebaseCrashlytics"
const QUEUE_LIMIT: int = 200

var _core: Object
var _analytics: Object
var _crashlytics: Object
var _initialized: bool = false
var _queue: Array[Array] = []
var _user_properties: Dictionary = {}


static func is_supported() -> bool:
	return Engine.has_singleton(CORE) and Engine.has_singleton(ANALYTICS)


func _init() -> void:
	if not is_supported():
		return
	_core = Engine.get_singleton(CORE)
	_analytics = Engine.get_singleton(ANALYTICS)
	if Engine.has_singleton(CRASHLYTICS):
		_crashlytics = Engine.get_singleton(CRASHLYTICS)
	_core.connect(&"core_initialized", _on_core_initialized)
	_analytics.connect(&"analytics_initialized", _on_analytics_initialized)
	_core.call(&"initialize")


func log_event(name: StringName, params: Dictionary) -> void:
	if not _initialized:
		if _queue.size() < QUEUE_LIMIT:
			_queue.append([name, params])
		return
	_analytics.call(&"log_event", String(name).left(40), sanitize(params))


func set_user_property(name: StringName, value: String) -> void:
	_user_properties[String(name)] = value.left(36)
	if _initialized and _analytics.has_method(&"set_user_property"):
		_analytics.call(&"set_user_property", String(name).left(24), value.left(36))
	if _crashlytics != null and _initialized:
		_crashlytics.call(&"set_custom_value_string", String(name), value)


## Согласие (GDPR, Consent Mode v2): вызывается на согласие, отказ и отзыв.
func set_consent(granted: bool) -> void:
	if _analytics == null:
		return
	var state: String = "granted" if granted else "denied"
	_analytics.call(&"set_consent", {"analytics_storage": state, "ad_storage": state, "ad_user_data": state, "ad_personalization": state})
	_analytics.call(&"set_analytics_collection_enabled", granted)
	if _crashlytics != null:
		_crashlytics.call(&"set_crashlytics_collection_enabled", granted)


func log_breadcrumb(message: String) -> void:
	if _crashlytics != null and _initialized:
		_crashlytics.call(&"log_message", message)


## Приведение параметров к типам и лимитам Firebase.
static func sanitize(params: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in params:
		var value: Variant = params[key]
		var k: String = str(key).left(40)
		match typeof(value):
			TYPE_INT, TYPE_FLOAT:
				out[k] = value
			TYPE_BOOL:
				out[k] = 1 if value else 0
			TYPE_ARRAY:
				out[k] = ",".join(PackedStringArray(value as Array)).left(100)
			_:
				out[k] = str(value).left(100)
	return out


func _on_core_initialized(success: bool) -> void:
	if not success:
		return
	_analytics.call(&"initialize")
	if _crashlytics != null:
		_crashlytics.call(&"initialize")


func _on_analytics_initialized(success: bool) -> void:
	_initialized = success
	if not success:
		return
	for key: String in _user_properties:
		set_user_property(StringName(key), str(_user_properties[key]))
	for entry: Array in _queue:
		log_event(entry[0] as StringName, entry[1] as Dictionary)
	_queue.clear()
