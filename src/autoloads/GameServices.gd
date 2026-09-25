extends Node
## Фасад нативных гейм-центров (D13): Game Center (iOS), Play Games v2 (Android), иначе «не подключено».
## Отказ или ошибка входа не блокируют игру — работаем на анонимном Firebase-аккаунте.
## После входа CloudManager привязывает аккаунт гейм-центра к анонимному UID.

signal signed_in_changed(signed_in: bool)

const CREDENTIAL_TIMEOUT_S: float = 6.0

var backend: GameServicesBackend


func _ready() -> void:
	set_process(false)
	set_backend(_default_backend())


func set_backend(new_backend: GameServicesBackend) -> void:
	if backend != null and backend.sign_in_finished.is_connected(_on_sign_in_finished):
		backend.sign_in_finished.disconnect(_on_sign_in_finished)
	backend = new_backend
	backend.sign_in_finished.connect(_on_sign_in_finished)


func _default_backend() -> GameServicesBackend:
	if OS.get_name() == "iOS" and ClassDB.class_exists(GameCenterBackend.MANAGER_CLASS):
		return GameCenterBackend.new()
	if OS.get_name() == "Android" and Engine.has_singleton(PlayGamesBackend.SINGLETON):
		var play: PlayGamesBackend = PlayGamesBackend.new()
		play.server_client_id = str(ConfigDB.get_config("services").get("play_games_server_client_id", ""))
		return play
	return GameServicesBackend.new()


func platform() -> String:
	return backend.platform()


func sign_in_silently() -> void:
	backend.sign_in_silently()


## Кнопка «Подключить» в S13.
func sign_in_interactive() -> void:
	backend.sign_in_interactive()


func is_signed_in() -> bool:
	return backend.is_signed_in()


func get_player_id() -> String:
	return backend.get_player_id()


func get_display_name() -> String:
	return backend.get_display_name()


## Данные для входа в Firebase или {} (нет входа, ошибка, таймаут).
func request_auth_credential() -> Dictionary:
	if not is_signed_in():
		return {}
	var box: Array[Dictionary] = []
	var on_ready: Callable = func(credential: Dictionary) -> void: box.append(credential)
	backend.auth_credential_ready.connect(on_ready, CONNECT_ONE_SHOT)
	backend.request_auth_credential()
	var deadline: int = Time.get_ticks_msec() + int(CREDENTIAL_TIMEOUT_S * 1000.0)
	while box.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if box.is_empty():
		backend.auth_credential_ready.disconnect(on_ready)
		return {}
	return box[0]


func _on_sign_in_finished(success: bool) -> void:
	Telemetry.log_event(&"game_services_sign_in", {"platform": platform(), "result": success})
	signed_in_changed.emit(success)
