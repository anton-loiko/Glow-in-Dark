# Task 7 · Монетизация, гейм-центры, облако, аналитика

## Обоснование

Legacy:
- `StoreManager.buy_item` — имитация (случайный фейл 10% + таймер 1.5 с), причём при фейле всё равно эмитит успех; реального биллинга нет; выдача покупок размазана по `MainMenu.gd` (с несуществующим `ITEM_BLUE_SKIN`) и `Shop.gd`.
- `AdManager` — рабочий AdMob (в V1 заменяется на Appodeal — D17), но один глобальный `reward_earned` без плейсмента: на него подписаны `MainMenu` (+50 искр), `UIControl` (revive), `SkillChoicePanel` (реролл), `WinPanel` (×2) — награда может уйти не туда.
- `CloudManager` — «фейковая» регистрация email/пароль с паролем в открытом виде в `user://secret_auth.cfg`; ручная упаковка REST-полей; синхронизирует только 4 поля; стратегия `max(sparks)` позволяет дюпать валюту.
- Аналитики нет вовсе (GDD п.8 требует Firebase Analytics).
- Лидерборд по `unlocked_level` (метрика, которой в V1 больше нет).

V1 (GDD п.5, DS S03/S08/S09/S10, Gear DS §03): 4 плейсмента RV + дополнительные RV-точки, IAP (стартер-пак с FOMO-таймером, 4 пакета Кристаллов; No Ads нет — D15), сундуки, честное правило «▶ = реклама», телеметрия с `screen_id`, облачный сейв всего профиля.

## Статус (2026-09-25)

Сделано (GDScript-слой полностью, нативные адаптеры по реальным API плагинов):
- **Реклама.** `AdManager` с лимитами по плейсментам из `ads.json` (1 за забег по `run_id`, N в день, кулдаун 8 ч, общий лимит `hub_sparks` ↔ `shop_free_gift`). Защита от повторного колбэка (один показ — одна награда), приглушение музыки на 60%, `ad_opportunity_shown`. `UIKit.ad_button` / `GlowButton.ad_placement` сами становятся Disabled с причиной («Реклама недоступна», «Через 7 ч 12 мин», «Лимит исчерпан»). В релизе без плагина — «реклама недоступна», а не мок.
- **Appodeal (D17).** Своя обёртка для Android: `plugins/appodeal/android` (Kotlin, Godot plugin v2). **Собирается** против Appodeal SDK 4.3.0 и Godot 4.7.2, AAR лежит в `addons/glow_appodeal/bin`. Экспорт-плагин подключает SDK и 15 адаптеров (все координаты проверены) из `android_dependencies.txt`. `AppodealBackend.gd` — сторона GDScript. Контракт — `docs/research/appodeal_wrapper.md`. AdMob, `godot_svc` и ветка GodotSvc в auth-аддоне удалены.
- **Покупки.** `StoreManager`: цены только из стора (`products_updated` → S10), поток «выдача → чек → критическая запись → облако → finish», идемпотентность по transaction_id, отложенные платежи (PENDING), «Восстановить покупки» только для нерасходуемого (скин Лунного без повторных ◆). Бэкенды: `GooglePlayBillingBackend` (godot-google-play-billing 3.x: consume/acknowledge, незавершённые покупки при старте) и `AppStoreBackend` (StoreKit 2 из GodotApplePlugins), сверены с исходниками плагинов. Шоу покупки 1.5 с + тост.
- **S10.** Карточка стартер-пака: рамка «золото → кристалл», Лунный Огонёк, FOMO-таймер 24 ч от первого показа, скрывается по истечении. Иконки пакетов растут с номиналом. Красная точка на вкладке — когда доступен дар.
- **Гейм-центры и авторизация.** `GameServices` с бэкендами `GameCenterBackend` (GodotApplePlugins, подпись identity verification) и `PlayGamesBackend` (godot-play-game-services 3.x, server auth code). `CloudManager` привязывает гейм-центр к анонимному UID через Identity Toolkit REST (`signInWithGameCenter`; Play Games — `signInWithIdp`, запасной путь — Cloud Function из `services.json`). При другом UID входим в него и сливаем профили. Одноразовая миграция `secret_auth.cfg` (Искры по максимуму, скины объединяются, файл удаляется).
- **Облако.** Синк при старте с таймаутом, после наград забега, тиров Маяка, покупок и ухода в фон (дебаунс 3 с). S13: «Синхронизировано · N мин назад», статус гейм-центра и «Подключить», «Настройки конфиденциальности» при необходимости. `firebase/firestore.rules` — только свой документ, только 3 поля. `ProfileMerge` дополнен: лимиты рекламы и таймер стартер-пака сливаются по максимуму, слоты экипировки объединяются.
- **Аналитика.** `FirebaseAnalyticsBackend` (godot-x/firebase 3.1): очередь до инициализации, лимиты Firebase, согласие Consent Mode v2 (`Telemetry.set_consent`), Crashlytics. User properties, `tab_open`. Словарь `docs/analytics_events.md` с тестом «все события в словаре». Debug-оверлей последних 20 событий (F9).
- **Экономика.** `GameManager.REASONS` с проверкой в debug и тестом. `docs/economy.md` — balance sheet.
- Попутно из task_6: предмет из Дара дня (день 4 — Шлем) теперь выдаётся в инвентарь при входе в хаб. Строка S03 «до сброса N ч».

