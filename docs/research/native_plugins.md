# Исследование: нативные плагины для V1 (Godot 4.7)

Дата: 2026-09-25. Данные — GitHub API и документация (ссылки внизу). Статус: **утверждено как D16** (`docs/decisions.md`), вариант А по iOS (минимум iOS 17). Рекламный SDK — **Appodeal со своей обёрткой (D17)**, см. раздел «Appodeal».

## Что нужно V1

| Потребность | Android | iOS |
|---|---|---|
| Покупки (IAP) | Google Play Billing | StoreKit 2 |
| Гейм-центр (вход, в V1.1 — лидерборды) | Google Play Games Services v2 | Game Center |
| Аналитика + краши | Firebase Analytics + Crashlytics | то же |
| Вход в Firebase через гейм-центр | Play Games → Firebase Auth | Game Center → Firebase Auth |
| Реклама (RV) + согласия | AdMob + UMP | AdMob + UMP + ATT |

## Кандидаты и проверка

| Плагин | Назначение | Последний релиз | Совместимость | Оценка |
|---|---|---|---|---|
| **godot-sdk-integrations/godot-google-play-billing** | Billing, Android | 3.3.0 · 2026-07-27 (Billing Library 9.1.0) | Godot 4.2+ | ✅ официальный, живой |
| **godot-sdk-integrations/godot-play-game-services** | Play Games v2, Android | v3.4.0 · 2026-07-20 | Godot 4.3+ | ✅ живой; есть `requestServerSideAccess(serverClientId)` → server auth code для Firebase |
| **migueldeicaza/GodotApplePlugins** | Game Center + StoreKit 2 + Sign in with Apple, iOS | сборка 2026-09-02 | GDExtension (SwiftGodot); **iOS 17.0+** | ✅ живой, один плагин закрывает и гейм-центр, и покупки; есть `fetch_items_for_identity_verification_signature` для Firebase |
| godot-sdk-integrations/godot-storekit2 | StoreKit 2, iOS | v0.2 · 2025-09-18 | — | ⚠ ранняя версия, 19★, релизов год нет |
| godot-sdk-integrations/godot-ios-plugins | GameCenter, InAppStore (StoreKit 1) | бинарники только для Godot 3.x (3.5, 2022) | для 4.x — собирать из исходников под каждую версию движка | ⚠ запасной вариант |
| **godot-x/firebase** | Firebase Core, Analytics, Crashlytics, Messaging | 3.1.0 · 2026-07-22 | Godot 4.5+ | ✅ живой, есть Consent Mode v2; **модуля Auth нет** |
| hyochan/godot-iap | IAP кросс-платформа | 1.2.9 | — | ❌ репозиторий в архиве |
| **poingstudios/godot-admob-plugin** | AdMob | v5.1.0 · 2026-09-13 | Godot 4.6+ | ✅ в проекте стоит **v4.3.1** → обновить до 5.x |
| `ios_plugins/godot_svc` (в проекте) | OAuth-браузер для godot-firebase | — | Godot 3.x | ❌ удалить (D14) |

## Вход в Firebase через гейм-центры

Нативного Auth-модуля в godot-x/firebase нет, поэтому авторизацию оставляем на REST (аддон `godot-firebase` уже умеет Anonymous) и дописываем два вызова Identity Toolkit REST:

- **Game Center → Firebase:** метод `accounts:signInWithGameCenter` существует в Identity Toolkit v1 (проверено по discovery-документу). Поля: `playerId`, `gamePlayerId`, `teamPlayerId`, `publicKeyUrl`, `signature`, `salt`, `timestamp`, `displayName` и **`idToken`** — через него вход привязывается к текущему анонимному пользователю. Подпись берём из `GodotApplePlugins` (`fetch_items_for_identity_verification_signature`). Схема рабочая, риск низкий.
- **Play Games → Firebase:** плагин отдаёт server auth code (`requestServerSideAccess`). Обмен кода на Firebase-вход через REST (`accounts:signInWithIdp`, провайдер `playgames.google.com`) в публичной REST-документации Firebase **не описан** — нужен прототип. Если не заработает, запасной путь — Cloud Function: обменивает server auth code на Google-токен, выпускает Firebase custom token → `signInWithCustomToken` (стандартная, документированная схема; добавляет серверную часть).

## Рекомендуемый стек

| Задача | Android | iOS |
|---|---|---|
| IAP | godot-google-play-billing 3.3 | GodotApplePlugins (StoreKit 2) |
| Гейм-центр | godot-play-game-services 3.4 | GodotApplePlugins (Game Center) |
| Analytics + Crashlytics | godot-x/firebase 3.1 | godot-x/firebase 3.1 |
| Firebase Auth | `godot-firebase` (REST): Anonymous + Play Games (прототип) | `godot-firebase` (REST): Anonymous + `signInWithGameCenter` |
| Firestore (облако) | `godot-firebase` (REST) | `godot-firebase` (REST) |
| Реклама | Appodeal — своя обёртка на Kotlin (D17) | Appodeal — своя обёртка на Swift/SwiftGodot (D17), + ATT |

