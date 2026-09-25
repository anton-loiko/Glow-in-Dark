class_name PlayerVisual
extends Node2D
## Визуал Огонька (Art Direction §02, GDD 7.2): hi-res слои src/assets/hero — тело (белое, цвет скина через
## modulate), раскалённое ядро, 4 эмоции глаз. Огонёк сам источник света — слои unshaded.
## Дыхание 1.2 с, squash & stretch по скорости, остывание и мерцание при HP < 25%, вспышка при уроне.

enum Mood { CALM, FOCUSED, SCARED, HAPPY }

const COLD_COLOR: Color = Color("#8FA3C0")

@export var body_radius: float = 20.0

var light_color: Color = Color("#FFB547")
var mood: Mood = Mood.CALM
var velocity: Vector2 = Vector2.ZERO
var max_speed: float = 110.0
var stretch_bonus: float = 0.0 ## +4% за уровень Ускорения (task_4)
var danger: bool = false

var _hurt_left: float = 0.0
var _happy_left: float = 0.0
var _body: Sprite2D
var _core: Sprite2D
var _eyes: Sprite2D

const BODY_TEX: Texture2D = preload("res://src/assets/hero/hero_body.png")
const CORE_TEX: Texture2D = preload("res://src/assets/hero/hero_core.png")
const EYES_TEX: Dictionary = {
	Mood.CALM: preload("res://src/assets/hero/hero_eyes_calm.png"),
	Mood.FOCUSED: preload("res://src/assets/hero/hero_eyes_focused.png"),
	Mood.SCARED: preload("res://src/assets/hero/hero_eyes_scared.png"),
	Mood.HAPPY: preload("res://src/assets/hero/hero_eyes_happy.png"),
}
## Геометрия исходника 170×170: центр круга тела (85, 104), радиус 50 px.
const SRC_BODY_R: float = 50.0
const SRC_BODY_CENTER_Y: float = 104.0


func _ready() -> void:
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded # ореол «Сверхновой» (_draw) — тоже источник света, не освещается
	_body = _layer(BODY_TEX, unshaded)
	_core = _layer(CORE_TEX, unshaded)
	_eyes = _layer(EYES_TEX[Mood.CALM], unshaded)
	_orbits = Node2D.new()
	_orbits.use_parent_material = true
	_orbits.draw.connect(_draw_orbits)
	add_child(_orbits)
	_flame = ColorRect.new()
	_flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = FLAME_SHADER
	_flame.material = _flame_mat
	_flame.visible = false
	add_child(_flame)
	move_child(_flame, 0) # пламя за телом: растёт из макушки
	EventBus.skill_selected.connect(_on_skill_selected)
	EventBus.run_started.connect(_on_run_started)


# --- «Сверхновая» (Art Direction §02): каждый навык добавляет слой, по силуэту виден билд ---

const FLAME_SHADER: Shader = preload("res://src/gameplay/shaders/flame.gdshader")

var _orbits: Node2D
var _flame: ColorRect
var _flame_mat: ShaderMaterial
var _halo: float = 0.0 ## 0..1
var _orbit_colors: Array[Color] = []
var _flame_power: float = 0.0


func _on_run_started(_run_id: String, _chapter_id: int) -> void:
	update_build({})


func _on_skill_selected(_skill_id: StringName, _level_to: int) -> void:
	if GameManager.current_run != null:
		update_build(GameManager.current_run.skills)


## Пересчёт слоёв по навыкам забега: ореол со 2-го навыка, искра-спутник на каждые N уровней (цвет категории
## навыка), пламя на макушке с порога суммарных уровней.
func update_build(skills: Dictionary) -> void:
	var cfg: Dictionary = ConfigDB.get_balance().get("supernova", {}) as Dictionary
	var total: int = 0
	var per_category: Array[Color] = []
	var ids: Array = skills.keys()
	ids.sort()
	for id: Variant in ids:
		var level: int = int(skills[id])
		total += level
		var def: SkillDef = SkillsManager.get_def(StringName(str(id)))
		var tokens: Dictionary = UITokens.CATEGORY.get(def.category if def != null else &"utility", UITokens.CATEGORY[&"utility"]) as Dictionary
		for i: int in level:
			per_category.append(tokens["500"])
	_halo = 1.0 if skills.size() >= int(cfg.get("halo_from_skills", 2)) else 0.0
	var per_orbit: int = maxi(1, int(cfg.get("levels_per_orbit", 3)))
	var count: int = mini(int(cfg.get("max_orbits", 8)), floori(float(total) / per_orbit))
	_orbit_colors.clear()
	for i: int in count:
		_orbit_colors.append(per_category[mini(per_category.size() - 1, i * per_orbit)])
	var from: float = float(cfg.get("flame_from_levels", 10))
	var full: float = float(cfg.get("flame_full_levels", 24))
	_flame_power = clampf((total - from) / maxf(1.0, full - from), 0.0, 1.0) if total >= from else -1.0
	_flame.visible = _flame_power >= 0.0


