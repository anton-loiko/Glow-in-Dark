class_name HeroGlyph
extends Control
## Огонёк в UI (кукла S12, S14, лента скинов): ядро hero.core + пламя цвета скина + ореол G-уровня.
## Слои из бренд-пака (tools/brand/make_brand.py): нейтральное тело красится цветом скина, ядро и лицо — без окраски,
## ореол — гладкий радиальный градиент (без ступенек концентрических кругов).

const BODY: Texture2D = preload("res://src/assets/brand/hero_ui_body.png")
const FACE: Texture2D = preload("res://src/assets/brand/hero_ui_face.png")
## Капля на холсте 256: круг r = 64 с центром (128, 156).
const CANVAS: float = 256.0
const DROP_R: float = 64.0
const DROP_CENTER: Vector2 = Vector2(128, 156)

static var _halo: GradientTexture2D

var color: Color = UITokens.LIGHT_500
var diameter: float = 62.0
var glow: int = UITokens.G2
var breathe: bool = true
var squash: float = 1.0 ## «кивок» после надевания (0.95 → 1)


static func halo_texture() -> GradientTexture2D:
	if _halo == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.55))
		g.set_color(1, Color(1, 1, 1, 0.0))
		g.add_point(0.4, Color(1, 1, 1, 0.18))
		_halo = GradientTexture2D.new()
		_halo.gradient = g
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5, 0.5)
		_halo.fill_to = Vector2(1.0, 0.5)
		_halo.width = 128
		_halo.height = 128
	return _halo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(diameter, diameter) * 1.6


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5 + Vector2(0, diameter * 0.15)
	var breath: float = TimeService.breath_phase() if breathe else 0.5
	var r: float = diameter * 0.5 * (1.0 + 0.03 * breath)
	var halo_r: float = r + glow * 1.6 + r * 0.6
	draw_texture_rect(halo_texture(), Rect2(c - Vector2.ONE * halo_r, Vector2.ONE * halo_r * 2.0), false, Color(color, 0.55 + 0.2 * breath))
	var scale_k: float = r / DROP_R
	draw_set_transform(c, 0.0, Vector2(1.0 / squash, squash) * scale_k)
	var rect: Rect2 = Rect2(-DROP_CENTER, Vector2.ONE * CANVAS)
	draw_texture_rect(BODY, rect, false, color.lightened(0.15))
	draw_texture_rect(FACE, rect, false)
	draw_set_transform(Vector2.ZERO)
