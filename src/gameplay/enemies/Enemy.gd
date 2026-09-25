class_name Enemy
extends Node2D
## Теневая сущность (Enemy DS §01–§03). Общий автомат E1–E8 для всех архетипов; атаку задаёт EnemyAttack.
## Узел без собственного процесса: EnemyManager тикает всех врагов одним циклом.
## Временная процедурная отрисовка до hi-res арта (task_8): тело темнее тьмы, красные глаза видны всегда,
## контровая обводка цветом скина — только в свете, трещины = потерянное HP.

enum State { SPAWN, HUNT, REVEAL, BURN, TELEGRAPH, ACTIVE, RECOIL, DYING, STUN, RETREAT, DESPAWN }

const BODY: Color = Color("#0A0B12")
const CORE: Color = Color("#03040A")
const EYE: Color = Color("#FF3B5C")
const EYE_GLINT: Color = Color("#FFE0E6")
const CRACK: Color = Color("#FFC86B")
const HOT: Color = Color("#FFF1D0")
const ELITE_RIM: Color = Color("#B07CFF")

var def: EnemyDef
var is_elite: bool = false
var max_hp: float = 1.0
var hp: float = 1.0
var base_speed: float = 60.0
var damage_pct: float = 0.0
var radius: float = 18.0
var eye_count: int = 2
var state: State = State.SPAWN
var state_t: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var separation: Vector2 = Vector2.ZERO
var attack: EnemyAttack
var marker: TelegraphMarker
var in_light: bool = false
var rim_color: Color = Color("#FFB547")
var manager: EnemyManager

var dmg_acc: float = 0.0
var dmg_acc_t: float = 0.0
var contact_cd: float = 0.0
var burn_after_exit_left: float = 0.0
var far_t: float = 0.0
## Появился из раскола Пожирателя — единственный спавн, которому можно быть в кадре (Enemy DS §03).
var from_split: bool = false
## Оцепенение при первом входе в свет уже сработало (Заморозка ур.5).
var entry_freeze_done: bool = false

var _slows: Dictionary[StringName, float] = {}
var _freeze_left: float = 0.0
var _stun_left: float = 0.0
var _eyes_only_left: float = 0.0
var _reveal: float = 0.0
var _blink_t: float = 0.0
var _next_blink: float = 4.0
var _facing: Vector2 = Vector2.DOWN
var _recoil_dir: Vector2
var _cfg: Dictionary = {}
## Hi-res спрайт тела (EnemyVisuals): освещается светом Огонька; нет ассета — процедурная отрисовка.
var _sprite: Sprite2D
var _frame_px: float = 72.0
var _anim_t: float = 0.0
# Значения конфига, кэшированные при активации (без разбора словарей в тике — task_8 §5).
var _spawn_s: float = 0.6
var _death_s: float = 0.48
var _recoil_pt: float = 24.0
var _contact_cooldown_s: float = 0.5
var _light_speed_mul: float = 0.85


func _init() -> void:
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	_sprite = Sprite2D.new()
	_sprite.visible = false
	_sprite.show_behind_parent = true # глаза и кольца (_draw родителя) — поверх тела
	add_child(_sprite)
	move_child(_sprite, 0)


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func activate(p_def: EnemyDef, pos: Vector2, elite: bool, hp_mul: float, damage_mul: float, p_manager: EnemyManager, eyes_only_s: float = 0.0) -> void:
	def = p_def
	manager = p_manager
	_cfg = manager.enemies_cfg
	is_elite = elite
	var elite_cfg: Dictionary = _cfg.get("elite", {}) as Dictionary
	var lifecycle: Dictionary = _cfg.get("lifecycle", {}) as Dictionary
	var contact: Dictionary = _cfg.get("contact", {}) as Dictionary
	_spawn_s = float(lifecycle.get("spawn_s", 0.6))
	_death_s = float(lifecycle.get("death_s", 0.48))
	_recoil_pt = float(contact.get("recoil_pt", 24.0))
	_contact_cooldown_s = float(contact.get("cooldown_s", 0.5))
	_light_speed_mul = float((_cfg.get("burn", {}) as Dictionary).get("speed_mul_in_light", 0.85))
	var sizes: Dictionary = _cfg.get("size_pt", {}) as Dictionary
	radius = float(sizes.get(String(def.size_class), 36)) * 0.5 * (float(elite_cfg.get("size_mul", 1.4)) if elite else 1.0)
	max_hp = def.hp * hp_mul * (float(elite_cfg.get("hp_mul", 5.0)) if elite else 1.0)
	hp = max_hp
	base_speed = def.speed * (float(elite_cfg.get("speed_mul", 1.1)) if elite else 1.0)
	damage_pct = def.contact_damage_pct * damage_mul * (float(elite_cfg.get("damage_mul", 1.5)) if elite else 1.0)
	eye_count = int(elite_cfg.get("eye_count", 4)) if elite else def.eye_count
	attack = EnemyAttack.create(def.attack)
	marker = null
	global_position = pos
	velocity = Vector2.ZERO
	separation = Vector2.ZERO
	in_light = false
	_reveal = 0.0
	dmg_acc = 0.0
	dmg_acc_t = 0.0
	contact_cd = 0.0
	burn_after_exit_left = 0.0
	far_t = 0.0
	from_split = false
	entry_freeze_done = false
	_slows.clear()
	_freeze_left = 0.0
	_stun_left = 0.0
	_eyes_only_left = eyes_only_s
	_next_blink = randf_range(3.0, 5.0)
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	_setup_sprite()
	_set_state(State.SPAWN)


