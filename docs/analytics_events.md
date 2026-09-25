# Словарь событий аналитики

Единственный источник имён событий (task_7 §7). Все вызовы `Telemetry.log_event` используют имена из таблиц ниже — это проверяет тест `tests/services/test_telemetry.gd`. Новое событие сначала добавляется сюда.

Бэкенд — Firebase Analytics через godot-x/firebase (`FirebaseAnalyticsBackend`). В редакторе — `DebugTelemetryBackend` (консоль + оверлей последних 20 событий, F9 в debug-сборке). Сбор выключен до согласия (Consent Mode v2, `Telemetry.set_consent`). Ограничения Firebase: имя ≤ 40 символов, строковый параметр ≤ 100, bool отправляется как 0/1, массив — строкой через запятую.

## Сессия и навигация

| Событие | Параметры | Где |
|---|---|---|
| `app_open` | — | S01 `SplashScreen` |
| `sync_timeout` | — | S01, облако не ответило за 6 с |
| `screen_view` | `screen_id` | `SceneRouter` → `Telemetry.screen_view` |
| `tab_open` | `tab`, `from` | `SceneRouter.go` (вкладки S02/S10/S11/S12) |
| `settings_changed` | `key`, `value` | `GameManager.set_setting` |

## Забег

| Событие | Параметры | Где |
|---|---|---|
| `run_started` | `run_id`, `chapter`, `skin` | `GameManager.start_run` |
| `run_ended` | `run_id`, `reason`, `time_s`, `kills`, `level`, `sparks`, … (`RunResult.to_telemetry`) | `GameManager.end_run` |
| `chapter_milestone` | `run_id`, `minute` | `RunDirector` |
| `chapter_cleared` | `run_id`, `chapter` | `RunDirector` |
| `level_up` | `run_id`, `level` | `RunDirector` |
| `skill_offered` | `run_id`, `player_level`, `level_up_idx`, `reroll_idx`, `offer`, `rules_fired` | `SkillsManager` |
| `skill_selected` | `run_id`, `id`, `level_to`, `category`, `position`, `decision_ms`, `focus_used`, `took_all` | `SkillsManager` |
| `skill_reroll` | `run_id`, `cost_type` (`sparks`\|`ad`\|`crystal`) | `SkillsManager` |
| `skill_maxed` | `run_id`, `id`, `run_time_s` | `SkillsManager` |
| `revive_used` | `run_id`, `source` (`ad`\|`crystal`) | `GameManager.request_revive` |
| `reward_multiplier` | `run_id`, `multiplier` (1\|3) | `GameManager.apply_run_rewards` |

## Мета

| Событие | Параметры | Где |
|---|---|---|
| `daily_claimed` | `day`, `multiplier` | `DailyGiftService` |
| `beacon_deposit` | `levels`, `sparks`, `hold` | `BeaconCTA` |
| `beacon_tier` | `chapter`, `tier`, `time_since_install` | `BeaconService` |
| `beacon_milestone` | `pct`, `skipped` | `BeaconService` |
| `skin_unlocked` | `id`, `tier` | `SkinService` |
| `skin_equipped` | `id`, `source` (`s14`\|`s12`) | `SkinService` |
| `item_equipped` | `slot`, `power_delta` | `GearService` |
| `item_levelup` | `base_id`, `rarity`, `to`, `cost` | `GearService` |
| `item_merged` | `base_id`, `to_rarity`, `refund` | `GearService` |
| `item_dismantled` | `rarity`, `level`, `refund` | `GearService` |
| `chest_opened` | `type`, `x`, `rarities`, `pity` | `ChestService` |

## Монетизация

| Событие | Параметры | Где |
|---|---|---|
| `ad_opportunity_shown` | `placement`, `ready` | `AdManager.note_opportunity` (кнопка ▶ на экране) |
| `ad_started` | `placement` | `AdManager.show_rewarded` |
| `ad_completed` | `placement`, `rewarded` | `AdManager` |
| `ad_failed` | `placement`, `reason` | `AdManager` |
| `offer_shown` | `product_id` | `StoreManager.note_starter_pack_shown` (запуск FOMO-таймера) |
| `iap_started` | `product_id` | `StoreManager.purchase` |
| `iap_completed` | `product_id` | `StoreManager` (после выдачи и записи) |
| `iap_pending` | `product_id` | `StoreManager` (отложенная оплата) |
| `iap_failed` | `product_id`, `reason` | `StoreManager` |
| `iap_restored` | `product_id` | `StoreManager` («Восстановить покупки») |
| `earn_virtual_currency` | `virtual_currency_name`, `value`, `reason`, `balance` | `GameManager.grant` → `Telemetry.log_economy` |
| `spend_virtual_currency` | `virtual_currency_name`, `value`, `reason`, `balance` | `GameManager.spend` → `Telemetry.log_economy` |

## Аккаунт и облако

| Событие | Параметры | Где |
|---|---|---|
| `game_services_sign_in` | `platform` (`game_center`\|`play_games`\|`none`), `result` | `GameServices` |
| `account_link` | `provider`, `result` (`linked`\|`switched`\|`failed`) | `CloudManager` |

## User properties

| Свойство | Значение | Когда обновляется |
|---|---|---|
| `install_ts` | unix-время установки | загрузка профиля |
| `beacon_level` | сумма уровней Маяков всех глав | загрузка профиля, `beacon_level_changed` |
| `chapter` | текущая глава | загрузка профиля, начало забега |
| `payer` | `1`, если есть хотя бы один чек | загрузка профиля, `iap_completed` |
| `equipped_skin` | id Огонька | загрузка профиля, `skin_equipped` |

Плагин godot-x/firebase 3.1 не пробрасывает `setUserProperty`: бэкенд вызывает метод, только если он есть. До форка или PR свойства дублируются в Crashlytics custom keys.
