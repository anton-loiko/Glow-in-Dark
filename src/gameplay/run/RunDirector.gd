class_name RunDirector
extends Node
## Поток забега (task_2 §6, §10): таймер главы, Искры и XP, очередь левел-апов (L3–L8 Skills DS),
## смерть → S08 (один раз за забег) → S09, воскрешение, завершение по таймеру главы.
## Временный источник искр/топлива (debug_pickup_spawner) работает до появления врагов в task_3.

const MILESTONE_EVERY_S: float = 120.0

@export var player: Player
@export var pickups: PickupSystem
@export var streamer: ChunkStreamer
@export var burst: LightBurst
@export var camera: RunCamera

var run: RunContext
var chapter: ChapterDef
var balance: Dictionary = {}
var xp_needed: int = 5

var _fuel_heal: float = 40.0
var _invuln_after_levelup: float = 1.5
var _invuln_after_revive: float = 2.0
var _revive_countdown: float = 5.0
var _ramp_in_ms: int = 120
var _ramp_out_ms: int = 300
var _duration_s: float = 600.0
var _next_tick_s: float = 1.0
var _next_milestone_s: float = MILESTONE_EVERY_S
var _spark_income_carry: float = 0.0
var _pending_level_ups: int = 0
var _in_level_up: bool = false
var _finished: bool = false

var _spawner_enabled: bool = false
var _spawner_sparks_per_s: float = 2.0
var _spawner_fuel_every_s: float = 25.0
var _spawner_ring: Vector2 = Vector2(120, 420)
var _spawner_spark_acc: float = 0.0
var _spawner_fuel_acc: float = 0.0


func setup(p_run: RunContext, p_chapter: ChapterDef, p_balance: Dictionary) -> void:
	run = p_run
	chapter = p_chapter
	balance = p_balance
	_duration_s = chapter.duration_s
	var player_cfg: Dictionary = balance.get("player", {}) as Dictionary
	_fuel_heal = float(player_cfg.get("fuel_heal", _fuel_heal))
	_invuln_after_levelup = float(player_cfg.get("invuln_after_levelup_s", _invuln_after_levelup))
	_invuln_after_revive = float(player_cfg.get("invuln_after_revive_s", _invuln_after_revive))
	var run_cfg: Dictionary = balance.get("run", {}) as Dictionary
	_revive_countdown = float(run_cfg.get("revive_countdown_s", _revive_countdown))
	var level_cfg: Dictionary = balance.get("level_up", {}) as Dictionary
	_ramp_in_ms = int(level_cfg.get("time_ramp_in_ms", _ramp_in_ms))
	_ramp_out_ms = int(level_cfg.get("time_ramp_out_ms", _ramp_out_ms))
	var spawner: Dictionary = run_cfg.get("debug_pickup_spawner", {}) as Dictionary
	_spawner_enabled = bool(spawner.get("enabled", false))
	_spawner_sparks_per_s = float(spawner.get("sparks_per_s", _spawner_sparks_per_s))
	_spawner_fuel_every_s = float(spawner.get("fuel_every_s", _spawner_fuel_every_s))
	_spawner_ring = Vector2(float(spawner.get("ring_min_pt", 120)), float(spawner.get("ring_max_pt", 420)))

	xp_needed = xp_to_next(run.player_level)
	pickups.spark_collected.connect(_on_spark_collected)
	pickups.fuel_collected.connect(_on_fuel_collected)
	pickups.chest_collected.connect(_on_chest_collected)
	player.light_model.depleted.connect(_on_light_depleted)
	EventBus.player_revived.connect(_on_player_revived)
	EventBus.run_ended.connect(_on_run_ended)

	EventBus.run_sparks_changed.emit(run.run_sparks, 0)
	EventBus.xp_changed.emit(run.xp, xp_needed, run.player_level)
	# Розовое Пламя: стартовые Искры сразу идут и в опыт — первый левел-ап почти сразу (Meta DS).
	if run.run_sparks > 0:
		_add_xp(run.run_sparks)


## xp_to_next(level) = round(base × growth^(level − 1)).
func xp_to_next(level: int) -> int:
	var curve: Dictionary = balance.get("xp_curve", {}) as Dictionary
	return maxi(1, roundi(float(curve.get("base", 5)) * pow(float(curve.get("growth", 1.25)), level - 1)))


func elapsed() -> float:
	return run.elapsed_s


func _physics_process(delta: float) -> void:
	if run == null or _finished:
		return
	run.elapsed_s += delta
	if run.elapsed_s >= _next_tick_s:
		_next_tick_s += 1.0
		EventBus.chapter_timer_tick.emit(run.elapsed_s)
	if run.elapsed_s >= _next_milestone_s:
		Telemetry.log_event(&"chapter_milestone", {"run_id": run.run_id, "minute": roundi(_next_milestone_s / 60.0)})
		_next_milestone_s += MILESTONE_EVERY_S
	if run.elapsed_s >= _duration_s:
		_finish(RunResult.REASON_CHAPTER_CLEARED)
		return
	if _spawner_enabled and not player.is_dead():
		_run_debug_spawner(delta)


