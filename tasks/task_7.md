# Task 7 · Монетизация, гейм-центры, облако, аналитика

## Обоснование

Legacy:
- `StoreManager.buy_item` — имитация (случайный фейл 10% + таймер 1.5 с), причём при фейле всё равно эмитит успех; реального биллинга нет; выдача покупок размазана по `MainMenu.gd` (с несуществующим `ITEM_BLUE_SKIN`) и `Shop.gd`.
- `AdManager` — рабочий AdMob (в V1 заменяется на Appodeal — D17), но один глобальный `reward_earned` без плейсмента: на него подписаны `MainMenu` (+50 искр), `UIControl` (revive), `SkillChoicePanel` (реролл), `WinPanel` (×2) — награда может уйти не туда.
- `CloudManager` — «фейковая» регистрация email/пароль с паролем в открытом виде в `user://secret_auth.cfg`; ручная упаковка REST-полей; синхронизирует только 4 поля; стратегия `max(sparks)` позволяет дюпать валюту.
- Аналитики нет вовсе (GDD п.8 требует Firebase Analytics).
- Лидерборд по `unlocked_level` (метрика, которой в V1 больше нет).

V1 (GDD п.5, DS S03/S08/S09/S10, Gear DS §03): 4 плейсмента RV + дополнительные RV-точки, IAP (стартер-пак с FOMO-таймером, 4 пакета Кристаллов; No Ads нет — D15), сундуки, честное правило «▶ = реклама», телеметрия с `screen_id`, облачный сейв всего профиля.

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
- [ ] API: `show_rewarded(placement: StringName) -> void`, `is_rewarded_ready(placement) -> bool`; результат только `EventBus.ad_reward_granted(placement)` / `ad_failed(placement)`. Каждый потребитель фильтрует **свой** плейсмент.
- [ ] Плейсменты (`ads.json`: лимиты, кулдауны):
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
- [ ] `ad_opportunity_shown(placement)` — при показе кнопки ▶; `ad_started`, `ad_completed`, `ad_failed` — телеметрия.
- [ ] Музыка приглушается на 60% во время RV (DS §06), игра на паузе через `TimeService`.
- [ ] Нет готовой рекламы → кнопка ▶ Disabled с причиной («Реклама недоступна»), без показа ошибки после тапа.
- [ ] Интерстишалов нет (D15): `AdManager` поддерживает только Rewarded; legacy `show_interstitial_ad()` и `INTERSTITIAL_ID` удалить.
- [ ] Бэкенд — **Appodeal, своя обёртка** (D17): `src/services/ads/IAdsBackend.gd`, `AppodealBackend.gd`, `MockAdsBackend.gd`; нативная часть — `android/plugins/appodeal/` (Kotlin, по образцу damnedpie/godot-appodeal) и `ios/plugins/appodeal/` (Swift/SwiftGodot, по образцу GodotApplePlugins). API обёртки: `initialize(app_key, consent)`, `load_rewarded()`, `is_rewarded_loaded()`, `show_rewarded(placement)`, сигналы `rewarded_loaded/shown/finished(reward)/closed/failed`.
- [ ] Удалить AdMob: `addons/admob`, `ios/plugins/poing-godot-admob*`, тестовые ID AdMob в `AdManager.gd`.
- [ ] App Key Appodeal по платформе из `ads.json`; тестовый режим — только в debug. Сети медиации подключаются в кабинете Appodeal.
- [ ] Согласия: Appodeal ConsentManager (GDPR) и ATT на iOS до инициализации рекламы; кнопка «Настройки конфиденциальности» в S13, если ConsentManager требует privacy options.
- [ ] Проверить отсутствие конфликтов Firebase-зависимостей Appodeal с godot-x/firebase (Android Gradle, iOS SPM/CocoaPods).

