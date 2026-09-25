class_name EmberButton
extends Control
## «В БОЙ» — горящий уголь (DS §02, Art Direction §03): круглая кнопка над таб-баром, дышит 1.2 с
## в ритме Огонька. В хабе 78pt с G2; на вне-хабовых вкладках 62pt и без свечения. glow_enabled = false,
## когда свечение передано другому главному действию (Meta DS: «Внести Искры»).

signal pressed

@export var diameter: float = UITokens.EMBER_HUB
@export var glow_enabled: bool = true

var _pressed: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var down: bool = false
	var up: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = (event as InputEventMouseButton).pressed
		up = not down
	elif event is InputEventScreenTouch:
		down = (event as InputEventScreenTouch).pressed
		up = not down
	if down:
		_pressed = true
		accept_event()
	elif up and _pressed:
		_pressed = false
		accept_event()
		if Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
			FeedbackManager.haptic(&"medium")
			pressed.emit()


const SPHERE: Texture2D = preload("res://src/assets/brand/ember_sphere.png")


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var breath: float = TimeService.breath_phase() if glow_enabled else 0.0
	var r: float = diameter * 0.5 * (1.0 + 0.04 * breath) * (0.96 if _pressed else 1.0)
	if glow_enabled:
		var halo: float = r + 30.0 # G2 · 30/8
		draw_texture_rect(HeroGlyph.halo_texture(), Rect2(center - Vector2.ONE * halo, Vector2.ONE * halo * 2.0), false, Color(UITokens.LIGHT_500, 0.55 + 0.25 * breath))
	draw_circle(center + Vector2(0, 3), r, UITokens.LIGHT_900, true, -1.0, true)
	# Объёмная сфера: блик light.300 сверху-слева → light.500 → light.700 к низу (текстура, без ступенек).
	draw_texture_rect(SPHERE, Rect2(center - Vector2.ONE * r, Vector2.ONE * r * 2.0), false)
	var font: Font = UIFonts.font(&"button")
	var font_size: int = 15 if diameter >= UITokens.EMBER_HUB else 12
	var text: String = tr("В БОЙ")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UITokens.TEXT_ON_LIGHT)
