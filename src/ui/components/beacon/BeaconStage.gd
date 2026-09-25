class_name BeaconStage
extends Control
## Диорама Маяка (Meta DS §01): вид по тиру из beacon_config.stage, кольцо из 10 рун по уровням тира,
## радиус света хаба = прогресс. Временная процедурная отрисовка до hi-res спрайтов (task_8).
## Между тирами параметры не интерполируются — переключаются под вспышкой кат-сцены.

var chapter_id: int = 1
var pulse: float = 0.0 ## вспышка кристалла на каждое внесение (+6% эмиссии)

var _level: int = 0
var _diorama: HubDiorama
## Свет хаба окрашен скином (Meta DS §03: «скин перекрашивает весь кадр»); смена — плавно за 600 мс.
var hub_color: Color = UITokens.LIGHT_500


static func skin_color() -> Color:
	var skin: SkinDef = ConfigDB.get_skin(GameManager.profile.skin_equipped)
	return skin.light_color if skin != null else UITokens.LIGHT_500


func _on_skin_equipped(_id: StringName) -> void:
	var t: Tween = UIMotion.tween(self)
	t.tween_property(self, ^"hub_color", skin_color(), 0.6)

## Hi-res ассеты (tools/art/gen_sprites.lua, свет запечён): постамент 160×80pt, кристалл 48×80pt × 12 кадров вращения.
const ART_DIR: String = "res://src/assets/beacon/"
const CRYSTAL_FRAMES: int = 12
static var _art: Dictionary = {}


static func art(file: String) -> Texture2D:
	if not _art.has(file):
		var path: String = ART_DIR + file + ".png"
		_art[file] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _art[file]


func refresh() -> void:
	_level = BeaconService.level(GameManager.profile, chapter_id)
	queue_redraw()


func flash_rune() -> void:
	pulse = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	hub_color = skin_color()
	EventBus.skin_equipped.connect(_on_skin_equipped)
	_diorama = HubDiorama.new()
	if _diorama.setup(chapter_id):
		_diorama.show_behind_parent = true
		_diorama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_diorama)
	else:
		_diorama = null
	refresh()


func _process(delta: float) -> void:
	pulse = maxf(0.0, pulse - delta * 3.0)
	queue_redraw()


func tier() -> int:
	return floori(float(_level) / BeaconService.levels_per_tier())


func _params() -> Dictionary:
	var stage: Array = BeaconService.config().get("stage", [])
	return stage[clampi(tier(), 0, stage.size() - 1)] as Dictionary


func _draw() -> void:
	var p: Dictionary = _params()
	var t: float = Time.get_ticks_msec() / 1000.0
	var breath: float = TimeService.breath_phase() if bool(p.get("breath", false)) else 0.5
	var base: Vector2 = Vector2(size.x * 0.5, size.y * 0.78)
	var hub_light: Array = BeaconService.config().get("hub_light", [0.0])
	var light_r: float = float(hub_light[clampi(tier(), 0, hub_light.size() - 1)]) * size.x
	if _diorama != null:
		_diorama.anchor_point = base + Vector2(0, -10)
		_diorama.set_light(maxf(40.0, light_r), 1.0 if tier() >= 10 else 0.0, breath, hub_color)
	# Свет Хаба: радиус = прогресс.
	var glow_r: float = maxf(24.0, light_r)
	draw_texture_rect(HeroGlyph.halo_texture(), Rect2(base + Vector2(0, -60) - Vector2.ONE * glow_r, Vector2.ONE * glow_r * 2.0), false, Color(hub_color, 0.3 + 0.1 * breath))
	if tier() == 0:
		for i: int in 4:
			var eye: Vector2 = base + Vector2.from_angle(PI + i * PI / 3.5 + 0.2) * Vector2(150, 90)
			draw_circle(eye + Vector2(-5, 0), 2.5, UITokens.THREAT)
			draw_circle(eye + Vector2(5, 0), 2.5, UITokens.THREAT)
	_draw_pedestal(base, str(p.get("pedestal", "ruins")))
	_draw_runes(base)
	var emission: float = float(p.get("emission", 0.0)) + pulse * 0.06
	var float_y: float = float(p.get("float_y", 0)) + 4.0 * sin(t * TAU / 3.0) * signf(float(p.get("float_y", 0)))
	var crystal_c: Vector2 = base + Vector2(0, -78 - float_y)
	var beam: float = float(p.get("beam", 0))
	if beam > 0.0:
		draw_line(crystal_c + Vector2(0, -40), Vector2(crystal_c.x, 0), Color(UITokens.RUNE, 0.35), beam * 2.0)
		draw_line(crystal_c + Vector2(0, -40), Vector2(crystal_c.x, 0), Color(1, 1, 1, 0.8), maxf(1.0, beam * 0.5))
	var aura: float = float(p.get("aura", 0.0))
	if aura > 0.0:
		for i: int in 5:
			draw_circle(crystal_c, 40.0 + i * 10.0 + 6.0 * breath, Color(UITokens.RUNE, aura * 0.12 * (1.0 - i / 5.0)))
	_draw_crystal(crystal_c, str(p.get("crystal", "shards")), emission, float(p.get("rot_s", 0)), t)
	_draw_motes(base, int(p.get("motes", 0)), t)


