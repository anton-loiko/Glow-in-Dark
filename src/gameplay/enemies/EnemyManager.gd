class_name EnemyManager
extends Node2D
## Все враги забега (Enemy DS §08–§09): пулы по архетипам (без instantiate в бою), один цикл тика,
## пространственная сетка для разделения стаи (раз в 2 кадра), урон светом тиками,
## цифры урона с накоплением 0.4 с, касания, реакция на Взрыв Света, награды за сгорание.

var enemies_cfg: Dictionary = {}
var player: Player
var pickups: PickupSystem
var streamer: ChunkStreamer
var camera: RunCamera
var run: RunContext

var _pools: Dictionary[StringName, ObjectPool] = {}
var _active: Array[Enemy] = []
var _counts: Dictionary[StringName, int] = {}
var _elite_count: int = 0
var _markers: ObjectPool = ObjectPool.new()
var _grid: Dictionary[Vector2i, Array] = {}
var _frame: int = 0
var _burn_tick: float = 0.25
var _burn_acc: float = 0.0
var _number_accumulate: float = 0.4
var _big_tick_mul: float = 3.0
var _sep_cell: float = 64.0
var _sep_strength: float = 60.0
var _light_drain: float = 1.0
var _screen_half: Vector2 = Vector2(195, 422)


func setup(p_player: Player, p_pickups: PickupSystem, p_streamer: ChunkStreamer, p_camera: RunCamera, p_run: RunContext) -> void:
	player = p_player
	pickups = p_pickups
	streamer = p_streamer
	camera = p_camera
	run = p_run
	enemies_cfg = ConfigDB.get_config("enemies")
	var burn: Dictionary = enemies_cfg.get("burn", {}) as Dictionary
	_burn_tick = float(burn.get("tick_s", 0.25))
	_number_accumulate = float(burn.get("number_accumulate_s", 0.4))
	_big_tick_mul = float(burn.get("big_tick_mul", 3.0))
	var sep: Dictionary = enemies_cfg.get("separation", {}) as Dictionary
	_sep_cell = float(sep.get("cell_pt", 64.0))
	_sep_strength = float(sep.get("strength", 60.0))
	_screen_half = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 390)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 844))) * 0.5
	for entry: Variant in enemies_cfg.get("enemies", []):
		var id: StringName = StringName(str((entry as Dictionary).get("id")))
		var def: EnemyDef = ConfigDB.get_enemy(id)
		if def == null or not def.enabled:
			continue
		var pool: ObjectPool = ObjectPool.new()
		pool.prewarm(_make_enemy, def.pool_size, self)
		_pools[id] = pool
		_counts[id] = 0
	var marker_limit: int = int((ConfigDB.get_config("waves")).get("max_markers", 6))
	_markers.prewarm(_make_marker, marker_limit, self)
	EventBus.light_burst_triggered.connect(_on_light_burst)


# --- Спавн ---------------------------------------------------------------------

func can_spawn(id: StringName, elite: bool = false) -> bool:
	var def: EnemyDef = ConfigDB.get_enemy(id)
	if def == null or not _pools.has(id):
		return false
	var limits: Dictionary = ConfigDB.get_config("waves").get("limits", {}) as Dictionary
	if _active.size() >= int(limits.get("total", 150)):
		return false
	if _counts[id] >= int(limits.get(String(id), def.screen_limit)):
		return false
	if elite and _elite_count >= int(limits.get("elite", 2)):
		return false
	return true


func spawn(id: StringName, pos: Vector2, elite: bool = false, eyes_only_s: float = 0.0, from_split: bool = false) -> Enemy:
	if not can_spawn(id, elite):
		return null
	var enemy: Enemy = _pools[id].acquire() as Enemy
	if enemy == null:
		return null
	var minutes: float = run.elapsed_s / 60.0
	var scaling: Dictionary = enemies_cfg.get("scaling_per_minute", {}) as Dictionary
	var hp_mul: float = pow(float(scaling.get("hp", 1.18)), minutes)
	var dmg_mul: float = pow(float(scaling.get("damage", 1.08)), minutes)
	enemy.activate(ConfigDB.get_enemy(id), pos, elite, hp_mul, dmg_mul, self, eyes_only_s)
	enemy.rim_color = _rim_color()
	if from_split:
		enemy.from_split = true
		enemy.state_t = 1.0 # раскол: без анимации открытия глаз
	_active.append(enemy)
	_counts[id] += 1
	if elite:
		_elite_count += 1
	EventBus.enemy_spawned.emit(id)
	return enemy


