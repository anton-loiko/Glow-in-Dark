extends Node
## Облачное сохранение профиля (Firestore через REST-аддон godot-firebase, D16).
## Документ users/{uid}: profile_json (снимок PlayerProfile) + updated_at + schema_version — поля вручную не пакуются.
## Авторизация: Firebase Anonymous → после входа в гейм-центр аккаунт гейм-центра привязывается к анонимному UID
## (Identity Toolkit REST). Если гейм-центр уже привязан к другому UID (переустановка, новое устройство) —
## входим в тот UID и сливаем профили по ProfileMerge (без дюпа валюты).
## Синк: старт (S01, таймаут), после наград забега, покупок, тиров Маяка, уход в фон — с дебаунсом.

signal linked(provider: String, uid: String)

const COLLECTION: String = "users"
const FIELD_PROFILE: String = "profile_json"
const LEGACY_AUTH_FILE: String = "user://secret_auth.cfg"
const IDENTITY_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s"

var state: StringName = &"offline"
var last_synced_at: int = 0
var _syncing: bool = false
var _push_timer: Timer
var _http: HTTPRequest


func _ready() -> void:
	set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_push_timer = Timer.new()
	_push_timer.one_shot = true
	_push_timer.timeout.connect(push)
	add_child(_push_timer)
	_http = HTTPRequest.new()
	_http.timeout = _cfg_float("sync_timeout_s", 6.0)
	add_child(_http)
	EventBus.beacon_tier_reached.connect(_on_beacon_tier)
	EventBus.run_rewards_claimed.connect(_on_run_rewards)
	GameServices.signed_in_changed.connect(_on_game_services_signed_in)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not GameManager.is_run_active():
			push()


func is_available() -> bool:
	if not bool(ConfigDB.get_config("services").get("cloud_sync_enabled", false)):
		return false
	return is_instance_valid(Firebase) and _auth() != null and _firestore() != null


## Полный цикл: вход → привязка гейм-центра → чтение облака → слияние → запись.
## Никогда не блокирует игру дольше таймаута (S01 показывает «Нет сети · играть офлайн»).
func sync() -> void:
	if _syncing:
		return
	if not is_available():
		_set_state(&"offline")
		return
	_syncing = true
	_set_state(&"syncing")
	if FileAccess.file_exists(LEGACY_AUTH_FILE):
		await _migrate_legacy_account()
	var uid: String = await _ensure_auth()
	if uid.is_empty():
		_finish_sync(&"offline")
		return
	uid = await _link_game_services(uid)
	var collection: FirestoreCollection = _firestore().collection(COLLECTION)
	var remote_doc: FirestoreDocument = await collection.get_doc(uid)
	if remote_doc != null and remote_doc.get_value(FIELD_PROFILE) != null:
		var remote: PlayerProfile = parse_remote(str(remote_doc.get_value(FIELD_PROFILE)))
		if remote != null:
			GameManager.set_profile(ProfileMerge.merge(GameManager.profile, remote))
			SaveManager.request_save(true)
	await _push(collection, uid)
	_finish_sync(&"synced")


## Разбор облачного снимка с миграцией схемы; null — повреждённые данные (облако не затирает локальный профиль).
static func parse_remote(profile_json: String) -> PlayerProfile:
	var parsed: Variant = JSON.parse_string(profile_json)
	if not parsed is Dictionary:
		return null
	return PlayerProfile.from_dict(SaveManager.migrate_dict(parsed as Dictionary))


## Отложенная запись: несколько событий подряд дают одну запись.
func schedule_push() -> void:
	if is_available() and is_inside_tree():
		_push_timer.start(_cfg_float("push_debounce_s", 3.0))


## Записать текущий профиль в облако (после покупок — сразу).
func push() -> void:
	if not is_available() or not _auth().is_logged_in():
		return
	var uid: String = _uid(_auth())
	if uid.is_empty():
		return
	await _push(_firestore().collection(COLLECTION), uid)
	last_synced_at = int(Time.get_unix_time_from_system())
	_set_state(&"synced")


func _push(collection: FirestoreCollection, uid: String) -> void:
	var profile: PlayerProfile = GameManager.profile
	await collection.set_doc(uid, {
		FIELD_PROFILE: JSON.stringify(profile.to_dict()),
		"schema_version": profile.schema_version,
		"updated_at": profile.updated_at,
	})


func _finish_sync(new_state: StringName) -> void:
	_syncing = false
	if new_state == &"synced":
		last_synced_at = int(Time.get_unix_time_from_system())
	_set_state(new_state)


# --- Авторизация ---

func _auth() -> FirebaseAuth:
	return Firebase.get(&"Auth") as FirebaseAuth


func _firestore() -> FirebaseFirestore:
	return Firebase.get(&"Firestore") as FirebaseFirestore


func _uid(auth: FirebaseAuth) -> String:
	return str(auth.auth.get("localid", ""))


func _api_key() -> String:
	var config: Dictionary = _auth().get(&"_config") as Dictionary
	return str(config.get("apiKey", "")) if config != null else ""


func _ensure_auth() -> String:
	var auth: FirebaseAuth = _auth()
	if auth.is_logged_in():
		return _uid(auth)
	if auth.load_auth():
		return _uid(auth)
	auth.login_anonymous()
	if not await _wait_logged_in():
		return ""
	auth.save_auth(auth.auth)
	return _uid(auth)


func _wait_logged_in() -> bool:
	var auth: FirebaseAuth = _auth()
	var deadline: int = Time.get_ticks_msec() + int(_cfg_float("sync_timeout_s", 6.0) * 1000.0)
	while not auth.is_logged_in() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return auth.is_logged_in()