func is_alive() -> bool:
	return state != State.DYING and state != State.DESPAWN


func is_targetable() -> bool:
	return is_alive() and state != State.SPAWN


func current_speed() -> float:
	if _freeze_left > 0.0 or _stun_left > 0.0:
		return 0.0
	var slow: float = 0.0
	for pct: float in _slows.values():
		slow = maxf(slow, pct)
	var light_mul: float = _light_speed_mul if in_light else 1.0
	return base_speed * (1.0 - slow / 100.0) * light_mul


# --- Хуки для навыков и скинов (task_4) ---------------------------------------

## Замедление в процентах; источники не складываются — берётся максимум.
func apply_slow(pct: float, source: StringName) -> void:
	_slows[source] = pct


func clear_slow(source: StringName) -> void:
	_slows.erase(source)


func apply_freeze(seconds: float) -> void:
	if def.id == &"extinguisher":
		return
	_freeze_left = maxf(_freeze_left, seconds * (0.5 if is_elite else 1.0))


func apply_knockback(direction: Vector2, force_pt: float) -> void:
	global_position += direction.normalized() * force_pt * (1.0 - def.knockback_resist)


func stun(seconds: float) -> void:
	if is_elite or not is_targetable():
		return
	_stun_left = seconds
	_set_state(State.STUN)


func start_retreat() -> void:
	if state in [State.HUNT, State.BURN]:
		_set_state(State.RETREAT)


## Урон. Возвращает true, если враг погиб от этого удара.
func take_damage(amount: float, count_for_numbers: bool = true) -> bool:
	if not is_targetable() or amount <= 0.0:
		return false
	hp -= amount
	if count_for_numbers:
		dmg_acc += amount
	if hp <= 0.0:
		hp = 0.0
		_die()
		return true
	return false


# --- Тик ---------------------------------------------------------------------

func tick(delta: float, to_player: Vector2, light_radius: float) -> void:
	state_t += delta
	contact_cd = maxf(0.0, contact_cd - delta)
	_freeze_left = maxf(0.0, _freeze_left - delta)
	attack.tick_cooldown(delta)
	_facing = to_player.normalized() if to_player != Vector2.ZERO else _facing
	_tick_blink(delta)

	var was_in_light: bool = in_light
	in_light = to_player.length() <= light_radius + radius * 0.3 and is_targetable()
	_reveal = move_toward(_reveal, 1.0 if in_light else 0.0, delta / 0.15)
	if was_in_light and not in_light and manager.stats_burn_after_exit() > 0.0:
		burn_after_exit_left = manager.stats_burn_after_exit()

	match state:
		State.SPAWN:
			velocity = Vector2.ZERO
			_eyes_only_left = maxf(0.0, _eyes_only_left - delta)
			if state_t >= _spawn_s and _eyes_only_left <= 0.0:
				_set_state(State.HUNT)
		State.HUNT, State.BURN:
			if in_light and state == State.HUNT:
				_set_state(State.REVEAL)
			elif not in_light and state == State.BURN:
				_set_state(State.HUNT)
			else:
				_hunt(to_player, light_radius)
		State.REVEAL:
			velocity = Vector2.ZERO
			if state_t >= 0.15:
				_set_state(State.BURN if in_light else State.HUNT)
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			if marker != null:
				marker.tick(delta, state_t * 1000.0 / maxf(1.0, float(def.telegraph_ms)))
			if state_t * 1000.0 >= def.telegraph_ms:
				manager.release_marker(marker)
				marker = null
				attack.execute(self, manager)
				_set_state(State.ACTIVE)
		State.ACTIVE:
			if not attack.tick_active(self, delta):
				_set_state(State.BURN if in_light else State.HUNT)
		State.RECOIL:
			velocity = _recoil_dir * _recoil_pt / 0.2
			if state_t >= 0.2:
				_set_state(State.BURN if in_light else State.HUNT)
		State.STUN:
			velocity = Vector2.ZERO
			_stun_left -= delta
			rotation = sin(state_t * 30.0) * deg_to_rad(15.0)
			if _stun_left <= 0.0:
				rotation = 0.0
				_set_state(State.BURN if in_light else State.HUNT)
		State.RETREAT:
			velocity = -to_player.normalized() * base_speed * 0.6
		State.DYING:
			velocity = Vector2.ZERO
			if state_t >= _death_s:
				manager.release_enemy(self)
				return
		State.DESPAWN:
			velocity = Vector2.ZERO
			if state_t >= 0.2:
				manager.release_enemy(self)
				return

	if is_alive() and state != State.SPAWN:
		attack.tick_passive(self, delta, manager)
		_check_contact(to_player)
	_move(delta)
	_update_sprite(delta)
	queue_redraw()


