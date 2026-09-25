## RunBot (task_8 §5–6): автопилот забега до конца главы. Бессмертный игрок бродит, закрывает левел-апы
## случайной картой; бот считает спавны в кадре/свете, время кадра (p1/p50 FPS), мс систем, утечку узлов
## после возврата в хаб. Отчёт — reports/bot/run_bot.json; код выхода 1 при нарушениях (для CI).
##
##   godot --headless --fixed-fps 60 --script res://tests/bots/RunBot.gd -- [--stress] [--seconds=600] [--seed=12345]
##
## --stress: держит на поле до 150 врагов (лимит waves.json) — перф-сценарий 150 врагов с засадами.
## В headless время кадра — время CPU симуляции (рендера нет); FPS на устройстве меряется вручную по docs/TESTING.md.
extends SceneTree
# Нетипизированный доступ: скрипт компилируется до автолоадов.

const REPORT_PATH: String = "res://reports/bot/run_bot.json"
const STRESS_TARGET: int = 150
const STRESS_MIX: Array[StringName] = [&"whisper", &"whisper", &"whisper", &"reaper", &"devourer"]

var gm: Node
var router: Node
var bus: Node
var scene: Node
var stress: bool = false
var seconds: float = 600.0
var run_seed: int = 12345
var first_level_up: float = -1.0
var violations: int = 0
var max_total: int = 0
var max_counts: Dictionary = {}
var next_report: float = 30.0
var phase_log: Array = []
var wander_t: float = 0.0
var dir: Vector2 = Vector2.RIGHT
var kills_by: Dictionary = {}
var levelups: int = 0
var frame_ms: PackedFloat32Array = PackedFloat32Array()
var enemies_ms: PackedFloat32Array = PackedFloat32Array()
var nodes_before: int = 0
var _last_frame_us: int = 0
var end_time_s: float = 0.0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--stress":
			stress = true
		elif arg.begins_with("--seconds="):
			seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			run_seed = int(arg.get_slice("=", 1))
	await process_frame
	gm = root.get_node(^"GameManager")
	router = root.get_node(^"SceneRouter")
	bus = root.get_node(^"EventBus")
	root.get_node(^"SaveManager").set("save_dir", "user://test_saves/bot/")
	bus.connect("level_up_ready", _on_level_up)
	bus.connect("enemy_spawned", _on_spawned)
	bus.connect("wave_phase_changed", _on_phase)
	bus.connect("enemy_killed", _on_killed)
	router.call("go", &"S02")
	for i: int in 30:
		await process_frame
	nodes_before = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	gm.call("start_run", 1, run_seed)
	_last_frame_us = Time.get_ticks_usec()
	while true:
		await physics_frame
		scene = current_scene
		var run: Object = gm.get("current_run")
		if run == null or run.get("result") != null:
			break
		if _t() >= seconds:
			_force_finish()
			break
		_tick()
	var result: Object = gm.get("current_run").get("result") if gm.get("current_run") != null else null
	var reason: String = str(result.get("reason")) if result != null else "?"
	end_time_s = _t()
	# Возврат в хаб и проверка утечки узлов после забега.
	gm.call("apply_run_rewards", 1)
	router.call("go", &"S02")
	for i: int in 60:
		await process_frame
	var nodes_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_write_report(reason, nodes_after)
	quit(1 if violations > 0 or nodes_after - nodes_before > 50 else 0)


func _t() -> float:
	var run: Object = gm.get("current_run")
	return run.get("elapsed_s") if run else 0.0


func _tick() -> void:
	var now: int = Time.get_ticks_usec()
	frame_ms.append((now - _last_frame_us) / 1000.0)
	_last_frame_us = now
	if scene == null or not scene.has_node(^"World/Player"):
		return
	var player: Node = scene.get_node(^"World/Player")
	var lm: Object = player.get("light_model")
	lm.set("current", lm.get("max_value"))
	if router.call("modal_stack").has(&"S06"):
		var run: Object = gm.get("current_run")
		var offer: Array = run.get("current_offer")
		if not offer.is_empty():
			var pick: int = randi() % offer.size()
			root.get_node(^"SkillsManager").call("choose", run, offer[pick], pick, 0)
		router.call("close_top")
	if router.call("modal_stack").has(&"S08"):
		router.call("close_top")
	wander_t -= 1.0 / 60.0
	if wander_t <= 0.0:
		wander_t = 2.0
		dir = Vector2.from_angle(randf() * TAU)
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)
	if dir.x > 0.3: Input.action_press(&"move_right")
	if dir.x < -0.3: Input.action_press(&"move_left")
	if dir.y > 0.3: Input.action_press(&"move_down")
	if dir.y < -0.3: Input.action_press(&"move_up")
	var em: Node = scene.get_node(^"World/Enemies")
	if stress:
		_fill_to_target(em, player)
	var total: int = em.call("active_count")
	max_total = maxi(max_total, total)
	for id: StringName in [&"whisper", &"reaper", &"devourer", &"extinguisher"]:
		max_counts[id] = maxi(int(max_counts.get(id, 0)), int(em.call("active_count", id)))
	enemies_ms.append(float(load("res://src/debug/PerfStats.gd").call("avg_ms", &"enemies")))
	if _t() >= next_report:
		next_report += 30.0
		var wd: Node = scene.get_node(^"WaveDirector")
		print("[bot] t=%3d phase=%-8s total=%3d W=%3d R=%2d D=%d X=%d kills=%d lvl=%d sparks=%d enemies_ms=%.2f" % [int(_t()), wd.get("phase"), total, em.call("active_count", &"whisper"), em.call("active_count", &"reaper"), em.call("active_count", &"devourer"), em.call("active_count", &"extinguisher"), gm.get("current_run").get("kills"), gm.get("current_run").get("player_level"), gm.get("current_run").get("run_sparks"), enemies_ms[enemies_ms.size() - 1]])