## Привязка гейм-центра к анонимному UID. Возвращает UID, под которым продолжаем (может смениться).
func _link_game_services(uid: String) -> String:
	if not GameServices.is_signed_in():
		return uid
	var credential: Dictionary = await GameServices.request_auth_credential()
	if credential.is_empty():
		return uid
	var result: Dictionary = await _sign_in_with_credential(credential)
	var new_uid: String = str(result.get("localId", ""))
	var refresh_token: String = str(result.get("refreshToken", ""))
	if new_uid.is_empty() or refresh_token.is_empty():
		Telemetry.log_event(&"account_link", {"provider": str(credential.get("provider", "")), "result": "failed"})
		return uid
	# Ставим выданные токены в аддон: он обновит idToken и продолжит ротацию сам.
	var auth: FirebaseAuth = _auth()
	auth.manual_token_refresh({"refreshtoken": refresh_token})
	await _wait_logged_in()
	auth.save_auth(auth.auth)
	var switched: bool = new_uid != uid
	Telemetry.log_event(&"account_link", {"provider": str(credential.get("provider", "")), "result": "switched" if switched else "linked"})
	linked.emit(str(credential.get("provider", "")), new_uid)
	return new_uid


## Вход по данным гейм-центра с idToken текущего (анонимного) пользователя — это и есть привязка.
func _sign_in_with_credential(credential: Dictionary) -> Dictionary:
	var id_token: String = str(_auth().auth.get("idtoken", ""))
	match str(credential.get("provider", "")):
		"gamecenter":
			var body: Dictionary = credential.duplicate()
			body.erase("provider")
			body["idToken"] = id_token
			return await _identity_post("signInWithGameCenter", body)
		"playgames":
			var code: String = str(credential.get("server_auth_code", ""))
			var result: Dictionary = await _identity_post("signInWithIdp", {
				"postBody": "providerId=playgames.google.com&code=%s" % code.uri_encode(),
				"requestUri": "http://localhost",
				"idToken": id_token,
				"returnSecureToken": true,
				"returnIdpCredential": true,
			})
			if result.has("localId"):
				return result
			return await _play_games_via_function(code)
	return {}


## Запасной путь Play Games (docs/research/native_plugins.md): Cloud Function меняет server auth code
## на Firebase custom token → signInWithCustomToken.
func _play_games_via_function(code: String) -> Dictionary:
	var url: String = str(ConfigDB.get_config("services").get("play_games_token_exchange_url", ""))
	if url.is_empty():
		return {}
	var response: Dictionary = await _post_json(url, {"server_auth_code": code, "id_token": str(_auth().auth.get("idtoken", ""))})
	var token: String = str(response.get("custom_token", ""))
	if token.is_empty():
		return {}
	return await _identity_post("signInWithCustomToken", {"token": token, "returnSecureToken": true})


func _identity_post(method: String, body: Dictionary) -> Dictionary:
	return await _post_json(IDENTITY_URL % [method, _api_key()], body)


func _post_json(url: String, body: Dictionary) -> Dictionary:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	var err: Error = _http.request(url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return {}
	var response: Array = await _http.request_completed
	var code: int = int(response[1])
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if code != 200 or not parsed is Dictionary:
		push_warning("[CloudManager] %s → HTTP %d" % [url.get_slice("?", 0), code])
		return {}
	return parsed as Dictionary


## MVP хранил «фейковый» email/пароль в открытом виде. Один раз входим старым способом, забираем
## Искры и скины из документа MVP (Искры — максимум с локальными: тот же прогресс мог уже прийти из
## локального сейва), затем удаляем файл и выходим — дальше только анонимный аккаунт + гейм-центр.
func _migrate_legacy_account() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(LEGACY_AUTH_FILE) == OK:
		var auth: FirebaseAuth = _auth()
		auth.login_with_email_and_password(str(config.get_value("auth", "email", "")), str(config.get_value("auth", "password", "")))
		if await _wait_logged_in():
			var doc: FirestoreDocument = await _firestore().collection(COLLECTION).get_doc(_uid(auth))
			if doc != null:
				apply_legacy_cloud(GameManager.profile, doc.get_value("sparks"), doc.get_value("owned_skins"))
				SaveManager.request_save(true)
		auth.logout()
		auth.remove_auth()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_AUTH_FILE))
	Telemetry.log_event(&"account_link", {"provider": "legacy_email", "result": "migrated"})


static func apply_legacy_cloud(profile: PlayerProfile, sparks: Variant, owned_skins: Variant) -> void:
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("inventory", "sparks", int(sparks) if sparks != null else 0)
	legacy.set_value("inventory", "owned_skins", owned_skins if owned_skins is Array else ["default"])
	var migrated: PlayerProfile = LegacySaveMigration.migrate(legacy)
	profile.sparks = maxi(profile.sparks, migrated.sparks)
	for skin: StringName in migrated.skins_unlocked:
		if not profile.skins_unlocked.has(skin):
			profile.skins_unlocked.append(skin)


# --- Триггеры ---

func _on_beacon_tier(_chapter_id: int, _tier: int) -> void:
	schedule_push()


func _on_run_rewards(_multiplier: int) -> void:
	schedule_push()


## Вошли в гейм-центр уже после старта — привязываем в фоне.
func _on_game_services_signed_in(signed_in: bool) -> void:
	if signed_in and state == &"synced" and not _syncing:
		sync()


func _set_state(new_state: StringName) -> void:
	state = new_state
	EventBus.cloud_sync_state_changed.emit(new_state)


func _cfg_float(key: String, fallback: float) -> float:
	return float(ConfigDB.get_config("services").get(key, fallback))