Проверки: 133 скрипта в строгом режиме, 114 тестов (+21: изоляция плейсментов, лимиты per_run / per_day / cooldown / shared, повторный колбэк, идемпотентность покупок, восстановление без ◆, отмена, миграция счётчиков, слияние лимитов и таймера, отсутствие дюпа валюты между устройствами, legacy-облако, битый облачный снимок, словарь событий, `reason`), рендер S10 / S13 / шоу покупки.

Что осталось (нужны аккаунты или устройства):
- **iOS-обёртка Appodeal** (SwiftGodot + ATT) — не написана; нужны App Key и iOS 17+ для проверки.
- Прототип на устройствах (шаги 1–5 `native_plugins.md`): тестовые покупки (license testers / sandbox), вход Game Center / Play Games и привязка к Firebase (Play Games через `signInWithIdp` не подтверждён — возможно, понадобится Cloud Function), DebugView Firebase, форма согласий Appodeal.
- Firebase-проект игры (`google-services.json`, `GoogleService-Info.plist`, `.env`) — облако выключено флагом `services.json`.
- godot-x/firebase не пробрасывает `setUserProperty` — нужен форк или PR (пока свойства уходят в Crashlytics keys).
- Серверная валидация чеков — решение до релиза (`docs/economy.md`).
- **B5 (баланс):** прокачка Эпического и Легендарного гира стоит миллионы Искр — вопрос геймдизайнеру.

## Затронутые файлы

**Переписать:**
- `src/autoloads/StoreManager.gd` — каталог + адаптеры бэкендов + выдача.
- `src/autoloads/AdManager.gd` — API по плейсментам.
- `src/autoloads/CloudManager.gd` — анонимная авторизация, документ профиля, слияние.
- `src/autoloads/Telemetry.gd` (каркас из task_1) — бэкенд Firebase Analytics.
- `src/autoloads/GameServices.gd` (каркас из task_1) — Game Center / Google Play Games (D13).

**Удалить:**
- `user://secret_auth.cfg` (миграция: однократный логин старым способом → привязка к анонимному аккаунту → удаление файла).
- `src/autoloads/LeaderboardManager.gd` и экран `src/meta_loop/screens/base/*` — лидерборды в V1.1 (D10).
- `ios_plugins/godot_svc/` и константа `_INAPP_PLUGIN = "GodotSvc"` в `addons/godot-firebase/auth/auth.gd` — OAuth через браузер не используется, плагин собран под Godot 3.x (D14).
- Обработчики покупок/наград в `MainMenu.gd`, `Shop.gd`, `WinPanel.gd`, `LosePanel.gd`, `SkillChoicePanel.gd` (удаляются вместе со сценами в task_5).

**Создать:**
- `src/services/store/IStoreBackend.gd`, `MockStoreBackend.gd`, `GooglePlayBillingBackend.gd`, `AppStoreBackend.gd`.
- `src/services/ads/AdPlacement.gd` (enum/константы плейсментов), `AdRequest.gd`.
- `src/services/analytics/FirebaseAnalyticsBackend.gd`, `DebugTelemetryBackend.gd`.
- `src/meta/daily/DailyGiftService.gd` (S03 + бесплатный дар магазина).
- `src/meta/offers/StarterPackService.gd`.
- `src/ui/screens/s10_shop/*`, `src/ui/components/{shop_offer_card,crystal_pack_card,starter_pack_card}/*`.
- `configs/shop.json`, `configs/ads.json`, `configs/daily.json`.
- `src/services/game_services/IGameServicesBackend.gd`, `GameCenterBackend.gd`, `PlayGamesBackend.gd`, `MockGameServicesBackend.gd`.
- Нативные плагины в `android/` и `ios/plugins/`: биллинг, Firebase Analytics/Crashlytics, Game Center, Play Games Services (выбор — после исследования, см. `tasks/README.md`).

