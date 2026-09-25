class_name PlayGamesBackend
extends GameServicesBackend
## Google Play Games Services v2 через godot-play-game-services 3.x (JNI-синглтон GodotPlayGameServices).
## Play Games v2 входит автоматически при старте; здесь только узнаём результат и имя игрока.
## Server auth code (requestServerSideAccess) → Firebase signInWithIdp playgames.google.com (FirebaseLink).

const SINGLETON: String = "GodotPlayGameServices"

var server_client_id: String = ""
var _plugin: Object
var _signed_in: bool = false
var _player_id: String = ""
var _display_name: String = ""


func platform() -> String:
	return "play_games"


func sign_in_silently() -> void:
	if not Engine.has_singleton(SINGLETON):
		sign_in_finished.emit.call_deferred(false)
		return
	if _plugin == null:
		_plugin = Engine.get_singleton(SINGLETON)
		_plugin.call(&"initialize")
		_plugin.connect(&"userAuthenticated", _on_authenticated)
		_plugin.connect(&"serverSideAccessRequested", _on_server_access)
		_plugin.connect(&"currentPlayerLoaded", _on_player_loaded)
	_plugin.call(&"isAuthenticated")


func sign_in_interactive() -> void:
	if _plugin == null:
		sign_in_silently()
	if _plugin != null:
		_plugin.call(&"signIn")


func is_signed_in() -> bool:
	return _signed_in


func get_player_id() -> String:
	return _player_id


func get_display_name() -> String:
	return _display_name


func request_auth_credential() -> void:
	if _plugin == null or not _signed_in or server_client_id.is_empty():
		auth_credential_ready.emit.call_deferred({})
		return
	_plugin.call(&"requestServerSideAccess", server_client_id, false)


func _on_authenticated(is_authenticated: bool) -> void:
	_signed_in = is_authenticated
	if is_authenticated:
		_plugin.call(&"loadCurrentPlayer", false)
	else:
		sign_in_finished.emit(false)


func _on_player_loaded(player_json: String) -> void:
	var parsed: Variant = JSON.parse_string(player_json)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		_player_id = str(d.get("playerId", ""))
		_display_name = str(d.get("displayName", ""))
	sign_in_finished.emit(_signed_in)


func _on_server_access(token: String) -> void:
	auth_credential_ready.emit({"provider": "playgames", "server_auth_code": token} if not token.is_empty() else {})