func release_enemy(enemy: Enemy) -> void:
	var idx: int = _active.find(enemy)
	if idx == -1:
		return
	_active.remove_at(idx)
	_counts[enemy.def.id] -= 1
	if enemy.is_elite:
		_elite_count -= 1
	_pools[enemy.def.id].release(enemy)


func active_count(id: StringName = &"") -> int:
	return _active.size() if id == &"" else _counts.get(id, 0)


func active_enemies() -> Array[Enemy]:
	return _active


## Фаза «Награда»: выжившие медленно отступают во тьму.
func retreat_all() -> void:
	for enemy: Enemy in _active:
		enemy.start_retreat()


# --- Запросы для навыков (task_4) -------------------------------------------------

func enemies_in_radius(center: Vector2, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy: Enemy in _active:
		if enemy.is_targetable() and enemy.global_position.distance_to(center) <= radius + enemy.radius:
			result.append(enemy)
	return result


## Цели Луча Света: сначала ближайшие, при равных — тяжёлые (L/XL); только в пределах max_range.
func pick_targets(center: Vector2, count: int, max_range: float) -> Array[Enemy]:
	var candidates: Array[Enemy] = enemies_in_radius(center, max_range)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool: return _target_score(a, center) < _target_score(b, center))
	return candidates.slice(0, count)


func _target_score(enemy: Enemy, center: Vector2) -> float:
	var heavy: bool = enemy.def.size_class == &"L" or enemy.def.size_class == &"XL" or enemy.is_elite
	return enemy.global_position.distance_to(center) - (60.0 if heavy else 0.0)


## Дополнительный урон всем врагам в свете (Аура ур.5 — усиленный тик).
func damage_in_light(amount: float) -> void:
	for i: int in range(_active.size() - 1, -1, -1):
		if i < _active.size() and _active[i].in_light:
			_active[i].take_damage(amount)


# --- Сервисы для врагов --------------------------------------------------------

func player_position() -> Vector2:
	return player.global_position


func player_body_radius() -> float:
	return player.visual.body_radius


func is_blocked(pos: Vector2) -> bool:
	return streamer.is_point_blocked(pos)


func acquire_marker() -> TelegraphMarker:
	return _markers.acquire() as TelegraphMarker


func release_marker(marker: TelegraphMarker) -> void:
	if marker != null:
		_markers.release(marker)


## Касание / удар по игроку (E6).
func hit_player(enemy: Enemy, source: StringName) -> void:
	if player.is_dead():
		return
	var dealt: float = player.light_model.apply_damage(enemy.damage_pct, source)
	if dealt > 0.0:
		camera.shake(3.0, 0.12)
		FeedbackManager.haptic(&"rigid")


## Плазменный Огонёк: касание сжигает врага (элита −40% HP, Гаситель −15%). true — урон игроку не наносится.
func try_instant_burn(enemy: Enemy) -> bool:
	if not player.stats.contact_instant_burn:
		return false
	var flags: Dictionary = player.stats.skin_flags
	if enemy.def.id == &"extinguisher":
		enemy.take_damage(enemy.max_hp * float(flags.get("extinguisher_contact_hp_pct", 15)) / 100.0)
		return false
	if enemy.is_elite:
		enemy.take_damage(enemy.max_hp * float(flags.get("elite_contact_hp_pct", 40)) / 100.0)
		return false
	enemy.take_damage(enemy.hp)
	return true


## Аура Гасителя: свет игрока «продавлен» на время нахождения в ауре.
func request_light_drain(multiplier: float) -> void:
	_light_drain = minf(_light_drain, multiplier)


func stats_burn_after_exit() -> float:
	return player.stats.burn_after_exit_s


