## Бот-забег 10:00 (task_3, task_8): бессмертный игрок бродит, закрывает левел-апы, печатает состав волн
## и считает спавны в кадре/свете. Запуск:
##   godot --headless --fixed-fps 60 --script res://tools/bot_run.gd
extends SceneTree
# 10-минутный забег-бот (task_3). Нетипизированный доступ: скрипт компилируется до автолоадов.

var gm: Node
var router: Node
var bus: Node
var scene: Node
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

func _init() -> void:
	await process_frame
	gm = root.get_node(^"GameManager")
	router = root.get_node(^"SceneRouter")
	bus = root.get_node(^"EventBus")
	root.get_node(^"SaveManager").set("save_dir", "user://test_saves/bot/")
	bus.connect("level_up_ready", _on_level_up)
	bus.connect("enemy_spawned", _on_spawned)
	bus.connect("wave_phase_changed", func(p: StringName) -> void: phase_log.append("%s@%d" % [p, int(_t())]))
	bus.connect("enemy_killed", func(id: StringName, _pos: Vector2, _e: bool) -> void: kills_by[id] = kills_by.get(id, 0) + 1)
	gm.call("start_run", 1, 12345)
	while true:
		await physics_frame
		scene = current_scene
		if gm.get("current_run") == null or gm.get("current_run").get("result") != null:
			break
		_tick()
	var result: Object = gm.get("current_run").get("result") if gm.get("current_run") != null else null
	print("[bot] END reason=%s t=%.1f kills=%s level=%s levelups=%d first_levelup=%.1fs" % [result.get("reason") if result else "?", _t(), kills_by, gm.get("current_run").get("player_level") if gm.get("current_run") else "?", levelups, first_level_up])
	print("[bot] phases=", phase_log.slice(0, 14))
	print("[bot] max_total=%d max_counts=%s violations=%d" % [max_total, max_counts, violations])
	if gm.get("current_run") != null:
		print("[bot] skills=", gm.get("current_run").get("skills"))
	quit()

func _t() -> float:
	var run: Object = gm.get("current_run")
	return run.get("elapsed_s") if run else 0.0

func _tick() -> void:
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
	for a in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)
	if dir.x > 0.3: Input.action_press(&"move_right")
	if dir.x < -0.3: Input.action_press(&"move_left")
	if dir.y > 0.3: Input.action_press(&"move_down")
	if dir.y < -0.3: Input.action_press(&"move_up")
	var em: Node = scene.get_node(^"World/Enemies")
	var total: int = em.call("active_count")
	max_total = max(max_total, total)
	for id in [&"whisper", &"reaper", &"devourer", &"extinguisher"]:
		max_counts[id] = max(max_counts.get(id, 0), em.call("active_count", id))
	if _t() >= next_report:
		next_report += 30.0
		var wd: Node = scene.get_node(^"WaveDirector")
		print("[bot] t=%3d phase=%-8s total=%3d W=%3d R=%2d D=%d X=%d kills=%d lvl=%d sparks=%d" % [int(_t()), wd.get("phase"), total, em.call("active_count", &"whisper"), em.call("active_count", &"reaper"), em.call("active_count", &"devourer"), em.call("active_count", &"extinguisher"), gm.get("current_run").get("kills"), gm.get("current_run").get("player_level"), gm.get("current_run").get("run_sparks")])

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