func _draw_pedestal(base: Vector2, kind: String) -> void:
	var tex: Texture2D = art("pedestal_" + kind)
	if tex != null:
		draw_texture_rect(tex, Rect2(base - Vector2(80, 74), Vector2(160, 80)), false)
		return
	var body: Color = UITokens.INK_600
	match kind:
		"ruins":
			draw_colored_polygon(PackedVector2Array([base + Vector2(-70, 0), base + Vector2(-40, -18), base + Vector2(-10, -6), base + Vector2(-20, 0)]), body)
			draw_colored_polygon(PackedVector2Array([base + Vector2(10, 0), base + Vector2(35, -22), base + Vector2(70, -4), base + Vector2(60, 0)]), body)
		_:
			draw_rect(Rect2(base + Vector2(-72, -22), Vector2(144, 22)), body)
			draw_rect(Rect2(base + Vector2(-54, -40), Vector2(108, 18)), UITokens.LINE_STRONG)
			if kind == "cracked":
				draw_line(base + Vector2(-30, -22), base + Vector2(-18, -4), UITokens.INK_900, 2.0)
				draw_line(base + Vector2(24, -40), base + Vector2(36, -24), UITokens.INK_900, 2.0)
			if kind in ["armored", "radiant"]:
				draw_rect(Rect2(base + Vector2(-74, -26), Vector2(148, 5)), UITokens.TEXT_MUTED)
				draw_rect(Rect2(base + Vector2(-74, -8), Vector2(148, 5)), UITokens.TEXT_MUTED)
			if kind in ["runes", "armored", "radiant"]:
				for i: int in 4:
					draw_circle(base + Vector2(-42 + i * 28, -31), 4.0, Color(UITokens.RUNE, 0.9))


## Кольцо из 10 рун — «10 зажжённых элементов» тира (Meta DS §00).
func _draw_runes(base: Vector2) -> void:
	var lit: int = _level % BeaconService.levels_per_tier()
	if BeaconService.is_max(GameManager.profile, chapter_id):
		lit = BeaconService.levels_per_tier()
	for i: int in BeaconService.levels_per_tier():
		var angle: float = PI + PI * (i + 0.5) / BeaconService.levels_per_tier()
		var pos: Vector2 = base + Vector2(0, -8) + Vector2.from_angle(angle) * Vector2(96, 30)
		if i < lit:
			draw_circle(pos, 6.0, Color(UITokens.RUNE, 0.3))
			draw_circle(pos, 3.5, UITokens.RUNE)
		else:
			draw_arc(pos, 3.5, 0.0, TAU, 12, UITokens.LINE_STRONG, 1.0)


func _draw_crystal(c: Vector2, kind: String, emission: float, rot_s: float, t: float) -> void:
	var tex: Texture2D = art("crystal_" + kind)
	if tex != null:
		var glow: float = 1.0 + pulse * 0.3 + emission * 0.1
		if kind == "shards":
			draw_texture_rect(tex, Rect2(c + Vector2(-24, 2), Vector2(48, 80)), false)
			return
		var frame: int = int(t / rot_s * CRYSTAL_FRAMES) % CRYSTAL_FRAMES if rot_s > 0.0 else 0
		var fw: float = tex.get_width() / float(CRYSTAL_FRAMES)
		draw_texture_rect_region(tex, Rect2(c - Vector2(24, 40), Vector2(48, 80)), Rect2(frame * fw, 0, fw, tex.get_height()), Color(glow, glow, glow, 1.0))
		return
	if kind == "shards":
		for offset: Vector2 in [Vector2(-30, 70), Vector2(4, 74), Vector2(34, 68)]:
			var s: Vector2 = c + offset
			draw_colored_polygon(PackedVector2Array([s + Vector2(0, -10), s + Vector2(6, 4), s + Vector2(-6, 4)]), UITokens.LINE_STRONG)
		return
	var width: float = 34.0
	if rot_s > 0.0:
		width *= 0.55 + 0.45 * absf(cos(t * TAU / rot_s))
	var color: Color = UITokens.INK_600.lerp(UITokens.RUNE, clampf(emission, 0.0, 1.0))
	if kind == "white":
		color = Color.WHITE
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -52), c + Vector2(width, -8), c + Vector2(0, 34), c + Vector2(-width, -8)]), color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -52), c + Vector2(width * 0.35, -8), c + Vector2(0, 34)]), Color(1, 1, 1, 0.25 * emission))


func _draw_motes(base: Vector2, count: int, t: float) -> void:
	for i: int in count:
		var phase: float = fmod(t * 0.3 + i * 0.618, 1.0)
		var x: float = base.x + sin(i * 12.9898) * 110.0
		var y: float = base.y - 20.0 - phase * 280.0
		draw_circle(Vector2(x, y), 1.5 + fmod(i, 3.0) * 0.6, Color(UITokens.RUNE, 1.0 - phase))
