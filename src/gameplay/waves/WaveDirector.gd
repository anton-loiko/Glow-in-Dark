class_name WaveDirector
extends Node
## Директор волн (Enemy DS §05): петля ~90 с — расслабление 45 с → напряжение 30 с → награда 15 с;
## с 9:00 — непрерывное напряжение. Плотности по отрезкам таймлайна (configs/waves.json),
## элита в волнах напряжения, засада кольцом глаз, Гаситель по расписанию, бочки топлива в фазе награды.

const PHASE_CALM: StringName = &"calm"
const PHASE_TENSION: StringName = &"tension"
const PHASE_REWARD: StringName = &"reward"
const SPAWNABLE: Array[StringName] = [&"whisper", &"reaper", &"devourer", &"mourner"]
const ELITE_CANDIDATES: Array[StringName] = [&"whisper", &"reaper"]

var run: RunContext
var manager: EnemyManager
var pickups: PickupSystem
var streamer: ChunkStreamer
var player: Player
var camera: RunCamera

var phase: StringName = &""
var phase_t: float = 0.0

var _cfg: Dictionary = {}
var _loop: Array[Dictionary] = []
var _loop_length: float = 90.0
var _final_from: float = 540.0
var _acc: Dictionary[StringName, float] = {}
var _elites_left: int = 0
var _ambush_pending: bool = false
var _spawn_pause: float = 0.0
var _extinguisher_times: Array[float] = []
var _ring: SpawnRing = SpawnRing.new()
var _screen_half: Vector2 = Vector2(195, 422)


func setup(p_run: RunContext, p_manager: EnemyManager, p_pickups: PickupSystem, p_streamer: ChunkStreamer, p_player: Player, p_camera: RunCamera) -> void:
	run = p_run
	manager = p_manager
	pickups = p_pickups
	streamer = p_streamer
	player = p_player
	camera = p_camera
	_cfg = ConfigDB.get_config("waves")
	_ring.setup(_cfg)
	_loop.clear()
	_loop_length = 0.0
	for entry: Variant in _cfg.get("loop", []):
		var step: Dictionary = entry as Dictionary
		_loop.append(step)
		_loop_length += float(step.get("duration_s", 30))
	_final_from = float(_cfg.get("final_tension_from_s", 540))
	for t: Variant in _cfg.get("extinguisher_at_s", []):
		_extinguisher_times.append(float(t))
	for id: StringName in SPAWNABLE:
		_acc[id] = 0.0
	_screen_half = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 390)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 844))) * 0.5


func _physics_process(delta: float) -> void:
	if run == null or run.result != null or player.is_dead():
		return
	var t: float = run.elapsed_s
	_update_phase(t, delta)
	_spawn_pause = maxf(0.0, _spawn_pause - delta)
	if _spawn_pause <= 0.0:
		_spawn_regular(t, delta)
	if phase == PHASE_TENSION:
		_spawn_elites()
		if _ambush_pending and phase_t >= 5.0:
			_ambush_pending = false
			_spawn_ambush()
	while not _extinguisher_times.is_empty() and t >= _extinguisher_times[0]:
		_extinguisher_times.pop_front()
		_spawn_at_ring(&"extinguisher", false)


func _update_phase(t: float, delta: float) -> void:
	var new_phase: StringName = _phase_at(t)
	if new_phase == phase:
		phase_t += delta
		return
	phase = new_phase
	phase_t = 0.0
	EventBus.wave_phase_changed.emit(phase)
	match phase:
		PHASE_TENSION:
			_elites_left = int(_segment(t).get("elite_per_wave", 0))
			_ambush_pending = t >= 90.0
		PHASE_REWARD:
			_spawn_pause = _reward_pause()
			manager.retreat_all()
			_spawn_reward_fuel()


## Только расчёт фазы по времени (без побочных эффектов) — для тестов.
func _update_phase_for_test(t: float) -> void:
	phase = _phase_at(t)


func _phase_at(t: float) -> StringName:
	if t >= _final_from:
		return PHASE_TENSION
	var pos: float = fmod(t, _loop_length)
	for step: Dictionary in _loop:
		var duration: float = float(step.get("duration_s", 30))
		if pos < duration:
			return StringName(str(step.get("phase", "calm")))
		pos -= duration
	return PHASE_CALM


func _segment(t: float) -> Dictionary:
	var current: Dictionary = {}
	for entry: Variant in _cfg.get("timeline", []):
		var seg: Dictionary = entry as Dictionary
		if t >= float(seg.get("from_s", 0)):
			current = seg
	return current