## Чеклист реализации

### 1. Реклама: `AdManager` по плейсментам
- [x] API: `show_rewarded(placement: StringName) -> void`, `is_rewarded_ready(placement) -> bool`; результат только `EventBus.ad_reward_granted(placement)` / `ad_failed(placement)`. Каждый потребитель фильтрует **свой** плейсмент.
- [x] Плейсменты (`ads.json`: лимиты, кулдауны):
  | id | Где | Награда | Лимит |
  |---|---|---|---|
  | `revive` (GDD 1) | S08 | +50% света, Взрыв, 2 с неуязв. | 1 за забег |
  | `run_x3` (GDD 2) | S09 | Искры забега ×3 | 1 за забег |
  | `skill_reroll` (GDD 3) | S06 | 2-й реролл | 1 за забег |
  | `skill_take_all` | S06 | «Взять все три» | 1 за забег |
  | `daily_x2` (GDD 4) | S03 | ×2 дар дня | 1/день |
  | `shop_free_gift` (GDD 4) | S10 | 300 Искр | 1 раз в 8 ч |
  | `basic_chest` | S10 | Базовый сундук | 3/день |
  | `hub_sparks` | S02 (Disabled CTA) | +300 Искр (= дар) | общий с `shop_free_gift` |
- [x] `ad_opportunity_shown(placement)` — при показе кнопки ▶; `ad_started`, `ad_completed`, `ad_failed` — телеметрия.
- [x] Музыка приглушается на 60% во время RV (DS §06), игра на паузе через `TimeService`.
- [x] Нет готовой рекламы → кнопка ▶ Disabled с причиной («Реклама недоступна»), без показа ошибки после тапа.
- [x] Интерстишалов нет (D15): `AdManager` поддерживает только Rewarded; legacy `show_interstitial_ad()` и `INTERSTITIAL_ID` удалить.
- [ ] Бэкенд — **Appodeal, своя обёртка** (D17): `src/services/ads/IAdsBackend.gd`, `AppodealBackend.gd`, `MockAdsBackend.gd`; нативная часть — `android/plugins/appodeal/` (Kotlin, по образцу damnedpie/godot-appodeal) и `ios/plugins/appodeal/` (Swift/SwiftGodot, по образцу GodotApplePlugins). API обёртки: `initialize(app_key, consent)`, `load_rewarded()`, `is_rewarded_loaded()`, `show_rewarded(placement)`, сигналы `rewarded_loaded/shown/finished(reward)/closed/failed`.
- [x] Удалить AdMob: `addons/admob`, `ios/plugins/poing-godot-admob*`, тестовые ID AdMob в `AdManager.gd`.
- [x] App Key Appodeal по платформе из `ads.json`; тестовый режим — только в debug. Сети медиации подключаются в кабинете Appodeal.
- [ ] Согласия: Appodeal ConsentManager (GDPR) и ATT на iOS до инициализации рекламы; кнопка «Настройки конфиденциальности» в S13, если ConsentManager требует privacy options.
- [ ] Проверить отсутствие конфликтов Firebase-зависимостей Appodeal с godot-x/firebase (Android Gradle, iOS SPM/CocoaPods).

### 2. IAP: `StoreManager` + бэкенды
- [x] Каталог `shop.json` (`ShopProductDef`): `starter_pack` (скин «Лунный» + 500 ◆ — D18; однократно, FOMO-таймер 24 ч от первого показа), `crystals_80` $0.99, `crystals_280` $2.99, `crystals_550` $4.99 «ХИТ» (+20%), `crystals_2600` $19.99. Цены в UI — **локализованные строки из стора**, не хардкод.
- [x] `IStoreBackend`: `init()`, `query_products(ids)`, `purchase(sku)`, `acknowledge/finish(tx)`, `restore()`. Реализации: Google Play Billing (v6+), StoreKit 2; `MockStoreBackend` для редактора с управляемым исходом (успех/отмена/ошибка/pending).
- [x] Поток: Crystal-кнопка → системный диалог оплаты → успех → **сначала** выдача и `SaveManager.flush()` + облако, **затем** acknowledge → шоу 1.5 с (кристаллы влетают в счётчик, экран пульсирует голубым, «хрустальный» аккорд, хаптика `success`) → тост.
- [x] Идемпотентность: `purchases.receipts` хранит `transaction_id`; повторная доставка не выдаёт дважды. Незавершённые транзакции обрабатываются при старте.
- [x] «Восстановить покупки» (S13) — скин из `starter_pack` (единственная нерасходуемая покупка).
- [ ] Серверная валидация чеков — вне V1 (зафиксировать риск), либо Cloud Function (решение до релиза).
- [x] Траты ◆ внутри игры (revive 30 ◆, реролл 10 ◆, Премиум-сундук, скины ◆) — через `GameManager.spend(&"crystals", ...)`, без биллинга.