### 2. IAP: `StoreManager` + бэкенды
- [ ] Каталог `shop.json` (`ShopProductDef`): `starter_pack` (скин «Лунный» + 500 ◆ — D18; однократно, FOMO-таймер 24 ч от первого показа), `crystals_80` $0.99, `crystals_280` $2.99, `crystals_550` $4.99 «ХИТ» (+20%), `crystals_2600` $19.99. Цены в UI — **локализованные строки из стора**, не хардкод.
- [ ] `IStoreBackend`: `init()`, `query_products(ids)`, `purchase(sku)`, `acknowledge/finish(tx)`, `restore()`. Реализации: Google Play Billing (v6+), StoreKit 2; `MockStoreBackend` для редактора с управляемым исходом (успех/отмена/ошибка/pending).
- [ ] Поток: Crystal-кнопка → системный диалог оплаты → успех → **сначала** выдача и `SaveManager.flush()` + облако, **затем** acknowledge → шоу 1.5 с (кристаллы влетают в счётчик, экран пульсирует голубым, «хрустальный» аккорд, хаптика `success`) → тост.
- [ ] Идемпотентность: `purchases.receipts` хранит `transaction_id`; повторная доставка не выдаёт дважды. Незавершённые транзакции обрабатываются при старте.
- [ ] «Восстановить покупки» (S13) — скин из `starter_pack` (единственная нерасходуемая покупка).
- [ ] Серверная валидация чеков — вне V1 (зафиксировать риск), либо Cloud Function (решение до релиза).
- [ ] Траты ◆ внутри игры (revive 30 ◆, реролл 10 ◆, Премиум-сундук, скины ◆) — через `GameManager.spend(&"crystals", ...)`, без биллинга.

### 3. Магазин S10 (DS S10 + Gear DS §03)
- [ ] Фиксированный порядок блоков: **стартер-пак** (пока не куплен/не истёк; двухцветная рамка «золото → кристалл», живой Огонёк в новом цвете освещает карточку, таймер-бейдж) → **бесплатный дар ▶** (300 Искр, 1 раз в 8 ч) → **Сундуки** (Базовый: 500 Искр / ▶ «Бесплатно · N/3»; Премиум: 150 ◆ / ×10 · 1 200 ◆, кнопки цвета кристалла, «i» — шансы) → **матрица Кристаллов** (размер иконки растёт: от одного кристалла до друзы; $19.99 «сокровище»). Строки «Без рекламы» нет (D15).
- [ ] Обменника нет (D9): блок из макета S10 (5 000 Искр за 50 ◆) не реализуется, его место занимает Премиум-сундук.
- [ ] На вкладке Магазина Ember «В БОЙ» уменьшается до 62pt и не светится.
- [ ] Красная точка на вкладке — когда доступен бесплатный дар.

### 4. Дар дня S03 `DailyGiftService`
- [ ] 7 дней (`daily.json`): 500 Искр, … , день 4 — Шлем, день 6 — 30 ◆, день 7 — Эпик «Сундук Света».
- [ ] Серия прерывается при пропуске дня; строка «Серия прервётся, если пропустить день · до сброса N ч». День считается по локальной полуночи; защита от перевода часов — сравнение с серверным временем Firestore при наличии сети.
- [ ] Авто-показ при первом входе за день после S01; «Забрать» / «▶ ×2».

### 5. Гейм-центры и авторизация: `GameServices` (D13)
- [ ] `GameServices` — фасад с бэкендами: **Game Center** (iOS), **Google Play Games Services v2** (Android), `Mock` (редактор). API: `sign_in_silently()`, `is_signed_in() -> bool`, `get_player_id() -> String`, `get_display_name() -> String`, `get_auth_credential()` (для привязки к Firebase). В V1.1 сюда же добавятся лидерборды и достижения.
- [ ] Старт приложения (S01): тихий вход в гейм-центр. Play Games v2 входит автоматически; Game Center показывает системный баннер. Отказ или ошибка **не блокируют** игру — работаем на анонимном аккаунте.
- [ ] Firebase: **Anonymous Auth** при первом запуске → при успешном входе в гейм-центр аккаунт гейм-центра **привязывается** (link) к анонимному Firebase-аккаунту. Если аккаунт гейм-центра уже привязан к другому UID (переустановка, новое устройство) — вход в тот UID и слияние профилей по правилам `SaveManager.merge`.
- [ ] Строка «Аккаунт» в S13: статус Game Center / Play Games (имя игрока, «Не подключено» + кнопка «Подключить»).
- [ ] Миграция legacy-аккаунтов из `secret_auth.cfg`: один раз войти старым способом, перенести профиль в новый UID, удалить файл.
- [ ] Технический риск: REST-аддон `godot-firebase` может не поддерживать credential-провайдеры Game Center / Play Games. Проверить на этапе выбора плагинов; запасной вариант — нативный Firebase Auth SDK через плагин.