func _phase_mul(id: StringName) -> float:
	var muls: Dictionary = (_cfg.get("phase_mul", {}) as Dictionary).get(String(phase), {}) as Dictionary
	return float(muls.get("whisper" if id == &"whisper" else "others", 1.0))


func _spawn_regular(t: float, delta: float) -> void:
	var seg: Dictionary = _segment(t)
	var rate_mul: float = player.stats.spawn_rate_mult
	for id: StringName in SPAWNABLE:
		var def: EnemyDef = ConfigDB.get_enemy(id)
		if def == null or not def.enabled or t < def.unlock_time_s:
			continue
		var per_min: float = float(seg.get(String(id), 0)) * _phase_mul(id) * rate_mul
		_acc[id] += per_min / 60.0 * delta
		if id == &"whisper":
			var group: Array = _cfg.get("whisper_group", [6, 12])
			var size: int = run.rng.randi_range(int(group[0]), int(group[1]))
			if _acc[id] >= size:
				_acc[id] -= size
				_spawn_group(id, size)
		else:
			while _acc[id] >= 1.0:
				_acc[id] -= 1.0
				_spawn_at_ring(id, false)


func _spawn_elites() -> void:
	if _elites_left <= 0 or phase_t < 3.0:
		return
	var options: Array[StringName] = []
	for id: StringName in ELITE_CANDIDATES:
		var def: EnemyDef = ConfigDB.get_enemy(id)
		if def != null and def.enabled and run.elapsed_s >= def.unlock_time_s:
			options.append(id)
	if options.is_empty():
		return
	var pick: StringName = options[run.rng.randi_range(0, options.size() - 1)]
	if _spawn_at_ring(pick, true) != null:
		_elites_left -= 1


func _spawn_at_ring(id: StringName, elite: bool) -> Enemy:
	var pos: Vector2 = _ring_point()
	if pos == Vector2.INF:
		return null
	return manager.spawn(id, pos, elite)


func _spawn_group(id: StringName, size: int) -> void:
	var center: Vector2 = _ring_point()
	if center == Vector2.INF:
		return
	for i: int in size:
		var offset: Vector2 = Vector2.from_angle(run.rng.randf() * TAU) * run.rng.randf_range(0.0, 40.0)
		if manager.spawn(id, center + offset) == null:
			return


## Засада: 12–20 пар глаз кольцом вокруг игрока (сначала только глаза, 800 мс), затем кольцо сжимается.
func _spawn_ambush() -> void:
	var pairs: Array = _cfg.get("ambush_pairs", [12, 20])
	var count: int = run.rng.randi_range(int(pairs[0]), int(pairs[1]))
	var ambush: Dictionary = _cfg.get("ambush", {}) as Dictionary
	var radius: float = maxf(player.light_radius() + 60.0, _screen_half.length() * float(ambush.get("radius_screens", 0.75)))
	var eyes_only: float = float(ambush.get("eyes_only_s", 0.8))
	var center: Vector2 = player.global_position
	for i: int in count:
		var pos: Vector2 = center + Vector2.from_angle(TAU * i / count) * radius
		if not streamer.is_point_blocked(pos):
			manager.spawn(&"whisper", pos, false, eyes_only)


func _spawn_reward_fuel() -> void:
	var range_pair: Array = _cfg.get("reward_fuel", [2, 3])
	var count: int = run.rng.randi_range(int(range_pair[0]), int(range_pair[1]))
	var max_dist: float = _screen_half.length() * 1.5
	var spots: Array[Vector2] = []
	for chunk: Chunk in streamer.active_chunks():
		for marker: Vector2 in chunk.fuel_markers:
			if marker.distance_to(player.global_position) <= max_dist:
				spots.append(marker)
	spots.sort_custom(_closer_to_player)
	for i: int in count:
		if i < spots.size():
			pickups.spawn_fuel(spots[i])
		else:
			var pos: Vector2 = player.global_position + Vector2.from_angle(run.rng.randf() * TAU) * run.rng.randf_range(220.0, 380.0)
			if not streamer.is_point_blocked(pos):
				pickups.spawn_fuel(pos)


func _closer_to_player(a: Vector2, b: Vector2) -> bool:
	return a.distance_squared_to(player.global_position) < b.distance_squared_to(player.global_position)


func _reward_pause() -> float:
	for step: Dictionary in _loop:
		if StringName(str(step.get("phase", ""))) == PHASE_REWARD:
			return float(step.get("spawn_pause_s", 5.0))
	return 5.0


func _ring_point() -> Vector2:
	var radius: float = _ring.ring_radius(_screen_half, camera.zoom.x, player.light_radius())
	return _ring.pick(player.global_position, player.velocity, radius, run.rng, streamer.is_point_blocked)
