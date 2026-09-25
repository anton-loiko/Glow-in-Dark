class_name GameCenterBackend
extends GameServicesBackend
## Game Center через GodotApplePlugins (GameCenterManager / GKLocalPlayer). Классы берём через ClassDB,
## чтобы код компилировался без аддона. Подпись fetch_items_for_identity_verification_signature
## уходит в Firebase accounts:signInWithGameCenter (FirebaseLink).

const MANAGER_CLASS: StringName = &"GameCenterManager"

var _manager: Object
var _signed_in: bool = false


func platform() -> String:
	return "game_center"


func sign_in_silently() -> void:
	if not ClassDB.class_exists(MANAGER_CLASS):
		sign_in_finished.emit.call_deferred(false)
		return
	if _manager == null:
		_manager = ClassDB.instantiate(MANAGER_CLASS)
		_manager.connect(&"authentication_result", _on_auth_result)
		_manager.connect(&"authentication_error", _on_auth_error)
	# Game Center сам показывает системный баннер или экран входа — отдельного «тихого» режима нет.
	_manager.call(&"authenticate")


func is_signed_in() -> bool:
	return _signed_in


func get_player_id() -> String:
	return _player_prop(&"team_player_id", &"teamPlayerID")


func get_display_name() -> String:
	return _player_prop(&"display_name", &"displayName")


func request_auth_credential() -> void:
	var local: Object = _local_player()
	if local == null or not _signed_in:
		auth_credential_ready.emit.call_deferred({})
		return
	local.call(&"fetch_items_for_identity_verification_signature", _on_identity_items)


func _on_identity_items(values: Dictionary, error: Variant) -> void:
	if error != null or values.is_empty():
		auth_credential_ready.emit({})
		return
	auth_credential_ready.emit({
		"provider": "gamecenter",
		"playerId": _player_prop(&"game_player_id", &"gamePlayerID"),
		"gamePlayerId": _player_prop(&"game_player_id", &"gamePlayerID"),
		"teamPlayerId": _player_prop(&"team_player_id", &"teamPlayerID"),
		"publicKeyUrl": str(values.get("url", "")),
		"signature": Marshalls.raw_to_base64(values.get("data", PackedByteArray()) as PackedByteArray),
		"salt": Marshalls.raw_to_base64(values.get("salt", PackedByteArray()) as PackedByteArray),
		"timestamp": int(values.get("timestamp", 0)),
		"displayName": get_display_name(),
	})


func _on_auth_result(status: bool) -> void:
	_signed_in = status
	sign_in_finished.emit(status)


func _on_auth_error(message: String) -> void:
	push_warning("[GameCenter] %s" % message)
	_signed_in = false
	sign_in_finished.emit(false)


func _local_player() -> Object:
	if _manager == null:
		return null
	var local: Variant = _manager.get(&"local_player")
	if local == null:
		local = _manager.get(&"localPlayer")
	return local as Object


## Имена свойств SwiftGodot в разных сборках — snake_case или camelCase.
func _player_prop(snake: StringName, camel: StringName) -> String:
	var local: Object = _local_player()
	if local == null:
		return ""
	var value: Variant = local.get(snake)
	if value == null:
		value = local.get(camel)
	return "" if value == null else str(value)