Все выбранные плагины обновлялись в 2026 году и поддерживают Godot 4.5+, то есть 4.7 проекта. Совместимость каждого с 4.7 подтверждаем в прототипе (шаг 1 ниже).

## Главный риск: минимальная версия iOS

`GodotApplePlugins` требует **iOS 17+**. Эталонное устройство из Design System §08 — **iPhone 8**, а его последняя iOS — 16. Варианты:

- **А (рекомендую):** минимальная iOS 17, эталон производительности iOS — iPhone XR/XS (A12, самые слабые устройства с iOS 17). Один современный плагин на iOS, меньше интеграционной работы.
- **Б:** оставить iOS 16 и iPhone 8 → Game Center и покупки через `godot-ios-plugins` (собирать из исходников под Godot 4.7, InAppStore — это StoreKit 1) или через ранний `godot-storekit2`. Больше ручной работы и риска.

## Appodeal (проверено 2026-09-25)

Цель — «проще всего + максимальный доход за счёт выбора лучшей сети». Состояние плагинов под Godot 4:

| Плагин | Платформа | Последнее обновление | Оценка |
|---|---|---|---|
| Официальный от Appodeal | — | — | ❌ для Godot 4 нет |
| damnedpie/godot-appodeal | Android | SDK4.3.0rev1 · 2026-09-08 (Appodeal SDK 4.3.0, Godot 4.7.2) | ✅ живой, но один автор, 11★; API ConsentManager не проброшен |
| slyd4r/godot-appodeal-plugin (Asset Library «Appodeal Ads») | Android | 1.0.0 · 2026-06 | ⚠ только Android, первая версия |
| ferdouseO/godot-appodeal-android-plugin | Android | v1.0.1 · 2025-07 (SDK 3.8) | ⚠ отстаёт по SDK |
| DmitriiFeshchenko/godot-appodeal-ios-plugin | iOS | v2.0.0 · 2024-01 (SDK 3.2, эпоха Godot 3) | ❌ заброшен |
| virtualplaynl/godot-4-appodeal-editor-plugin | Android + iOS | 2024-04, «Work In Progress» | ❌ заброшен |

**Вывод: на iOS живого плагина Appodeal для Godot 4 нет.** Для Appodeal на iOS придётся писать и поддерживать свою обёртку над Appodeal iOS SDK (GDExtension через SwiftGodot, по образцу GodotApplePlugins) и обновлять её вместе с SDK. Это противоречит цели «проще всего».

Дополнительные риски Appodeal: SDK тянет свои сервисы аналитики/атрибуции (в т.ч. Firebase) — возможен конфликт версий с godot-x/firebase, проверять в прототипе; согласия (UMP/ATT) идут через ConsentManager Appodeal, который в Android-плагине не проброшен.

**Альтернатива с той же целью — AdMob-медиация** через уже стоящий в проекте плагин poing (обновить до 5.x): живой, обе платформы, в v5.1 синхронизированы адаптеры 15+ сетей медиации (AppLovin, Unity, ironSource, Meta, Mintegral и др.). Bidding в AdMob сам выбирает самую доходную сеть на каждый показ — то же, ради чего берут Appodeal. Минус: сети-партнёры подключаются вручную в кабинете AdMob (у Appodeal это готово «из коробки»).

Варианты:
- **А (рекомендую):** AdMob + медиация (bidding) через poing 5.x на обеих платформах.
- **Б:** Appodeal на обеих платформах: Android — damnedpie, iOS — своя обёртка (оценка: 1–2 недели на обёртку + поддержка при каждом обновлении SDK).
- **В:** Appodeal на Android + AdMob-медиация на iOS — два рекламных стека, двойная интеграция и отчётность.

## План проверки (прототип, до основных эпиков)

1. Пустой проект Godot 4.7 + все выбранные плагины → debug-сборки Android и iOS запускаются.
2. Play Billing и StoreKit 2: тестовая покупка расходуемого товара (license tester / sandbox).
3. Вход в Play Games и Game Center + привязка к анонимному Firebase-пользователю (для Play Games — проверить REST; при неудаче — Cloud Function).
4. Firebase Analytics: событие видно в DebugView; Crashlytics: тестовый краш виден в консоли.
5. Appodeal (своя обёртка): форма согласий ConsentManager, ATT на iOS, показ тестового Rewarded на обеих платформах; сборка без конфликтов Firebase-зависимостей Appodeal и godot-x/firebase.

## Источники

- https://github.com/godot-sdk-integrations/godot-google-play-billing
- https://github.com/godot-sdk-integrations/godot-play-game-services
- https://github.com/migueldeicaza/GodotApplePlugins
- https://github.com/godot-sdk-integrations/godot-storekit2
- https://github.com/godot-sdk-integrations/godot-ios-plugins
- https://github.com/godot-x/firebase
- https://github.com/poingstudios/godot-admob-plugin
- https://github.com/hyochan/godot-iap
- https://cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/signInWithGameCenter
- https://firebase.google.com/docs/reference/rest/auth
- https://github.com/damnedpie/godot-appodeal
- https://github.com/slyd4r/godot-appodeal-plugin
- https://github.com/DmitriiFeshchenko/godot-appodeal-ios-plugin
- https://github.com/virtualplaynl/godot-4-appodeal-editor-plugin
