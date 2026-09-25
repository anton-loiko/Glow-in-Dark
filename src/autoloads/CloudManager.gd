extends Node
## Облачное сохранение профиля (Firestore через REST-аддон godot-firebase, D16).
## Работает только со снимком профиля: не знает его полей, слияние — ProfileMerge.
## Авторизация: Firebase Anonymous (сессия хранится аддоном); привязка к гейм-центрам — task_7.

const COLLECTION: String = "users"
const FIELD_PROFILE: String = "profile_json"
const SYNC_TIMEOUT_S: float = 6.0

var state: StringName = &"offline"
var _syncing: bool = false


func _ready() -> void:
	set_process(false)


func is_available() -> bool:
	return is_instance_valid(Firebase) and _auth() != null and _firestore() != null


func _auth() -> FirebaseAuth:
	return Firebase.get(&"Auth") as FirebaseAuth


func _firestore() -> FirebaseFirestore:
	return Firebase.get(&"Firestore") as FirebaseFirestore


func _uid(auth: FirebaseAuth) -> String:
	return str(auth.auth.get("localid", ""))


## Полный цикл: вход → чтение облака → слияние → запись. Никогда не блокирует игру дольше таймаута.
func sync() -> void:
	if _syncing:
		return
	if not is_available():
		_set_state(&"offline")
		return
	_syncing = true
	_set_state(&"syncing")
	var uid: String = await _ensure_auth()
	if uid.is_empty():
		_syncing = false
		_set_state(&"offline")
		return
	var collection: FirestoreCollection = _firestore().collection(COLLECTION)
	var remote_doc: FirestoreDocument = await collection.get_doc(uid)
	if remote_doc != null and remote_doc.get_value(FIELD_PROFILE) != null:
		var parsed: Variant = JSON.parse_string(str(remote_doc.get_value(FIELD_PROFILE)))
		if parsed is Dictionary:
			var remote_data: Dictionary = parsed
			var remote: PlayerProfile = PlayerProfile.from_dict(SaveManager.migrate_dict(remote_data))
			var merged: PlayerProfile = ProfileMerge.merge(GameManager.profile, remote)
			GameManager.set_profile(merged)
			SaveManager.request_save(true)
	await _push(collection, uid)
	_syncing = false
	_set_state(&"synced")


## Записать текущий профиль в облако (после S09, покупок, кат-сцен Маяка).
func push() -> void:
	if not is_available() or not _auth().is_logged_in():
		return
	var uid: String = _uid(_auth())
	if uid.is_empty():
		return
	await _push(_firestore().collection(COLLECTION), uid)


func _push(collection: FirestoreCollection, uid: String) -> void:
	var profile: PlayerProfile = GameManager.profile
	await collection.set_doc(uid, {
		FIELD_PROFILE: JSON.stringify(profile.to_dict()),
		"schema_version": profile.schema_version,
		"updated_at": profile.updated_at,
	})


func _ensure_auth() -> String:
	var auth: FirebaseAuth = _auth()
	if auth.is_logged_in():
		return _uid(auth)
	if auth.load_auth():
		return _uid(auth)
	auth.login_anonymous()
	var timer: SceneTreeTimer = get_tree().create_timer(SYNC_TIMEOUT_S, true, false, true)
	while not auth.is_logged_in() and timer.time_left > 0.0:
		await get_tree().process_frame
	if not auth.is_logged_in():
		return ""
	auth.save_auth(auth.auth)
	return _uid(auth)


func _set_state(new_state: StringName) -> void:
	state = new_state
	EventBus.cloud_sync_state_changed.emit(new_state)