func _draw() -> void:
	if _halo <= 0.0:
		return
	var breath: float = TimeService.breath_phase()
	var r: float = body_radius * (1.55 + 0.05 * breath)
	draw_arc(Vector2(0, body_radius * 0.15), r, 0.0, TAU, 48, Color(light_color, 0.35), 2.0)
	draw_arc(Vector2(0, body_radius * 0.15), r + 3.0, 0.0, TAU, 48, Color(light_color, 0.12), 4.0)


func _draw_orbits() -> void:
	var n: int = _orbit_colors.size()
	if n == 0:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var r: float = body_radius * 1.9
	for i: int in n:
		var a: float = t * 1.6 + TAU * i / n
		# Орбита в мировой ориентации: компенсируем поворот и сквош тела.
		var p: Vector2 = (Vector2.from_angle(a) * Vector2(r, r * 0.55)).rotated(-rotation) / scale
		_orbits.draw_circle(p, 4.5, Color(_orbit_colors[i], 0.25))
		_orbits.draw_circle(p, 2.2, _orbit_colors[i])
		_orbits.draw_circle(p, 1.0, Color.WHITE)


func _update_supernova() -> void:
	if _halo > 0.0:
		queue_redraw()
	if not _orbit_colors.is_empty():
		_orbits.queue_redraw()
	if _flame.visible:
		var w: float = body_radius * lerpf(1.2, 1.8, _flame_power)
		var h: float = body_radius * lerpf(1.3, 2.4, _flame_power)
		_flame.size = Vector2(w, h)
		# Кончик капли — на ~1.25 радиуса над центром тела; пламя стоит на нём.
		_flame.position = Vector2(-w * 0.5, -body_radius * 1.05 - h + body_radius * 0.35)
		_flame_mat.set_shader_parameter(&"color", light_color)
		_flame_mat.set_shader_parameter(&"intensity", _flame_power)


func _layer(tex: Texture2D, mat: Material) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.material = mat
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	_hurt_left = maxf(0.0, _hurt_left - delta)
	_happy_left = maxf(0.0, _happy_left - delta)
	var breath: float = TimeService.breath_phase()
	var speed_ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.0, 1.0)
	var stretch: float = 1.0 + speed_ratio * (0.12 + stretch_bonus)
	var squash: float = 1.0 / stretch
	var base_scale: float = 1.0 + 0.04 * breath
	if speed_ratio > 0.05:
		rotation = velocity.angle() + PI * 0.5
		scale = Vector2(squash, stretch) * base_scale
	else:
		rotation = lerp_angle(rotation, 0.0, minf(1.0, delta * 8.0))
		scale = Vector2.ONE * base_scale
	_update_layers()


func play_hurt() -> void:
	_hurt_left = 0.12


func play_happy(seconds: float = 1.0) -> void:
	_happy_left = seconds


func _current_mood() -> Mood:
	if _happy_left > 0.0:
		return Mood.HAPPY
	if danger:
		return Mood.SCARED
	return mood


## Цвет тела, остывание при HP < 25%, вспышка урона, эмоция глаз; масштаб слоёв под body_radius.
func _update_layers() -> void:
	if _body == null:
		return
	var color: Color = light_color
	if danger:
		var flicker: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.037) * sin(Time.get_ticks_msec() * 0.011)
		color = light_color.lerp(COLD_COLOR, 0.7) * Color(flicker, flicker, flicker, 1.0)
	if _hurt_left > 0.0:
		color = color.lerp(Color.WHITE, 0.6)
	var k: float = body_radius / SRC_BODY_R
	var offset: Vector2 = Vector2(0, -(SRC_BODY_CENTER_Y - 85.0) + body_radius * 0.15 / k)
	for layer: Sprite2D in [_body, _core, _eyes]:
		layer.scale = Vector2.ONE * k
		layer.offset = offset
	_body.modulate = color
	_eyes.texture = EYES_TEX[_current_mood()]
	_update_supernova()