func _setup_sprite() -> void:
	var tex: CanvasTexture = EnemyVisuals.texture_for(def.id)
	_sprite.visible = tex != null
	if tex == null:
		return
	_sprite.texture = tex
	_sprite.hframes = EnemyVisuals.frame_count(def.id)
	_sprite.material = EnemyVisuals.material_for(def.id)
	_frame_px = float(tex.diffuse_texture.get_height())
	_anim_t = randf() * 2.0
	_sprite.modulate = Color.WHITE
	_sprite.scale = Vector2.ONE * (radius * 2.0 / _frame_px)


## Кадр анимации, разворот к игроку, сквош фаз, растворение при смерти (альфа modulate = прогресс).
func _update_sprite(delta: float) -> void:
	if not _sprite.visible and _sprite.texture == null:
		return
	_anim_t += delta
	_sprite.frame = int(_anim_t * EnemyVisuals.FPS) % _sprite.hframes
	_sprite.flip_h = _facing.x < 0.0
	var base: float = radius * 2.0 / _frame_px
	var squash: Vector2 = Vector2.ONE
	var dissolve: float = 0.0
	match state:
		State.SPAWN:
			var appear: float = clampf(state_t / 0.4, 0.0, 1.0)
			squash = Vector2.ONE * lerpf(0.6, 1.0, appear)
		State.TELEGRAPH:
			squash = Vector2.ONE * (0.92 if def.id != &"devourer" else 1.12)
		State.REVEAL:
			squash = Vector2(1.1, 0.9)
		State.DYING:
			dissolve = clampf(state_t / _death_s, 0.0, 1.0)
			squash = Vector2.ONE * (1.0 + dissolve * 0.15)
		State.DESPAWN:
			squash = Vector2.ONE * (1.0 - state_t / 0.2)
	_sprite.visible = _eyes_only_left <= 0.0
	_sprite.scale = squash * base
	_sprite.modulate = Color(1, 1, 1, 1.0 - dissolve)


func begin_despawn() -> void:
	if is_alive():
		_set_state(State.DESPAWN)


func _hunt(to_player: Vector2, light_radius: float) -> void:
	if attack.can_start(self, to_player):
		var needs_marker: bool = attack.marker_kind() != &"none" and attack.marker_kind() != &"zone"
		var m: TelegraphMarker = manager.acquire_marker() if needs_marker else null
		if not needs_marker or m != null:
			marker = m
			if m != null:
				attack.on_telegraph(self, to_player, m)
			FeedbackManager.telegraph(def.id)
			_set_state(State.TELEGRAPH)
			return
	velocity = attack.hunt_velocity(self, to_player, light_radius) + separation


func _check_contact(to_player: Vector2) -> void:
	if contact_cd > 0.0 or state == State.STUN:
		return
	if to_player.length() > radius + manager.player_body_radius():
		return
	contact_cd = _contact_cooldown_s
	if manager.try_instant_burn(self):
		return
	if damage_pct > 0.0:
		manager.hit_player(self, &"contact")
	_recoil_dir = -to_player.normalized()
	if state not in [State.TELEGRAPH, State.ACTIVE]:
		_set_state(State.RECOIL)