# --- Цикл ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_frame += 1
	if _frame % 2 == 0:
		_rebuild_grid()
	_light_drain = 1.0
	var player_pos: Vector2 = player.global_position
	var light_radius: float = player.light_radius()
	var slow_pct: float = player.stats.aura_slow_pct
	var despawn_dist: float = _screen_half.y * 2.0 * float((enemies_cfg.get("lifecycle", {}) as Dictionary).get("despawn_screens", 2.0))
	for i: int in range(_active.size() - 1, -1, -1):
		if i >= _active.size():
			continue
		var enemy: Enemy = _active[i]
		enemy.separation = _separation_for(enemy)
		var to_player: Vector2 = player_pos - enemy.global_position
		enemy.tick(delta, to_player, light_radius)
		if not enemy.is_alive():
			continue
		if enemy.in_light and not enemy.entry_freeze_done and player.stats.light_entry_freeze_s > 0.0:
			enemy.entry_freeze_done = true
			enemy.apply_freeze(player.stats.light_entry_freeze_s)
		if slow_pct > 0.0:
			if enemy.in_light:
				enemy.apply_slow(slow_pct, &"skin_aura")
			else:
				enemy.clear_slow(&"skin_aura")
		_update_despawn(enemy, to_player, despawn_dist, delta)
		_update_numbers(enemy, delta)
	player.aura_radius_mult = _light_drain
	_burn_tick = player.stats.aura_tick_s
	_burn_acc += delta
	while _burn_acc >= _burn_tick:
		_burn_acc -= _burn_tick
		_apply_light_damage()


func _apply_light_damage() -> void:
	if player.is_dead():
		return
	var dmg: float = player.stats.aura_dps * _burn_tick
	for i: int in range(_active.size() - 1, -1, -1):
		if i >= _active.size():
			continue
		var enemy: Enemy = _active[i]
		if not enemy.is_targetable():
			continue
		if enemy.in_light:
			enemy.take_damage(dmg)
		elif enemy.burn_after_exit_left > 0.0:
			enemy.burn_after_exit_left -= _burn_tick
			enemy.take_damage(dmg)


func _update_numbers(enemy: Enemy, delta: float) -> void:
	if enemy.dmg_acc <= 0.0:
		return
	enemy.dmg_acc_t += delta
	if enemy.dmg_acc_t >= _number_accumulate:
		_emit_number(enemy, false)


func _emit_number(enemy: Enemy, lethal: bool) -> void:
	if enemy.dmg_acc <= 0.0:
		return
	var style: DamageNumber.Style = DamageNumber.Style.NORMAL
	if lethal and enemy.def.id != &"whisper":
		style = DamageNumber.Style.LETHAL
	elif enemy.dmg_acc >= player.stats.aura_dps * _burn_tick * _big_tick_mul:
		style = DamageNumber.Style.BIG_TICK
	EventBus.damage_dealt.emit(ceili(enemy.dmg_acc), enemy.global_position + Vector2(0, -enemy.radius), style)
	enemy.dmg_acc = 0.0
	enemy.dmg_acc_t = 0.0


func _update_despawn(enemy: Enemy, to_player: Vector2, despawn_dist: float, delta: float) -> void:
	var dist: float = to_player.length()
	if dist > despawn_dist or (enemy.state == Enemy.State.RETREAT and dist > _screen_half.length() * 1.3):
		enemy.far_t += delta
		if enemy.far_t >= float((enemies_cfg.get("lifecycle", {}) as Dictionary).get("despawn_after_s", 4.0)) and _is_offscreen(enemy):
			enemy.begin_despawn()
	else:
		enemy.far_t = 0.0


func _is_offscreen(enemy: Enemy) -> bool:
	var local: Vector2 = (enemy.global_position - camera.get_screen_center_position()).abs()
	var half: Vector2 = _screen_half / camera.zoom
	return local.x > half.x + enemy.radius or local.y > half.y + enemy.radius


# --- Разделение стаи -----------------------------------------------------------

func _rebuild_grid() -> void:
	_grid.clear()
	for enemy: Enemy in _active:
		var cell: Vector2i = Vector2i((enemy.global_position / _sep_cell).floor())
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(enemy)


