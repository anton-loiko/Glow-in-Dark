extends SkillBehavior
## ▲ Луч Света: раз в 2.5 с мгновенный луч в ближайшего врага, 60 урона, всегда крит;
## +1 луч за уровень в разных врагов (приоритет — ближайший, затем тяжёлые).

const BEAM_S: float = 0.14

var _timer: float = 0.0
var _beams: Array[Vector2] = []
var _beam_age: float = 1.0


func setup(p_host: SkillHost, p_def: SkillDef) -> void:
	super.setup(p_host, p_def)
	top_level = true


func reset_cooldown() -> void:
	_timer = 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	_beam_age += delta
	if _timer <= 0.0 and not host.player.is_dead():
		var origin: Vector2 = host.player.global_position
		var targets: Array[Enemy] = host.enemies.pick_targets(origin, int(param("count", 1)), host.player.light_radius() * 1.6)
		if not targets.is_empty():
			_timer = cooldown(float(param("cooldown_s", 2.5)))
			_beams.clear()
			var damage: float = float(param("damage", 60))
			for enemy: Enemy in targets:
				_beams.append(enemy.global_position)
				var pos: Vector2 = enemy.global_position
				enemy.take_damage(damage, false)
				EventBus.damage_dealt.emit(roundi(damage), pos + Vector2(0, -enemy.radius), DamageNumber.Style.LETHAL)
			_beam_age = 0.0
			if level >= 5:
				host.camera.shake(1.5, 0.1)
	queue_redraw()


func _draw() -> void:
	if _beam_age > BEAM_S:
		return
	var origin: Vector2 = host.player.global_position
	var t: float = _beam_age / BEAM_S
	var width: float = (3.0 + 5.0 * sin(t * PI)) * (1.0 - t * 0.5)
	for target: Vector2 in _beams:
		draw_line(origin, target, Color(host.player.visual.light_color, 0.6), width * 2.0)
		draw_line(origin, target, Color.WHITE, width * 0.5)