### 3. Магазин S10 (DS S10 + Gear DS §03)
- [x] Фиксированный порядок блоков: **стартер-пак** (пока не куплен/не истёк; двухцветная рамка «золото → кристалл», живой Огонёк в новом цвете освещает карточку, таймер-бейдж) → **бесплатный дар ▶** (300 Искр, 1 раз в 8 ч) → **Сундуки** (Базовый: 500 Искр / ▶ «Бесплатно · N/3»; Премиум: 150 ◆ / ×10 · 1 200 ◆, кнопки цвета кристалла, «i» — шансы) → **матрица Кристаллов** (размер иконки растёт: от одного кристалла до друзы; $19.99 «сокровище»). Строки «Без рекламы» нет (D15).
- [x] Обменника нет (D9): блок из макета S10 (5 000 Искр за 50 ◆) не реализуется, его место занимает Премиум-сундук.
- [x] На вкладке Магазина Ember «В БОЙ» уменьшается до 62pt и не светится.
- [x] Красная точка на вкладке — когда доступен бесплатный дар.

### 4. Дар дня S03 `DailyGiftService`
- [x] 7 дней (`daily.json`): 500 Искр, … , день 4 — Шлем, день 6 — 30 ◆, день 7 — Эпик «Сундук Света».
- [ ] Серия прерывается при пропуске дня; строка «Серия прервётся, если пропустить день · до сброса N ч». День считается по локальной полуночи; защита от перевода часов — сравнение с серверным временем Firestore при наличии сети.
- [x] Авто-показ при первом входе за день после S01; «Забрать» / «▶ ×2».

### 5. Гейм-центры и авторизация: `GameServices` (D13)
- [x] `GameServices` — фасад с бэкендами: **Game Center** (iOS), **Google Play Games Services v2** (Android), `Mock` (редактор). API: `sign_in_silently()`, `is_signed_in() -> bool`, `get_player_id() -> String`, `get_display_name() -> String`, `get_auth_credential()` (для привязки к Firebase). В V1.1 сюда же добавятся лидерборды и достижения.
- [x] Старт приложения (S01): тихий вход в гейм-центр. Play Games v2 входит автоматически; Game Center показывает системный баннер. Отказ или ошибка **не блокируют** игру — работаем на анонимном аккаунте.
- [ ] Firebase: **Anonymous Auth** при первом запуске → при успешном входе в гейм-центр аккаунт гейм-центра **привязывается** (link) к анонимному Firebase-аккаунту. Если аккаунт гейм-центра уже привязан к другому UID (переустановка, новое устройство) — вход в тот UID и слияние профилей по правилам `SaveManager.merge`.
- [x] Строка «Аккаунт» в S13: статус Game Center / Play Games (имя игрока, «Не подключено» + кнопка «Подключить»).
- [x] Миграция legacy-аккаунтов из `secret_auth.cfg`: один раз войти старым способом, перенести профиль в новый UID, удалить файл.
- [ ] Технический риск: REST-аддон `godot-firebase` может не поддерживать credential-провайдеры Game Center / Play Games. Проверить на этапе выбора плагинов; запасной вариант — нативный Firebase Auth SDK через плагин.

