# Task 1 · Создание / переработка архитектуры

## Статус (2026-09-25)

Реализовано, кроме двух ручных проверок в критериях приёмки. Проверки: `tools/run_tests.sh` —
строгая компиляция 43 скриптов (предупреждения как ошибки) и 31 юнит-тест gdUnit4, все зелёные.

Отличия от плана:
- Legacy-сцены MVP перенесены в `legacy/` (папка исключена из проекта через `.gdignore`) — образец для task_2/task_5. Главная сцена — `src/app/Boot.tscn`, экраны S01–S17 пока показываются заглушкой `ScreenStub` с переходами из DS §04.
- Аддон `virtual_joystick` убран в `legacy/`: в Godot 4.7 появился встроенный `VirtualJoystick` (конфликт имён). Джойстик в task_2 — на встроенном узле.
- Предупреждения `unsafe_cast` и `unsafe_call_argument` не включены: они срабатывают на каждое чтение JSON. Включены `untyped_declaration`, `inferred_declaration`, `unsafe_property_access`, `unsafe_method_access`.
- Клавиатурные действия (`move_*`, `pause`, `ui_back`) есть во всех сборках — на мобильных они безвредны.
- Трата и начисление Кристаллов сохраняются сразу, даже во время забега (`SaveManager.request_save(true)`), чтобы реальная ценность не терялась; Искры — по правилу «не писать во время забега».
- `LeaderboardManager` удалён (D10); `AdManager`, `StoreManager`, `GameServices` работают на мок-бэкендах до task_7.
- Известная утечка при выходе (`Timer` в `addons/godot-firebase/auth/auth.gd:55`) — в аддоне, не в нашем коде.

## Обоснование

Legacy-код держится на прямых ссылках между узлами: `LevelRoot` вручную связывает `Player` с `UIControl`, `Exit` ищет UI через `find_child`, `SkillChoicePanel` берёт `get_parent().get_node("UIControl")`, игровые сущности читают `GameManager.active_skills`, а на `AdManager.reward_earned` подписаны четыре экрана сразу. Состояние забега (run) смешано с профилем (meta) в `GameManager`, сохранение (`ConfigFile`) пишется на каждую искру, баланс зашит константами в скриптах.

Цель эпика — каркас, на который лягут эпики 2–8:
- **Слой данных** (конфиги JSON + типизированные `Resource`-определения): баланс меняется без правки кода.
- **Слой сервисов** (автолоады): профиль, сейв, экономика, навыки, пулы, роутинг экранов, время.
- **Слой забега** (`RunContext` — не автолоад, живёт в сцене забега и умирает вместе с ней).
- **Слой представления** (UI) общается с остальными только через `EventBus` (факты) и публичные API сервисов (команды).

Правило связности: **геймплей никогда не знает о UI, UI никогда не трогает узлы геймплея.** Геймплей публикует факты (`enemy_killed`, `player_light_changed`), UI подписывается. UI отправляет намерения через методы сервисов (`GameManager.request_revive(...)`), а не напрямую в узлы.

## Затронутые файлы

**Изменить:**
- `project.godot` — порядок и состав автолоадов, вьюпорт, input map, слои физики (см. шаг 1).
- `src/autoloads/EventBus.gd` — полный каталог типизированных сигналов.
- `src/autoloads/GameManager.gd` — профиль игрока, экономика, жизненный цикл забега (без сериализации).
- `src/autoloads/SkillsManager.gd` — каркас реестра навыков (логика пула — в task_4).
- `src/autoloads/DamagePool.gd` — общий `ObjectPool` + пул цифр урона.
- `src/autoloads/StoreManager.gd` — интерфейс каталога и покупок (биллинг — в task_7).
- `src/autoloads/CloudManager.gd` — работает только через `SaveManager` (снимок профиля), без знания полей.
- `src/autoloads/AudioManager.gd` — разделить на `AudioManager` (музыка/SFX-пул) и `FeedbackManager` (хаптика) — каркас.

**Удалить (после миграции):**
- `src/autoloads/GameBalanceManager.gd` → заменяется `ConfigDB` + `configs/*.json`.

