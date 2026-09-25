extends Node
## Глобальная шина событий. Сигналы — только ФАКТЫ в прошедшем времени, без ссылок на узлы.
## У каждого сигнала один владелец (кто эмитит); подписываться может кто угодно.
## Геймплей публикует факты, UI подписывается; UI отправляет намерения через API сервисов.

@warning_ignore_start("unused_signal")

# --- Забег ------------------------------------------------------------------
## GameManager.start_run
signal run_started(run_id: String, chapter_id: int)
## TimeService (стек причин паузы мира)
signal run_paused(reason: StringName)
## TimeService
signal run_resumed
## GameManager.end_run
signal run_ended(result: RunResult)
## RunDirector (task_2), раз в секунду
signal chapter_timer_tick(elapsed_s: float)
## WaveDirector (task_3): calm | tension | reward
signal wave_phase_changed(phase: StringName)

# --- Игрок (task_2) ----------------------------------------------------------
## PlayerLight
signal player_light_changed(current: float, max_value: float)
## PlayerLight
signal player_damaged(amount: float, source: StringName)
## PlayerLight, ровно один раз за «смерть»
signal player_light_depleted
## RunDirector после применения воскрешения: ad | crystal
signal player_revived(source: StringName)
## FuelCapsule
signal fuel_collected(amount: float, world_pos: Vector2)
## LightBurst
signal light_burst_triggered(world_pos: Vector2)

# --- Бой (task_3) ------------------------------------------------------------
## WaveDirector
signal enemy_spawned(archetype: StringName)
## Enemy (E7)
signal enemy_killed(archetype: StringName, world_pos: Vector2, is_elite: bool)
## LightDamageSystem / навыки; style — DamageNumber.Style
signal damage_dealt(amount: int, world_pos: Vector2, style: int)

# --- Прогрессия забега (task_2, task_4) --------------------------------------
## RunDirector
signal run_sparks_changed(total: int, delta: int)
## RunDirector
signal xp_changed(current: int, needed: int, level: int)
## RunDirector
signal level_up_ready(level: int, queued: int)
## SkillsManager: Array[SkillOffer]
signal skill_offer_presented(offer: Array)
## SkillsManager.apply
signal skill_selected(skill_id: StringName, level_to: int)

# --- Экономика и мета --------------------------------------------------------
## GameManager (grant/spend): sparks | crystals
signal currency_changed(currency: StringName, total: int, delta: int)
## BeaconService (task_6)
signal beacon_level_changed(chapter_id: int, level: int)
## BeaconService (task_6)
signal beacon_tier_reached(chapter_id: int, tier: int)
## SkinService (task_6)
signal skin_unlocked(skin_id: StringName)
## SkinService (task_6)
signal skin_equipped(skin_id: StringName)
## GearService (task_6)
signal gear_changed(slot: StringName)
## GearService / ChestService (task_6)
signal inventory_changed

# --- Монетизация -------------------------------------------------------------
## AdManager
signal ad_reward_granted(placement: StringName)
## AdManager
signal ad_failed(placement: StringName)
## StoreManager — после выдачи награды
signal purchase_completed(product_id: StringName)
## StoreManager
signal purchase_failed(product_id: StringName, reason: String)

# --- Системные ---------------------------------------------------------------
## GameManager после загрузки или замены профиля
signal profile_loaded
## CloudManager: syncing | synced | offline | error
signal cloud_sync_state_changed(state: StringName)
## GameManager.set_setting
signal settings_changed(key: StringName, value: Variant)
## Любой сервис; UI показывает вне боя (DS §02 Toast)
signal toast_requested(text: String, icon: StringName)
## SceneRouter после смены экрана или открытия модала
signal screen_changed(screen_id: StringName)

@warning_ignore_restore("unused_signal")


func _ready() -> void:
	set_process(false)
