extends SkillBehavior
## ▲ Орбитальные Сферы: сгустки света на орбите 90pt (× Линза), урон при пролёте, КД на врага 0.5 с;
## ур.5 — вторая сфера симметрично.

const ORBIT_PT: float = 90.0
const ORB_RADIUS: float = 10.0
const HIT_CD_S: float = 0.5

var _angle: float = 0.0
var _hit_cd: Dictionary = {} ## Enemy -> секунды до следующего удара


func _physics_process(delta: float) -> void:
	global_position = host.player.global_position
	_angle = fmod(_angle + TAU / float(param("period_s", 2.0)) * delta, TAU)
	for enemy: Variant in _hit_cd.keys():
		_hit_cd[enemy] = float(_hit_cd[enemy]) - delta
		if float(_hit_cd[enemy]) <= 0.0:
			_hit_cd.erase(enemy)
	var orbit: float = ORBIT_PT * host.player.stats.area_scale
	for i: int in int(param("count", 1)):
		var pos: Vector2 = global_position + Vector2.from_angle(_angle + PI * i) * orbit
		for enemy: Enemy in host.enemies.enemies_in_radius(pos, ORB_RADIUS):
			if not _hit_cd.has(enemy):
				_hit_cd[enemy] = HIT_CD_S
				enemy.take_damage(float(param("damage", 30)))
	queue_redraw()


func _draw() -> void:
	var orbit: float = ORBIT_PT * host.player.stats.area_scale
	var color: Color = host.player.visual.light_color
	var trail: float = deg_to_rad(60.0 + 20.0 * (level - 1))
	for i: int in int(param("count", 1)):
		var a: float = _angle + PI * i
		draw_arc(Vector2.ZERO, orbit, a - trail, a, 16, Color(color, 0.35), 3.0)
		draw_circle(Vector2.from_angle(a) * orbit, ORB_RADIUS + 3.0, Color(color, 0.35))
		draw_circle(Vector2.from_angle(a) * orbit, ORB_RADIUS, Color.WHITE.lerp(color, 0.3))