**Создать:**
- `src/autoloads/ConfigDB.gd` — загрузка и валидация `configs/*.json`.
- `src/autoloads/SaveManager.gd` — JSON-сейв, версии, миграции, атомарная запись, debounce.
- `src/autoloads/SceneRouter.gd` — навигация по экранам S01–S17, модалы, Android «назад».
- `src/autoloads/TimeService.gd` — hit-stop, пауза мира, unscaled-время для UI.
- `src/autoloads/Telemetry.gd` — фасад аналитики (реализация бэкенда — task_7).
- `src/autoloads/GameServices.gd` — фасад нативных гейм-центров: Game Center / Google Play Games (реализация — task_7, D13).
- `src/core/pool/ObjectPool.gd` — универсальный пул узлов.
- `src/core/run/RunContext.gd` — состояние одного забега.
- `src/core/stats/StatBlock.gd`, `src/core/stats/StatsResolver.gd` — сборка статов Огонька из всех источников.
- `src/data/defs/*.gd` — классы `Resource`: `SkillDef`, `EnemyDef`, `GearItemDef`, `SkinDef`, `BeaconTierDef`, `ChapterDef`, `ShopProductDef`.
- `src/data/save/PlayerProfile.gd` — типизированная модель профиля + `to_dict()/from_dict()`.
- `configs/balance.json`, `configs/skills_config.json`, `configs/enemies.json`, `configs/waves.json`, `configs/beacon_config.json`, `configs/gear_config.json`, `configs/chests.json`, `configs/shop.json`, `configs/chapters.json` (каркасы, значения заполняют task_2–7).
- `tests/` — юнит-тесты на gdUnit4 (D11), `addons/gdUnit4`.

## Чеклист реализации

### 1. Фундамент проекта
- [x] `project.godot`: `display/window/size/viewport_width=390`, `viewport_height=844`, `stretch/mode="canvas_items"`, `aspect="expand"` (макеты DS 390×844 в масштабе 1:1). Удалить `window_width_override`/`height_override` (оставить только для десктоп-отладки через feature tag).
- [x] Удалить мусор: `editor/movie_writer/movie_file` указывает на чужой проект `mc_game`; `3d/physics_engine="Jolt Physics"` не нужен в 2D.
- [x] Слои физики 2D: `1 world`, `2 player`, `3 enemy`, `4 enemy_hitbox`, `5 pickup`, `6 player_light_area`, `7 projectile_enemy`. Задать имена в `layer_names/2d_physics/*`.
- [x] Input map: `move` (вектор от плавающего джойстика), `pause`, `ui_back`. Клавиатура — только под feature `editor`.
- [x] Структура каталогов: `src/autoloads`, `src/core/{pool,run,stats,fsm}`, `src/data/{defs,save}`, `src/gameplay/...`, `src/ui/...`, `configs/`, `tests/`.

### 2. EventBus — каталог сигналов
- [x] Переписать `EventBus.gd` с типизированными сигналами, сгруппированными по доменам. Сигналы — **только факты в прошедшем времени**; никаких ссылок на узлы UI в аргументах.
  - Забег: `run_started(run_id: String, chapter_id: int)`, `run_paused(reason: StringName)`, `run_resumed`, `run_ended(result: RunResult)`, `chapter_timer_tick(elapsed_s: float)`, `wave_phase_changed(phase: StringName)`.
  - Игрок: `player_light_changed(current: float, max_value: float)`, `player_damaged(amount: float, source: StringName)`, `player_light_depleted`, `player_revived(source: StringName)`, `fuel_collected(amount: float, world_pos: Vector2)`, `light_burst_triggered(world_pos: Vector2)`.
  - Бой: `enemy_spawned(archetype: StringName)`, `enemy_killed(archetype: StringName, world_pos: Vector2, is_elite: bool)`, `damage_dealt(amount: int, world_pos: Vector2, style: int)`.
  - Прогрессия забега: `run_sparks_changed(total: int, delta: int)`, `xp_changed(current: int, needed: int, level: int)`, `level_up_ready(level: int, queued: int)`, `skill_offer_presented(offer: Array)`, `skill_selected(skill_id: StringName, level_to: int)`.
  - Экономика/мета: `currency_changed(currency: StringName, total: int, delta: int)`, `beacon_level_changed(chapter_id: int, level: int)`, `beacon_tier_reached(chapter_id: int, tier: int)`, `skin_unlocked(skin_id: StringName)`, `skin_equipped(skin_id: StringName)`, `gear_changed(slot: StringName)`, `inventory_changed`.
  - Монетизация: `ad_reward_granted(placement: StringName)`, `ad_failed(placement: StringName)`, `purchase_completed(product_id: StringName)`, `purchase_failed(product_id: StringName, reason: String)`.
  - Системные: `profile_loaded`, `cloud_sync_state_changed(state: StringName)`, `settings_changed(key: StringName, value: Variant)`, `toast_requested(text: String, icon: StringName)`.