func _separation_for(enemy: Enemy) -> Vector2:
	if not enemy.is_alive():
		return Vector2.ZERO
	var cell: Vector2i = Vector2i((enemy.global_position / _sep_cell).floor())
	var push: Vector2 = Vector2.ZERO
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var bucket: Array = _grid.get(cell + Vector2i(dx, dy), [])
			for other: Enemy in bucket:
				if other == enemy or not other.is_alive():
					continue
				var offset: Vector2 = enemy.global_position - other.global_position
				var min_dist: float = (enemy.radius + other.radius) * 0.9
				var d: float = offset.length()
				if d > 0.001 and d < min_dist:
					push += offset / d * (1.0 - d / min_dist) * (other.radius / enemy.radius)
	return push * _sep_strength


# --- Смерть и награды ----------------------------------------------------------

func on_enemy_killed(enemy: Enemy) -> void:
	_emit_number(enemy, true)
	var pos: Vector2 = enemy.global_position
	var elite_cfg: Dictionary = enemies_cfg.get("elite", {}) as Dictionary
	var sparks: int = enemy.def.sparks * (int(elite_cfg.get("sparks_mul", 5)) if enemy.is_elite else 1)
	var pieces: int = mini(sparks, 6)
	for i: int in pieces:
		var value: int = floori(float(sparks) / pieces) + (1 if i < sparks % pieces else 0)
		pickups.spawn_spark(pos + Vector2.from_angle(TAU * i / pieces) * 4.0, value, true)
	var fuel_chance: float = float(elite_cfg.get("fuel_chance", 1.0)) if enemy.is_elite else enemy.def.fuel_chance
	if run.rng.randf() < fuel_chance:
		pickups.spawn_fuel(pos + Vector2(12, 0))
	var chest_cfg: Dictionary = enemies_cfg.get("run_chest_chance", {}) as Dictionary
	var chest_chance: float = 0.0
	if enemy.def.id == &"extinguisher":
		chest_chance = float(chest_cfg.get("extinguisher", 0.5))
		pickups.spawn_fuel(pos - Vector2(12, 0))
		_extinguisher_reward()
	elif enemy.is_elite:
		chest_chance = float(chest_cfg.get("elite", 0.2))
	if chest_chance > 0.0 and run.rng.randf() < chest_chance:
		pickups.spawn_chest(pos)
	var hit_stop: int = 45 if enemy.is_elite else enemy.def.hit_stop_ms
	if hit_stop > 0:
		TimeService.hit_stop(hit_stop)
	var spawn_on_death: Dictionary = enemy.def.attack.get("spawn_on_death", {}) as Dictionary
	for child_id: String in spawn_on_death:
		_spawn_children_later(StringName(child_id), int(spawn_on_death[child_id]), pos)
	run.kills += 1
	FeedbackManager.haptic(&"light")
	EventBus.enemy_killed.emit(enemy.def.id, pos, enemy.is_elite)


func _spawn_children_later(id: StringName, count: int, pos: Vector2) -> void:
	await get_tree().create_timer(0.3, false).timeout
	for i: int in count:
		spawn(id, pos + Vector2.from_angle(TAU * i / count) * 20.0, false, 0.0, true)


func _extinguisher_reward() -> void:
	camera.shake(4.0, 0.3)
	var tween: Tween = create_tween()
	var full: float = _screen_half.length() / maxf(1.0, player.light_radius())
	tween.tween_property(player, ^"radius_boost", full, 0.25)
	tween.tween_interval(0.75)
	tween.tween_property(player, ^"radius_boost", 1.0, 0.4)


func _on_light_burst(origin: Vector2) -> void:
	var radius: float = player.light_radius() * 1.4
	var lifecycle: Dictionary = enemies_cfg.get("lifecycle", {}) as Dictionary
	for enemy: Enemy in _active:
		if not enemy.is_targetable():
			continue
		var offset: Vector2 = enemy.global_position - origin
		if offset.length() > radius + enemy.radius:
			continue
		if enemy.attack is DarkAuraAttack:
			(enemy.attack as DarkAuraAttack).on_light_burst(enemy)
			continue
		enemy.apply_knockback(offset, float(lifecycle.get("burst_knockback_pt", 80.0)))
		enemy.stun(float(lifecycle.get("stun_s", 0.6)))


func _rim_color() -> Color:
	var skin: SkinDef = ConfigDB.get_skin(GameManager.profile.skin_equipped)
	return skin.rim_color if skin != null else Color("#FFB547")


func _make_enemy() -> Node:
	return Enemy.new()


func _make_marker() -> Node:
	return TelegraphMarker.new()
