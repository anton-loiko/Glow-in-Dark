# Обёртка Appodeal (D17): контракт и статус

Своя тонкая обёртка Appodeal SDK. Наружу — только Rewarded Video (интерстишалов и баннеров нет, D15). GDScript-сторона — `src/services/ads/AppodealBackend.gd`; `AdManager` о SDK не знает.

## Контракт (одинаковый для Android и iOS)

| | Android (JNI-синглтон `GodotAppodeal`) | iOS (GDExtension-класс `AppodealPlugin`) |
|---|---|---|
| `initialize(app_key: String, testing: bool)` | ✅ | ⏳ |
| `is_rewarded_loaded() -> bool` | ✅ | ⏳ |
| `show_rewarded(placement: String)` | ✅ (UI-поток) | ⏳ |
| `show_privacy_options()`, `privacy_options_required() -> bool` | — (SDK показывает форму сам) | ⏳ |
| сигнал `initialized(errors: String)` | ✅ | ⏳ |
| сигналы `rewarded_loaded`, `rewarded_load_failed`, `rewarded_shown`, `rewarded_show_failed` | ✅ | ⏳ |
| сигнал `rewarded_finished(amount: float, currency: String)` — награда заработана | ✅ | ⏳ |
| сигнал `rewarded_closed(finished: bool)` — показ закрыт | ✅ | ⏳ |

Правило награды: `AppodealBackend` выдаёт награду на `rewarded_closed`, если был `rewarded_finished` или `finished = true`. Повторные колбэки отсекает `AdManager` (один показ — одна награда).

App Key берётся из `configs/ads.json → app_keys.android/ios`. Тестовый режим включается только в debug-сборке (`test_mode_in_debug`).

## Android — готово, собирается

- Исходники: `plugins/appodeal/android` (Kotlin, Godot Android plugin v2, AGP 8.13, Kotlin 2.4, minSdk 26).
- Сборка: `cd plugins/appodeal/android && ./gradlew installToAddon` → `addons/glow_appodeal/bin/GlowAppodeal.{debug,release}.aar`.
- Код компилируется против Appodeal SDK `core:4.3.0` и `org.godotengine:godot:4.7.2.stable`. SDK подключается `compileOnly`.
- При экспорте игры `addons/glow_appodeal/export_plugin.gd` добавляет AAR, Appodeal SDK, адаптеры из `addons/glow_appodeal/android_dependencies.txt` и Maven-репозиторий Appodeal. Все 16 координат проверены: POM отвечают 200. Для экспорта нужен Gradle build (Android Build Template).
- Согласия: Appodeal SDK 4.x сам показывает форму согласия (GDPR/UMP) во время `initialize()`. Результат для Firebase передаётся через `Telemetry.set_consent` — это будет проверено в прототипе на устройстве.
- Конфликт Firebase: адаптер `firebase:23.2.0.0` использует firebase-analytics 23.2.0, ту же версию, что godot-x/firebase 3.1. Итоговую сборку с обоими плагинами проверить в прототипе (шаг 5 плана `native_plugins.md`).

## iOS — следующий шаг

План: GDExtension на SwiftGodot по образцу GodotApplePlugins. Appodeal iOS SDK подключается через CocoaPods или SPM, а до `initialize` запрашивается ATT (`ATTrackingManager.requestTrackingAuthorization`). Нужны App Key Appodeal и тестовое устройство или симулятор с iOS 17+.

## Что нужно от владельца проекта

1. Аккаунт Appodeal и App Key для Android и iOS → `configs/ads.json`.
2. Список сетей медиации из кабинета Appodeal (правится `android_dependencies.txt`).
3. Firebase-проект игры (`google-services.json`, `GoogleService-Info.plist`) — для аналитики и облака.
