extends SkillBehavior
## ▲ Пульсар: раз в 4 с (ур.3: 3.2 с) волна радиусом 60% света — урон, отброс, оглушение;
## ур.4 — две волны с шагом 250 мс; ур.5 — оглушение 1.2 с.

var _timer: float = 0.0
var _rings: Array[float] = [] ## возраст колец, с


func reset_cooldown() -> void:
	_timer = 0.0


func _physics_process(delta: float) -> void:
	global_position = host.player.global_position
	_timer -= delta
	if _timer <= 0.0 and not host.player.is_dead():
		_timer = cooldown(float(param("cooldown_s", 4.0)))
		_fire()
		if int(param("waves", 1)) > 1:
			get_tree().create_timer(0.25, false).timeout.connect(_fire)
	for i: int in range(_rings.size() - 1, -1, -1):
		_rings[i] += delta
		if _rings[i] > 0.22:
			_rings.remove_at(i)
	queue_redraw()


func _fire() -> void:
	var radius: float = _radius()
	for enemy: Enemy in host.enemies.enemies_in_radius(host.player.global_position, radius):
		enemy.take_damage(float(param("damage", 25)))
		enemy.apply_knockback(enemy.global_position - host.player.global_position, float(param("knockback_pt", 80)))
		enemy.stun(float(param("stun_s", 0.6)))
	_rings.append(0.0)
	if level >= 4:
		host.camera.shake(2.0, 0.12)


func _radius() -> float:
	return host.player.light_radius() * float(param("radius_pct", 60)) / 100.0


func _draw() -> void:
	var color: Color = host.player.visual.light_color.lerp(Color.WHITE, 0.5)
	for age: float in _rings:
		var t: float = age / 0.22
		draw_arc(Vector2.ZERO, _radius() * (0.3 + 0.7 * t), 0.0, TAU, 48, Color(color, 1.0 - t), 4.0 if level < 2 else 6.0)