### 6. Облако: `CloudManager`
- [ ] Документ `users/{uid}`: `profile_json` (строка сериализованного `PlayerProfile`) + `updated_at`, `schema_version`. Не упаковывать поля вручную.
- [ ] Синк при старте (S01, таймаут 6 с → «Нет сети · играть офлайн»), после S09, после покупок и кат-сцен Маяка, при уходе в фон (debounce).
- [ ] Слияние — правила из task_1 §4 (`SaveManager.merge(local, remote)`): `max(beacon.level)`, объединение скинов и инвентаря по `uid`, `premium_pity` max, кошелёк и `equipped` — по `updated_at`. Юнит-тесты на конфликты.
- [ ] `EventBus.cloud_sync_state_changed` (`syncing|synced|offline|error`) → S13 «Синхронизировано · 2 мин назад».
- [ ] Firestore Security Rules: пользователь читает и пишет только свой документ.

### 7. Аналитика: `Telemetry` → Firebase Analytics
- [ ] Бэкенд — нативный плагин (REST-аддон `godot-firebase` аналитику не отправляет). Батчинг и оффлайн-очередь на стороне SDK.
- [ ] User properties: `install_ts`, `beacon_level`, `chapter`, `payer`, `equipped_skin`.
- [ ] События (GDD п.8 + DS §04 + Skills/Meta/Gear DS): `app_open`, `sync_timeout`, `screen_view (screen_id)`, `tab_open`, `run_started (chapter, skin, power)`, `run_ended (reason, time_s, level, kills, sparks)`, `chapter_cleared`, `level_up`, `skill_offered`, `skill_selected`, `skill_reroll`, `skill_maxed`, `revive_used (ad|crystal)`, `reward_multiplier (1|3)`, `daily_claimed`, `ad_opportunity_shown`, `ad_started/completed/failed`, `iap_started`, `iap_completed`, `iap_failed`, `beacon_deposit`, `beacon_tier`, `beacon_milestone`, `skin_unlocked`, `skin_equipped`, `gear_equip`, `game_services_sign_in (platform, result)`, `chest_opened`, `item_levelup`, `item_merged`, `item_dismantled`, `settings_changed`.
- [ ] Экономические события: `earn_virtual_currency` / `spend_virtual_currency` (стандартные имена Firebase) из `GameManager.grant/spend`.
- [ ] Словарь событий — `docs/analytics_events.md` (имя, параметры, типы, где эмитится); тест: все вызовы `Telemetry.log_event` используют имена из словаря.
- [ ] Debug-режим: `DebugTelemetryBackend` + debug-оверлей последних 20 событий.

### 8. Лидерборды — V1.1 (D10)
- [ ] В V1 не реализуются. Удалить `LeaderboardManager.gd`, `src/meta_loop/screens/base/*` и его Kenney-шрифт.
- [ ] Заготовка на V1.1: лидерборды гейм-центров (Game Center / Play Games) через `GameServices`; метрику выбрать позже.

### 9. Экономика: целостность
- [ ] Все начисления — через `GameManager.grant(currency, amount, reason)`; `reason` ∈ {`run`, `run_x3`, `daily`, `ad_gift`, `iap`, `chest`, `dismantle`, `merge_refund`, `beacon_reward`}.
- [ ] Защита от повторной выдачи RV-наград (идемпотентный `reward_token` на показ).
- [ ] Balance sheet: таблица источников/стоков в `docs/economy.md` (Маяк ≈ 74 000 Искр на главу, прокачка гира, сундуки) — ревью с геймдизайнером.

## Критерии приёмки

- [ ] Каждый из 8 RV-плейсментов выдаёт только свою награду; параллельные подписчики не срабатывают (тест с `MockAd`: показ `skill_reroll` не даёт revive/+50 Искр).
- [ ] Все RV-кнопки помечены ▶ и соблюдают лимиты (1/забег, 3/день, 1 раз в 8 ч).
- [ ] Тестовые покупки в Google Play (license testers) и StoreKit sandbox: 4 пакета и стартер-пак; повторная доставка/перезапуск во время покупки не дублирует и не теряет выдачу; «Восстановить покупки» возвращает скин стартер-пака.
- [ ] Цены в S10 — локализованные строки из стора.
- [ ] Шансы сундуков доступны по «i» до покупки.
- [ ] Новый игрок получает анонимный UID; вход в Game Center / Play Games происходит автоматически и привязывается к нему; переустановка + вход в тот же гейм-центр восстанавливает профиль; отказ от гейм-центра не блокирует игру; конфликт двух устройств разрешается по правилам без дюпа валюты (юнит-тесты `merge`).
- [ ] В DebugView Firebase Analytics видны все события из словаря с корректными параметрами за один полный цикл S01 → S05 → S06 → S08 → S09 → S02 → S10.
- [ ] `secret_auth.cfg` больше не создаётся; пароли не хранятся на устройстве.