func _move(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	var step: Vector2 = velocity * delta
	var target: Vector2 = global_position + step
	if not manager.is_blocked(target):
		global_position = target
	elif not manager.is_blocked(global_position + Vector2(step.x, 0.0)):
		global_position += Vector2(step.x, 0.0)
	elif not manager.is_blocked(global_position + Vector2(0.0, step.y)):
		global_position += Vector2(0.0, step.y)


func _die() -> void:
	if marker != null:
		marker.cancel()
		manager.release_marker(marker)
		marker = null
	_set_state(State.DYING)
	manager.on_enemy_killed(self)


func _set_state(new_state: State) -> void:
	state = new_state
	state_t = 0.0


func _tick_blink(delta: float) -> void:
	_blink_t += delta
	if _blink_t >= _next_blink + 0.12:
		_blink_t = 0.0
		_next_blink = randf_range(3.0, 5.0)


# --- Отрисовка ----------------------------------------------------------------

func _draw() -> void:
	var appear: float = clampf(state_t / 0.4, 0.0, 1.0) if state == State.SPAWN else 1.0
	var body_alpha: float = appear
	if _eyes_only_left > 0.0:
		body_alpha = 0.0
	var body: Color = BODY
	var squash: Vector2 = Vector2.ONE
	match state:
		State.DYING:
			var t: float = state_t / 0.48
			body = HOT if state_t < 0.08 else HOT.lerp(Color(HOT, 0.0), t)
			squash = Vector2.ONE * (1.0 + t * 0.4)
		State.TELEGRAPH:
			squash = Vector2.ONE * (0.92 if def.id != &"devourer" else 1.12)
		State.REVEAL:
			squash = Vector2(1.1, 0.9)
		State.DESPAWN:
			body_alpha = 1.0 - state_t / 0.2
	var r: float = radius
	if attack is DarkAuraAttack and is_alive():
		var aura: DarkAuraAttack = attack as DarkAuraAttack
		if aura.disabled_left <= 0.0:
			var zone_r: float = aura.aura_radius(self)
			draw_circle(Vector2.ZERO, zone_r, Color(0.02, 0.02, 0.04, 0.35 * appear))
			for i: int in 24:
				var a: float = TAU * i / 24.0
				draw_arc(Vector2.ZERO, zone_r, a, a + TAU / 48.0, 4, Color(ELITE_RIM, appear), 1.5)
	if body_alpha > 0.0:
		if _sprite.texture == null:
			_draw_body(Vector2.ZERO, r * squash.x, Color(body, body_alpha))
			if in_light or _reveal > 0.0:
				_draw_rim(r, _reveal)
				_draw_cracks(r)
		if is_elite:
			draw_arc(Vector2.ZERO, r + 1.0, 0.0, TAU, 32, ELITE_RIM, 2.0)
	if state != State.DYING:
		_draw_eyes(r, appear)


func _draw_body(center: Vector2, r: float, color: Color) -> void:
	match def.id:
		&"reaper":
			var tip: Vector2 = _facing * r * 1.3
			var side: Vector2 = _facing.orthogonal() * r * 0.8
			draw_colored_polygon(PackedVector2Array([center + tip, center - _facing * r * 0.7 + side, center - _facing * r * 0.7 - side]), color)
		&"devourer":
			draw_circle(center + Vector2(0, -r * 0.1), r, color)
			draw_rect(Rect2(center + Vector2(-r, 0), Vector2(r * 2.0, r * 0.7)), color)
		_:
			draw_circle(center, r, color)
			draw_circle(center, r * 0.55, Color(CORE, color.a))


func _draw_rim(r: float, strength: float) -> void:
	var angle: float = _facing.angle()
	draw_arc(Vector2.ZERO, r, angle - 1.1, angle + 1.1, 16, Color(rim_color, strength), lerpf(3.0, 6.0, strength))


func _draw_cracks(r: float) -> void:
	var lost: float = 1.0 - hp / maxf(1.0, max_hp)
	var count: int = floori(lost * 8.0)
	var base_angle: float = _facing.angle()
	for i: int in count:
		var a: float = base_angle + (i - count * 0.5) * 0.35
		var start: Vector2 = Vector2.from_angle(a) * r
		draw_line(start, start.lerp(Vector2.ZERO, 0.3 + lost * 0.5), CRACK, 1.5)


func _draw_eyes(r: float, open: float) -> void:
	var blink: float = 0.1 if _blink_t > _next_blink else 1.0
	var eye_r: float = maxf(2.0, r * 0.16)
	var spread: float = r * 0.36
	var y: float = -r * 0.15
	var white: bool = state == State.TELEGRAPH
	for i: int in eye_count:
		var x: float = (i - (eye_count - 1) * 0.5) * spread
		var center: Vector2 = Vector2(x, y + (absf(x) * 0.15 if eye_count > 2 else 0.0))
		if state == State.STUN:
			draw_line(center - Vector2(eye_r, 0), center + Vector2(eye_r, 0), EYE, 2.0)
			continue
		var color: Color = Color.WHITE if white else EYE
		if white:
			draw_circle(center, eye_r * 1.8, Color(EYE, 0.35))
		var squash: Vector2 = Vector2(1.0, open * blink)
		if def.id == &"reaper":
			squash.y *= 0.45
		draw_set_transform(center, 0.0, squash)
		draw_circle(Vector2.ZERO, eye_r, color)
		draw_circle(Vector2(-eye_r * 0.35, -eye_r * 0.35), eye_r * 0.25, EYE_GLINT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