### 6. Облако: `CloudManager`
- [x] Документ `users/{uid}`: `profile_json` (строка сериализованного `PlayerProfile`) + `updated_at`, `schema_version`. Не упаковывать поля вручную.
- [x] Синк при старте (S01, таймаут 6 с → «Нет сети · играть офлайн»), после S09, после покупок и кат-сцен Маяка, при уходе в фон (debounce).
- [x] Слияние — правила из task_1 §4 (`SaveManager.merge(local, remote)`): `max(beacon.level)`, объединение скинов и инвентаря по `uid`, `premium_pity` max, кошелёк и `equipped` — по `updated_at`. Юнит-тесты на конфликты.
- [x] `EventBus.cloud_sync_state_changed` (`syncing|synced|offline|error`) → S13 «Синхронизировано · 2 мин назад».
- [x] Firestore Security Rules: пользователь читает и пишет только свой документ.

### 7. Аналитика: `Telemetry` → Firebase Analytics
- [ ] Бэкенд — нативный плагин (REST-аддон `godot-firebase` аналитику не отправляет). Батчинг и оффлайн-очередь на стороне SDK.
- [ ] User properties: `install_ts`, `beacon_level`, `chapter`, `payer`, `equipped_skin`.
- [ ] События (GDD п.8 + DS §04 + Skills/Meta/Gear DS): `app_open`, `sync_timeout`, `screen_view (screen_id)`, `tab_open`, `run_started (chapter, skin, power)`, `run_ended (reason, time_s, level, kills, sparks)`, `chapter_cleared`, `level_up`, `skill_offered`, `skill_selected`, `skill_reroll`, `skill_maxed`, `revive_used (ad|crystal)`, `reward_multiplier (1|3)`, `daily_claimed`, `ad_opportunity_shown`, `ad_started/completed/failed`, `iap_started`, `iap_completed`, `iap_failed`, `beacon_deposit`, `beacon_tier`, `beacon_milestone`, `skin_unlocked`, `skin_equipped`, `gear_equip`, `game_services_sign_in (platform, result)`, `chest_opened`, `item_levelup`, `item_merged`, `item_dismantled`, `settings_changed`.
- [x] Экономические события: `earn_virtual_currency` / `spend_virtual_currency` (стандартные имена Firebase) из `GameManager.grant/spend`.
- [x] Словарь событий — `docs/analytics_events.md` (имя, параметры, типы, где эмитится); тест: все вызовы `Telemetry.log_event` используют имена из словаря.
- [x] Debug-режим: `DebugTelemetryBackend` + debug-оверлей последних 20 событий.

### 8. Лидерборды — V1.1 (D10)
- [x] В V1 не реализуются. Удалить `LeaderboardManager.gd`, `src/meta_loop/screens/base/*` и его Kenney-шрифт.
- [ ] Заготовка на V1.1: лидерборды гейм-центров (Game Center / Play Games) через `GameServices`; метрику выбрать позже.

### 9. Экономика: целостность
- [x] Все начисления — через `GameManager.grant(currency, amount, reason)`; `reason` ∈ {`run`, `run_x3`, `daily`, `ad_gift`, `iap`, `chest`, `dismantle`, `merge_refund`, `beacon_reward`}.
- [x] Защита от повторной выдачи RV-наград (идемпотентный `reward_token` на показ).
- [x] Balance sheet: таблица источников/стоков в `docs/economy.md` (Маяк ≈ 74 000 Искр на главу, прокачка гира, сундуки) — ревью с геймдизайнером.

## Критерии приёмки

- [x] Каждый из 8 RV-плейсментов выдаёт только свою награду; параллельные подписчики не срабатывают (тест с `MockAd`: показ `skill_reroll` не даёт revive/+50 Искр).
- [x] Все RV-кнопки помечены ▶ и соблюдают лимиты (1/забег, 3/день, 1 раз в 8 ч).
- [ ] Тестовые покупки в Google Play (license testers) и StoreKit sandbox: 4 пакета и стартер-пак; повторная доставка/перезапуск во время покупки не дублирует и не теряет выдачу; «Восстановить покупки» возвращает скин стартер-пака.
- [ ] Цены в S10 — локализованные строки из стора.
- [x] Шансы сундуков доступны по «i» до покупки.
- [ ] Новый игрок получает анонимный UID; вход в Game Center / Play Games происходит автоматически и привязывается к нему; переустановка + вход в тот же гейм-центр восстанавливает профиль; отказ от гейм-центра не блокирует игру; конфликт двух устройств разрешается по правилам без дюпа валюты (юнит-тесты `merge`).
- [ ] В DebugView Firebase Analytics видны все события из словаря с корректными параметрами за один полный цикл S01 → S05 → S06 → S08 → S09 → S02 → S10.
- [x] `secret_auth.cfg` больше не создаётся; пароли не хранятся на устройстве.
