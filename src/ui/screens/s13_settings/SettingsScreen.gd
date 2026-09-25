extends Control
## S13 · Настройки (DS S13): Primary нет — изменения применяются сразу. «Без белых вспышек» заменяет белый
## кадр Взрыва Света янтарём 40% и режет тряску; аккаунт — статус облака и гейм-центра; ID игрока внизу
## копируется долгим тапом.

const LONG_PRESS_MS: int = 600

var _press_ms: int = -1
var _cloud_row: HBoxContainer
var _services_row: HBoxContainer
var _connect: GlowButton


func _ready() -> void:
	var column: VBoxContainer = UIKit.screen_root(self)
	var header: HBoxContainer = UIKit.hbox()
	column.add_child(header)
	header.add_child(UIKit.button("‹", GlowButton.Variant.QUIET, SceneRouter.go.bind(&"S02")))
	header.add_child(UIKit.mono(tr("Настройки")))
	var settings: PlayerProfile.Settings = GameManager.profile.settings

	column.add_child(UIKit.mono(tr("Звук и отклик")))
	column.add_child(_toggle_row(tr("Музыка"), &"music", settings.music))
	column.add_child(_toggle_row(tr("Звуки"), &"sfx", settings.sfx))
	column.add_child(_toggle_row(tr("Вибрация"), &"vibration", settings.vibration, tr("Удар при сборе топлива, тик на искрах")))

	column.add_child(UIKit.mono(tr("Комфорт")))
	column.add_child(_toggle_row(tr("Без белых вспышек"), &"no_flashes", settings.no_flashes, tr("Для светочувствительных игроков")))
	column.add_child(_toggle_row(tr("Тряска камеры"), &"camera_shake", settings.camera_shake))
	var numbers: HBoxContainer = UIKit.hbox(UITokens.S2)
	numbers.custom_minimum_size.y = 52
	numbers.add_child(UIKit.label(tr("Цифры урона"), &"body"))
	numbers.add_child(UIKit.spacer(false))
	var segmented: Segmented = Segmented.new(PackedStringArray([tr("Выкл"), tr("Обычные"), tr("Крупные")]), settings.damage_numbers)
	segmented.selected.connect(func(i: int) -> void: GameManager.set_setting(&"damage_numbers", i))
	numbers.add_child(segmented)
	column.add_child(numbers)

	column.add_child(UIKit.mono(tr("Аккаунт")))
	_cloud_row = _info_row(tr("Облачное сохранение"), "")
	column.add_child(_cloud_row)
	_services_row = _info_row(_platform_name(), "")
	column.add_child(_services_row)
	_connect = UIKit.button(tr("Подключить"), GlowButton.Variant.SECONDARY, GameServices.sign_in_interactive)
	_connect.size_flags_horizontal = Control.SIZE_SHRINK_END
	_services_row.add_child(_connect)
	if AdManager.backend.privacy_options_required():
		column.add_child(UIKit.button(tr("Настройки конфиденциальности"), GlowButton.Variant.QUIET, AdManager.backend.show_privacy_options))
	_refresh_account()
	EventBus.cloud_sync_state_changed.connect(_on_sync_state)
	GameServices.signed_in_changed.connect(_on_signed_in)
	var language: Button = Button.new()
	language.theme_type_variation = &"ButtonQuiet"
	language.alignment = HORIZONTAL_ALIGNMENT_LEFT
	language.text = tr("Язык: %s ›") % ("English" if TranslationServer.get_locale().begins_with("en") else "Русский")
	language.pressed.connect(_toggle_language)
	column.add_child(language)
	column.add_child(UIKit.button(tr("Восстановить покупки"), GlowButton.Variant.QUIET, StoreManager.restore_purchases))
	column.add_child(UIKit.spacer())
	var footer: Label = UIKit.mono("Glow in the Dark %s · ID %s" % [ProjectSettings.get_setting("application/config/version", "1.0.0"), GameManager.profile.device_id.left(4).to_upper()], UITokens.TEXT_DISABLED, HORIZONTAL_ALIGNMENT_CENTER)
	footer.mouse_filter = Control.MOUSE_FILTER_STOP
	footer.gui_input.connect(_on_footer_input)
	column.add_child(footer)


func _platform_name() -> String:
	match GameServices.platform():
		"game_center":
			return "Game Center"
		"play_games":
			return "Play Games"
	return "Play Games" if OS.get_name() == "Android" else "Game Center" # V1 — iOS (D19)


func _on_sync_state(_state: StringName) -> void:
	_refresh_account()


func _on_signed_in(_signed_in: bool) -> void:
	_refresh_account()


## «Синхронизировано · 2 мин назад» · имя игрока гейм-центра или «Не подключено» + «Подключить».
func _refresh_account() -> void:
	var cloud: String = {&"synced": tr("Синхронизировано"), &"syncing": tr("Синхронизация…"), &"offline": tr("Офлайн"), &"error": tr("Ошибка синхронизации")}.get(CloudManager.state, tr("Офлайн"))
	if CloudManager.state == &"synced" and CloudManager.last_synced_at > 0:
		cloud += " · " + ago_text(int(Time.get_unix_time_from_system()) - CloudManager.last_synced_at)
	(_cloud_row.get_child(1) as Label).text = cloud
	var signed_in: bool = GameServices.is_signed_in()
	(_services_row.get_child(1) as Label).text = GameServices.get_display_name() if signed_in else tr("Не подключено")
	_connect.visible = not signed_in and GameServices.platform() != "none"


static func ago_text(seconds: int) -> String:
	if seconds < 60:
		return TranslationServer.translate("только что")
	if seconds < 3600:
		return TranslationServer.translate("%d мин назад") % floori(seconds / 60.0)
	return TranslationServer.translate("%d ч назад") % floori(seconds / 3600.0)


func _toggle_row(title: String, key: StringName, value: bool, caption: String = "") -> Control:
	var row: HBoxContainer = UIKit.hbox(UITokens.S3)
	row.custom_minimum_size.y = 52
	var texts: VBoxContainer = UIKit.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UIKit.label(title, &"body"))
	if not caption.is_empty():
		texts.add_child(UIKit.label(caption, &"body_s", UITokens.TEXT_MUTED))
	row.add_child(texts)
	var toggle: ToggleSwitch = ToggleSwitch.new()
	toggle.set_on(value)
	toggle.toggled.connect(func(on: bool) -> void: GameManager.set_setting(key, on))
	row.add_child(toggle)
	return row


func _info_row(title: String, value: String) -> Control:
	var row: HBoxContainer = UIKit.hbox(UITokens.S3)
	row.custom_minimum_size.y = 44
	var t: Label = UIKit.label(title, &"body")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UIKit.label(value, &"body_s", UITokens.TEXT_MUTED))
	return row


func _toggle_language() -> void:
	var next: String = "ru" if TranslationServer.get_locale().begins_with("en") else "en"
	GameManager.set_setting(&"language", next)
	TranslationServer.set_locale(next)
	SceneRouter.go(&"S13")


func _on_footer_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	var released: bool = (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed)
	if pressed:
		_press_ms = Time.get_ticks_msec()
	elif released and _press_ms >= 0 and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		DisplayServer.clipboard_set(GameManager.profile.device_id)
		EventBus.toast_requested.emit(tr("ID скопирован"), &"copy")
		_press_ms = -1