- [x] Удалить устаревшие `sparks_picked_up`, `skill_choice_triggered`, `skill_applied`, `sparks_changed` после перевода подписчиков.
- [x] Документировать в шапке файла: кто эмитит каждый сигнал (один владелец на сигнал).

### 3. Слой данных: ConfigDB и Resource-определения
- [x] `ConfigDB.gd`: при `_ready()` читает все `res://configs/*.json` через `FileAccess.get_file_as_string` + `JSON.parse_string`, валидирует обязательные ключи, падает с понятной ошибкой в debug (`push_error` + `assert`).
- [x] Геттеры с типами: `get_balance() -> Dictionary`, `get_skill_tuning() -> Dictionary`, `get_enemy(id: StringName) -> EnemyDef`, `get_chapter(id: int) -> ChapterDef`, `get_beacon_cost(level: int) -> int` и т.д.
- [x] `src/data/defs/*`: `class_name SkillDef extends Resource` с `@export` полями (`id`, `category`, `type`, `max_level`, `synergies`, `tags`, `levels: Array[Dictionary]`, `icon`, `preview_scene`). Аналогично остальные Def-классы. Визуальные ассеты — в `.tres`, числа — в JSON (правка баланса без переимпорта).
- [x] Удалить `GameBalanceManager.gd`, перенести значения в `configs/balance.json` (временно, до task_3).

### 4. Сохранения: PlayerProfile + SaveManager
- [x] `PlayerProfile.gd` (`class_name PlayerProfile extends RefCounted`) — единая модель:
  ```
  schema_version: int
  wallet: { sparks: int, crystals: int }
  chapters: { current_id: int, unlocked_ids: Array[int], best_time_s: Dictionary }
  beacon: { "<chapter_id>": { level: int, pending_tier_cutscene: bool, seen_milestones: Array[int] } }
  skins: { unlocked: Array[StringName], equipped: StringName, new_badge: Array[StringName] }
  gear: { equipped: { head, core, feet, amulet, amulet_2: uid|null }, inventory: Array[{uid, base_id, slot, rarity, level, sparks_invested, is_new}] }
  chests: { premium_pity: int, basic_ads_today: int, ads_day_stamp: int }
  skills_archive: { seen: Array[StringName] }
  daily: { streak_day: int, last_claim_day: int }
  purchases: { starter_pack: { bought: bool, expires_at: int }, receipts: Array }
  settings: { music, sfx, vibration, no_flashes, camera_shake: bool, damage_numbers: int, language: String }
  meta: { install_ts: int, updated_at: int, device_id: String }
  ```
- [x] `to_dict()/from_dict()` с дефолтами для отсутствующих ключей; `StringName` сериализуются строками.
- [x] `SaveManager.gd`:
  - `load_profile() -> PlayerProfile`, `request_save()` (debounce 1.0 с по unscaled-таймеру), `flush()` (немедленно — при `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_CLOSE_REQUEST`, после покупок и перехода S09→S02).
  - Атомарная запись: `user://profile.json.tmp` → `DirAccess.rename_absolute` в `user://profile.json`; бэкап `profile.bak.json`.
  - `migrations: Array[Callable]` по `schema_version`. Миграция v0: чтение legacy `user://save_data.cfg` (`sparks`, `owned_skins`, `equipped_skin`, настройки; `has_no_ads` игнорируется — реальных покупок в legacy не было) → профиль v1; маппинг legacy-скинов (`default`→`base`, `pink_flame`→`pink`, прочие — компенсация Кристаллами).
  - Правило: **во время забега профиль не пишется**; искры забега живут в `RunContext` и зачисляются одной транзакцией на S09.
- [x] Правила слияния для облака (используются `CloudManager` в task_7): `max(beacon.level)` по главе, объединение `skins.unlocked`/`gear.inventory` по `uid`, `equipped` — по `updated_at`, `premium_pity` — max, кошелёк — по `updated_at` (не max, чтобы не дюпать валюту).