# --- Искры и опыт -------------------------------------------------------------

func _on_spark_collected(value: int, _pos: Vector2) -> void:
	_spark_income_carry += value * run.stats.spark_income_mult
	var gained: int = floori(_spark_income_carry)
	_spark_income_carry -= gained
	run.run_sparks += gained
	EventBus.run_sparks_changed.emit(run.run_sparks, gained)
	FeedbackManager.cue(&"spark")
	_add_xp(value)


func _add_xp(amount: int) -> void:
	run.xp += amount
	while run.xp >= xp_needed:
		run.xp -= xp_needed
		run.player_level += 1
		xp_needed = xp_to_next(run.player_level)
		_pending_level_ups += 1
	EventBus.xp_changed.emit(run.xp, xp_needed, run.player_level)
	if _pending_level_ups > 0 and not _in_level_up and not player.is_dead():
		_level_up_flow()


func _level_up_flow() -> void:
	_in_level_up = true
	player.visual.play_happy(1.2)
	var first: bool = true
	while _pending_level_ups > 0 and not _finished:
		_pending_level_ups -= 1
		run.level_up_idx += 1
		EventBus.level_up_ready.emit(run.player_level - _pending_level_ups, _pending_level_ups)
		Telemetry.log_event(&"level_up", {"run_id": run.run_id, "level": run.player_level - _pending_level_ups})
		if first:
			# L3: мир замедляется до 0 за 120 мс; повторно для очереди не проигрывается.
			await TimeService.ramp_time_scale(0.0, _ramp_in_ms).finished
			first = false
		SceneRouter.open_modal(&"S06")
		while SceneRouter.modal_stack().has(&"S06"):
			await EventBus.screen_changed
	# L8: возврат времени за 300 мс и 1.5 с неуязвимости.
	TimeService.ramp_time_scale(1.0, _ramp_out_ms)
	player.light_model.grant_invulnerability(_invuln_after_levelup)
	_in_level_up = false


# --- Топливо и сундуки --------------------------------------------------------

func _on_fuel_collected(pos: Vector2) -> void:
	var healed: float = player.light_model.heal_fuel(_fuel_heal)
	EventBus.fuel_collected.emit(healed, pos)
	FeedbackManager.cue(&"fuel")
	burst.trigger()


func _on_chest_collected(_pos: Vector2) -> void:
	run.run_chests.append(&"run")
	FeedbackManager.cue(&"run_chest")


# --- Смерть и воскрешение -----------------------------------------------------

func _on_light_depleted() -> void:
	if _finished:
		return
	if run.revive_used:
		_finish(RunResult.REASON_DEATH)
		return
	SceneRouter.open_modal(&"S08")
	await get_tree().create_timer(_revive_countdown, true, false, true).timeout
	if not _finished and player.is_dead():
		_finish(RunResult.REASON_DEATH)


func _on_player_revived(_source: StringName) -> void:
	if SceneRouter.modal_stack().has(&"S08"):
		SceneRouter.close_top()
	player.revive(run.stats.revive_light_pct, _invuln_after_revive)
	burst.trigger()


func _on_run_ended(_result: RunResult) -> void:
	_finished = true


func _finish(reason: StringName) -> void:
	if _finished:
		return
	_finished = true
	var result: RunResult = RunResult.new()
	result.reason = reason
	result.time_s = run.elapsed_s
	if reason == RunResult.REASON_CHAPTER_CLEARED:
		Telemetry.log_event(&"chapter_cleared", {"run_id": run.run_id, "chapter": run.chapter_id})
	GameManager.end_run(result)


# --- Временный спавнер (до task_3) -------------------------------------------

func _run_debug_spawner(delta: float) -> void:
	_spawner_spark_acc += delta * _spawner_sparks_per_s
	while _spawner_spark_acc >= 1.0:
		_spawner_spark_acc -= 1.0
		var pos: Vector2 = _random_ring_point()
		if pos != Vector2.INF:
			pickups.spawn_spark(pos, 1, false)
	_spawner_fuel_acc += delta
	if _spawner_fuel_acc >= _spawner_fuel_every_s:
		_spawner_fuel_acc = 0.0
		var fuel_pos: Vector2 = _random_ring_point()
		if fuel_pos != Vector2.INF:
			pickups.spawn_fuel(fuel_pos)


func _random_ring_point() -> Vector2:
	for attempt: int in 4:
		var angle: float = run.rng.randf() * TAU
		var dist: float = run.rng.randf_range(_spawner_ring.x, _spawner_ring.y)
		var pos: Vector2 = player.global_position + Vector2.from_angle(angle) * dist
		if not streamer.is_point_blocked(pos):
			return pos
	return Vector2.INF
