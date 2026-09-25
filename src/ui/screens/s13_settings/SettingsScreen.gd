extends Control
## S13 · Настройки (DS S13): Primary нет — изменения применяются сразу. «Без белых вспышек» заменяет белый
## кадр Взрыва Света янтарём 40% и режет тряску; аккаунт — статус облака и гейм-центра; ID игрока внизу
## копируется долгим тапом.

const LONG_PRESS_MS: int = 600

var _press_ms: int = -1


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
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in 3:
		var option: Button = Button.new()
		option.theme_type_variation = &"ButtonSecondary"
		option.toggle_mode = true
		option.button_group = group
		option.text = [tr("Выкл"), tr("Обычные"), tr("Крупные")][i]
		option.button_pressed = settings.damage_numbers == i
		option.pressed.connect(GameManager.set_setting.bind(&"damage_numbers", i))
		numbers.add_child(option)
	column.add_child(numbers)

	column.add_child(UIKit.mono(tr("Аккаунт")))
	var cloud: String = {&"synced": tr("Синхронизировано"), &"syncing": tr("Синхронизация…"), &"offline": tr("Офлайн"), &"error": tr("Ошибка синхронизации")}.get(CloudManager.state, tr("Офлайн"))
	column.add_child(_info_row(tr("Облачное сохранение"), cloud))
	var services: String = GameServices.get_display_name() if GameServices.is_signed_in() else tr("Не подключено")
	var platform: String = "Game Center" if OS.get_name() == "iOS" else "Play Games"
	column.add_child(_info_row(platform, services))
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
