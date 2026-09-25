extends Node
## Точка входа: передаёт управление SceneRouter (S01 — сплэш/синхронизация).


func _ready() -> void:
	set_process(false)
	var language: String = GameManager.profile.settings.language
	if language.is_empty():
		language = "en" if OS.get_locale_language() == "en" else "ru"
	TranslationServer.set_locale(language)
	SceneRouter.go.call_deferred(&"S01")