## Стресс: добиваем поле до 150 врагов за кадром (кольцо 500–700pt), по 5 за тик, без нарушений правила спавна.
func _fill_to_target(em: Node, player: Node2D) -> void:
	for i: int in 5:
		if int(em.call("active_count")) >= STRESS_TARGET:
			return
		var pos: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(560.0, 720.0)
		em.call("spawn", STRESS_MIX[randi() % STRESS_MIX.size()], pos, false, 0.0, true)


func _force_finish() -> void:
	var result: RefCounted = load("res://src/core/run/RunResult.gd").new()
	result.set("reason", &"bot_timeout")
	result.set("time_s", _t())
	gm.call("end_run", result)


func _percentile(values: PackedFloat32Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = Array(values)
	sorted.sort()
	return float(sorted[clampi(int(p * (sorted.size() - 1)), 0, sorted.size() - 1)])


func _write_report(reason: String, nodes_after: int) -> void:
	# Первые 2 с — прогрев (шейдеры, пулы), в статистику не входят.
	var steady: PackedFloat32Array = frame_ms.slice(mini(120, frame_ms.size()))
	var report: Dictionary = {
		"mode": "stress" if stress else "normal",
		"seed": run_seed,
		"end_reason": reason,
		"time_s": snappedf(end_time_s, 0.1),
		"levelups": levelups,
		"first_level_up_s": snappedf(first_level_up, 0.1),
		"kills": kills_by,
		"max_total": max_total,
		"max_counts": max_counts,
		"spawn_violations": violations,
		"phases": phase_log.slice(0, 14),
		"sim_frame_ms_p50": snappedf(_percentile(steady, 0.5), 0.01),
		"sim_frame_ms_p99": snappedf(_percentile(steady, 0.99), 0.01),
		"sim_fps_p50": snappedf(1000.0 / maxf(0.001, _percentile(steady, 0.5)), 0.1),
		"sim_fps_p1": snappedf(1000.0 / maxf(0.001, _percentile(steady, 0.99)), 0.1),
		"enemies_ms_p50": snappedf(_percentile(enemies_ms, 0.5), 0.01),
		"enemies_ms_max": snappedf(_percentile(enemies_ms, 1.0), 0.01),
		"nodes_before": nodes_before,
		"nodes_after": nodes_after,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("[bot] REPORT ", JSON.stringify(report))


func _on_phase(p: StringName) -> void:
	phase_log.append("%s@%d" % [p, int(_t())])


func _on_killed(id: StringName, _pos: Vector2, _elite: bool) -> void:
	kills_by[id] = int(kills_by.get(id, 0)) + 1


func _on_level_up(_level: int, _queued: int) -> void:
	levelups += 1
	if first_level_up < 0.0:
		first_level_up = _t()


func _on_spawned(_id: StringName) -> void:
	if scene == null or not scene.has_node(^"World/Enemies"):
		return
	var em: Node = scene.get_node(^"World/Enemies")
	var list: Array = em.call("active_enemies")
	if list.is_empty():
		return
	var e: Node2D = list[list.size() - 1]
	if e.get("_eyes_only_left") > 0.0 or e.get("from_split"):
		return
	var player: Node2D = scene.get_node(^"World/Player")
	var d: float = e.global_position.distance_to(player.global_position)
	var cam: Camera2D = scene.get_node(^"World/Player/Camera")
	var local: Vector2 = (e.global_position - cam.get_screen_center_position()).abs()
	var in_frame: bool = local.x < 195.0 / cam.zoom.x and local.y < 422.0 / cam.zoom.y
	if in_frame or d < player.call("light_radius"):
		violations += 1
