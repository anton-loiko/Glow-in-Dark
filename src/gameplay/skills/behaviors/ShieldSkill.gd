extends SkillBehavior
## ■ Щит: урон касаний −10…−30% (естественное затухание не трогает); ур.5 — +1 света каждые 5 с.

const HEX_SHADER: Shader = preload("res://src/gameplay/shaders/shield_hex.gdshader")

var _regen_t: float = 0.0
var _bubble: ColorRect
var _bubble_mat: ShaderMaterial
var _hit: float = 0.0


func _ready() -> void:
	_bubble = ColorRect.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = HEX_SHADER
	_bubble.material = _bubble_mat
	add_child(_bubble)
	EventBus.player_damaged.connect(_on_player_damaged)


func _on_player_damaged(_amount: float, _source: StringName) -> void:
	_hit = 1.0


func modify_stats(stats: StatBlock, p_base: StatBlock) -> void:
	stats.contact_damage_mult = p_base.contact_damage_mult * (1.0 - float(param("reduction_pct", 0)) / 100.0)


func _physics_process(delta: float) -> void:
	# Hex-пузырь вокруг Огонька; удар — вспышка сот.
	global_position = host.player.global_position
	var size: float = host.player.visual.body_radius * 3.2
	_bubble.size = Vector2(size, size)
	_bubble.position = -_bubble.size * 0.5
	_hit = maxf(0.0, _hit - delta * 3.0)
	_bubble_mat.set_shader_parameter(&"hit", _hit)
	var regen: float = float(param("regen_per_5s", 0))
	if regen <= 0.0:
		return
	_regen_t += delta
	if _regen_t >= 5.0:
		_regen_t = 0.0
		host.player.light_model.heal(regen)