### 5. GameManager — фасад профиля и экономики
- [x] Хранит `profile: PlayerProfile`, `current_run: RunContext` (null вне забега).
- [x] Экономика — единственная точка изменения валют: `can_afford(currency, amount) -> bool`, `spend(currency: StringName, amount: int, reason: StringName) -> bool`, `grant(currency, amount, reason)`. Каждая операция → `EventBus.currency_changed` + `SaveManager.request_save()` + `Telemetry.log_economy(...)`.
- [x] Жизненный цикл забега: `start_run(chapter_id: int)` → создаёт `RunContext`, строит `StatBlock` через `StatsResolver`, вызывает `SceneRouter.go(&"S05")`; `end_run(result: RunResult)`; `apply_run_rewards(multiplier: int)` (x1/x3) — зачисляет искры забега, сундуки забега, прогресс глав.
- [x] Удалить из `GameManager`: `active_skills`, `permanent_skills`, `current_level/unlocked_level`, прямые вызовы `change_scene_to_file`, `get_equipped_skin_color()` (переезжает в `SkinDef`).

### 6. RunContext — состояние забега
- [x] `class_name RunContext extends RefCounted`: `run_id`, `seed: int`, `chapter_id`, `elapsed_s`, `run_sparks`, `xp`, `player_level`, `level_up_idx`, `skills: Dictionary[StringName, int]` (id → уровень), `offer_history`, `revive_used: bool`, `take_all_used: bool`, `reroll_count`, `kills`, `run_chests: Array`, `stats: StatBlock`.
- [x] `RandomNumberGenerator` с `seed` — все случайности забега (оферы навыков, спавн) детерминированы от `run.seed` (требование Skills DS §04).
- [x] Создаётся `GameManager.start_run`, уничтожается после S09. Геймплейные узлы получают его через `GameManager.current_run` в `_ready()` один раз, без поиска по дереву.

### 7. Статы: StatBlock + StatsResolver
- [x] `StatBlock` — поля: `max_light`, `decay_rate`, `contact_damage_mult`, `move_speed`, `magnet_radius`, `fuel_efficiency`, `spark_income_mult`, `aura_dps`, `area_scale`, `cooldown_mult`, `revive_light_pct` и т.д.
- [x] `StatsResolver.build(profile, skin_id) -> StatBlock`: база из `balance.json` → Маяки всех глав (суммируются, проценты **от базы**, не цепочкой — Meta DS §00, D5) → Экипировка (`Item_Stat = Base_Stat + Level × Stat_Step`) → модификаторы скина-класса. Навыки забега применяются поверх в рантайме (task_4).
- [x] Покрыть тестами: суммирование процентов от базы, тир 10 «+30% ко всем».

### 8. Пулы: ObjectPool + DamagePool
- [x] `ObjectPool.gd`: `prewarm(scene: PackedScene, count: int, parent: Node)`, `acquire() -> Node`, `release(node: Node)`; узлы не удаляются, а переводятся в `visible=false`, `process_mode=DISABLED`, выключаются коллизии. Жёсткий лимит без роста (в debug — `push_warning` при исчерпании).
- [x] `DamagePool.gd` переписать на `ObjectPool`: 40 объектов, **без роста** (сейчас растёт бесконечно), лимит 12 одновременно видимых (старейшая гасится), API `show_damage(amount: int, world_pos: Vector2, style: DamageStyle)`, где `enum DamageStyle { NORMAL, BIG_TICK, LETHAL }`. Подписан на `EventBus.damage_dealt` — враги больше не соединяются с пулом напрямую.
- [x] Инициализация контейнера: `DamagePool.bind_world(container: Node2D)` из сцены забега; `unbind()` на выходе.

### 9. SkillsManager — каркас
- [x] Реестр: `get_def(id: StringName) -> SkillDef`, `all_ids() -> Array[StringName]`; загрузка 12 `SkillDef` из `src/data/skills/*.tres` + тюнинг из `skills_config.json`.
- [x] Публичный API (реализация — task_4): `draw_offer(run: RunContext) -> Array[SkillOffer]`, `reroll(run) -> Array[SkillOffer]`, `apply(run, skill_id)`.
- [x] Удалить `SKILLS_DB`, `SKILL_CHOICE_TRIGGERED_TRASHHOLD` и константы навыков.

### 10. StoreManager — интерфейс
- [x] Каталог из `configs/shop.json` (`ShopProductDef`: `id`, `store_sku`, `kind: iap|crystals|sparks|ad`, `price`, `grants`).
- [x] API: `get_products() -> Array[ShopProductDef]`, `purchase(product_id: StringName) -> void` (результат — только через `EventBus.purchase_completed/failed`), `restore_purchases()`. Бэкенд за адаптером `IStoreBackend` (`MockStoreBackend` сейчас, нативные — task_7).
- [x] Выдача наград покупки — **только** в `StoreManager._grant(product)`; убрать обработку покупок из `MainMenu.gd` (там же баг: `StoreManager.ITEM_BLUE_SKIN` не существует).

### 11. SceneRouter и TimeService
- [x] `SceneRouter.gd`: реестр экранов по `screen_id` (`&"S01"`…`&"S17"`) → путь сцены + тип (`screen|modal|sheet`). API `go(id, params := {})`, `open_modal(id, params)`, `close_top()`. Переходы с длительностями из DS §05 (`t.fast 160`, `t.base 240`, `t.slow 400`, «нырок в свет» 600 мс).
- [x] Android «назад» (`NOTIFICATION_WM_GO_BACK_REQUEST`): в забеге → S07; в модале → закрыть; на вкладке → S02; на S02 → системный диалог выхода; на S06/S08/S09 — игнор (DS §04).
- [x] Каждый переход → `Telemetry.screen_view(screen_id)`.
- [x] `TimeService.gd`: `hit_stop(ms: int)` (через `Engine.time_scale` с восстановлением по `create_timer(..., ignore_time_scale=true)`), `ramp_time_scale(to: float, ms: int)`, `pause_world(reason)`/`resume_world(reason)` со стеком причин (левел-ап, пауза, revive не конфликтуют). UI-твины обязаны вызывать `set_ignore_time_scale(true)`.
- [x] Автопауза при `NOTIFICATION_APPLICATION_FOCUS_OUT` — одна точка обработки в `TimeService`/`GameManager` (сейчас разбросано по `PauseMenu`).

### 12. Telemetry и FeedbackManager (каркас)
- [x] `Telemetry.gd`: `log_event(name: StringName, params: Dictionary)`, `screen_view(id)`; бэкенд-адаптер (`DebugTelemetryBackend` печатает в консоль). Список событий — task_7.
- [x] `FeedbackManager.gd`: `haptic(kind: StringName)` (`selection|light|medium|heavy|rigid|soft|success`) с троттлингом по виду (искра ≥ 80 мс, убийство ≥ 120 мс), уважает `settings.vibration`. Реализация уровней — task_8.

### 13. Порядок автолоадов в `project.godot`
```
EventBus → ConfigDB → SaveManager → Telemetry → GameManager → TimeService → SceneRouter →
SkillsManager → DamagePool → AudioManager → FeedbackManager → AdManager → StoreManager →
Firebase → GameServices → CloudManager
```
- [x] Автолоады не обращаются друг к другу в `_init()`; межсервисная инициализация — в `_ready()` с учётом порядка выше.

### 14. Приведение к `docs/GDSCRIPT.md`
- [x] Строгая типизация во всех новых/изменённых файлах; включить в `project.godot` предупреждения `untyped_declaration`, `unsafe_*` как warning.
- [x] Никаких `get_node("path")`/`$Path` — только `@export` и `%UniqueName`.
- [x] `set_process(false)`/`set_physics_process(false)` у узлов, которым процесс нужен только на инициализацию.

## Критерии приёмки

- [x] Проект запускается без ошибок и предупреждений парсера; все автолоады грузятся в заданном порядке.
- [x] `grep -rn "find_child\|get_parent().get_node\|get_first_node_in_group" src/` не находит вхождений в UI и геймплее (кроме `SceneRouter`).
- [x] Ни один скрипт в `src/ui/**` не импортирует геймплейные классы (`Player`, `BaseEnemy`, `Chunk…`), и ни один геймплейный скрипт не ссылается на `src/ui/**`.
- [x] Legacy-сейв `user://save_data.cfg` мигрирует в `profile.json` v1 без потери искр, скинов и настроек (юнит-тест на фикстуре).
- [ ] Принудительное завершение процесса во время записи не портит профиль (восстановление из `.bak`) — ручной тест. _Автотест покрывает битый основной файл → бэкап; ручное убийство процесса не проводилось._
- [x] В течение забега на диск не пишется ни одного сейва (проверка логом `SaveManager`).
- [x] `DamagePool` при 200 одновременных `damage_dealt` держит ≤ 12 видимых цифр и 40 узлов в дереве.
- [x] `StatsResolver` покрыт тестами: база, Маяк (проценты от базы), экипировка по формуле gear_system §4.
- [ ] Android «назад» ведёт себя по таблице DS §04 на всех экранах-заглушках. _Логика покрыта тестом `test_navigation.gd` и сквозным прогоном; проверка на устройстве/эмуляторе — после первой Android-сборки._
- [x] Весь баланс, ранее зашитый в `GameBalanceManager`/`SkillsManager`, лежит в `configs/*.json`; `GameBalanceManager.gd` удалён.
