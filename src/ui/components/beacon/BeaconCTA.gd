class_name BeaconCTA
extends Control
## Главное действие хаба «Внести Искры» (Meta DS §02). Состояния:
## ACTIVE — тап = 1 уровень · HOLDING — удержание > 250 мс, темп 600 → 150 мс за 2 с, заливка = прогресс тира ·
## TIER_READY — 9/10 рун, отдельный тап «Зажечь тир» (удержание здесь всегда останавливается) ·
## DISABLED — «Нужно ещё N ✦», тап — покачивание + rigid · MAXED — переход к главам · SYNCING — ввод заблокирован.

signal deposited(levels: int)
signal tier_lit(tier: int)
signal need_sparks
signal maxed_pressed

enum State { ACTIVE, HOLDING, TIER_READY, DISABLED, MAXED, SYNCING }

const HOLD_DELAY_S: float = 0.25
const HEIGHT: float = 64.0

var chapter_id: int = 1
var state: State = State.ACTIVE
var syncing: bool = false

var _down: bool = false
var _held_s: float = 0.0
var _next_step_s: float = 0.0
var _hold_levels: int = 0
var _hold_sparks: int = 0
var _shine_t: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	if syncing:
		state = State.SYNCING
	elif BeaconService.is_max(profile, chapter_id):
		state = State.MAXED
	elif not BeaconService.can_afford_next(profile, chapter_id):
		state = State.DISABLED
	elif BeaconService.is_tier_ready(profile, chapter_id):
		state = State.TIER_READY
	elif _down and _held_s >= HOLD_DELAY_S:
		state = State.HOLDING
	else:
		state = State.ACTIVE
	queue_redraw()


## Прервать удержание (кат-сцена вехи перекрыла кнопку).
func release() -> void:
	if _down:
		_on_up()


## Сколько Искр не хватает до следующего уровня.
func sparks_missing() -> int:
	return maxi(0, BeaconService.next_cost(GameManager.profile, chapter_id) - GameManager.profile.sparks)


func _process(delta: float) -> void:
	_shine_t = fmod(_shine_t + delta, 4.0)
	if _down and state in [State.ACTIVE, State.HOLDING]:
		_held_s += delta
		if _held_s >= HOLD_DELAY_S:
			_next_step_s -= delta
			if _next_step_s <= 0.0:
				_next_step_s += _interval_s()
				_step()
	queue_redraw()


## Интервал удержания: линейно от start_ms к min_ms за ramp_ms.
func _interval_s() -> float:
	var hold: Dictionary = BeaconService.config().get("hold", {}) as Dictionary
	var start: float = float(hold.get("start_ms", 600))
	var min_ms: float = float(hold.get("min_ms", 150))
	var ramp: float = float(hold.get("ramp_ms", 2000))
	var k: float = clampf((_held_s - HOLD_DELAY_S) * 1000.0 / ramp, 0.0, 1.0)
	return lerpf(start, min_ms, k) / 1000.0


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
		accept_event()
		_on_down()
	elif up and _down:
		accept_event()
		_on_up()


func _on_down() -> void:
	match state:
		State.SYNCING:
			return
		State.DISABLED:
			UIMotion.shake(self)
			FeedbackManager.cue(&"button_disabled")
			need_sparks.emit()
			return
		State.MAXED:
			maxed_pressed.emit()
			return
		State.TIER_READY:
			_light_tier()
			return
	_down = true
	_held_s = 0.0
	_next_step_s = 0.0
	_hold_levels = 0
	_hold_sparks = 0
	_step()


func _on_up() -> void:
	_down = false
	if _hold_levels > 0:
		Telemetry.log_event(&"beacon_deposit", {"levels": _hold_levels, "sparks": _hold_sparks, "hold": _held_s >= HOLD_DELAY_S})
		SaveManager.request_save()
	_held_s = 0.0
	refresh()


func _step() -> void:
	var cost: int = BeaconService.next_cost(GameManager.profile, chapter_id)
	var result: int = BeaconService.deposit_one(GameManager.profile, chapter_id)
	if result < 0:
		_down = false
		refresh()
		return
	_hold_levels += 1
	_hold_sparks += cost
	FeedbackManager.cue(&"beacon_tick", pow(2.0, float(BeaconService.level(GameManager.profile, chapter_id) % BeaconService.levels_per_tier()) / 12.0))
	deposited.emit(1)
	refresh()
	if state != State.ACTIVE and state != State.HOLDING:
		_on_up() # граница тира или кончились Искры — удержание останавливается


func _light_tier() -> void:
	syncing = true
	refresh()
	var tier: int = BeaconService.deposit_one(GameManager.profile, chapter_id, true)
	syncing = false
	if tier > 0:
		Telemetry.log_event(&"beacon_deposit", {"levels": 1, "sparks": 0, "hold": false})
		tier_lit.emit(tier)
	refresh()


## Две строки Meta DS §02: действие (Unbounded, капс) + цена следующего шага.
func _lines() -> PackedStringArray:
	var profile: PlayerProfile = GameManager.profile
	var cost: String = UIKit.format_number(BeaconService.next_cost(profile, chapter_id))
	match state:
		State.TIER_READY:
			var tier: int = floori(float(BeaconService.level(profile, chapter_id)) / BeaconService.levels_per_tier()) + 1
			return PackedStringArray([tr("Зажечь тир %d") % tier, tr("последний уровень · %s ✦") % cost])
		State.DISABLED:
			return PackedStringArray([tr("Нужно ещё %s ✦") % UIKit.format_number(sparks_missing()), tr("следующий уровень · %s ✦") % cost])
		State.MAXED:
			return PackedStringArray([tr("Глава %d открыта →") % (chapter_id + 1) if ConfigDB.get_chapter(chapter_id + 1) != null else tr("К главам"), ""])
		State.SYNCING:
			return PackedStringArray(["", ""])
		State.HOLDING:
			return PackedStringArray([UIKit.plural(_hold_levels, tr("+%d уровень"), tr("+%d уровня"), tr("+%d уровней")), "−%s ✦" % UIKit.format_number(_hold_sparks)])
	return PackedStringArray([tr("Внести Искры"), tr("1 ур. · %s ✦ · удерживай, чтобы внести больше") % cost])


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var main_color: Color = UITokens.TEXT_ON_LIGHT
	var sub_color: Color = Color(UITokens.TEXT_ON_LIGHT, 0.75)
	match state:
		State.ACTIVE, State.HOLDING, State.TIER_READY:
			var pressed: bool = state == State.HOLDING
			var base: StyleBoxFlat = StyleBoxFlat.new()
			base.bg_color = UITokens.LIGHT_900
			base.set_corner_radius_all(UITokens.R16)
			base.anti_aliasing = true
			base.shadow_color = Color(UITokens.LIGHT_500, 0.45 if state == State.TIER_READY else 0.35)
			base.shadow_size = UITokens.G3 if state == State.TIER_READY else UITokens.G2 - 14
			draw_style_box(base, rect)
			# Тело: градиент light.300 → 500 → 700, цоколь 4pt; в HOLDING кнопка утоплена (цоколь 0).
			var body: Rect2 = Rect2(Vector2(0, 4.0 if pressed else 0.0), Vector2(rect.size.x, rect.size.y - 4.0))
			_draw_gradient(body, [UITokens.LIGHT_300, UITokens.LIGHT_500, UITokens.LIGHT_700])
			# Заливка = прогресс внутри тира; в HOLDING остаток — тёмный янтарь.
			var lv: int = BeaconService.level(GameManager.profile, chapter_id)
			var k: float = float(lv % BeaconService.levels_per_tier()) / BeaconService.levels_per_tier()
			if pressed:
				var rest: Rect2 = Rect2(body.position + Vector2(body.size.x * k, 0), Vector2(body.size.x * (1.0 - k), body.size.y))
				draw_rect(rest.intersection(body.grow_individual(0, 0, -UITokens.R16 * 0.5, 0)), Color(UITokens.LIGHT_900, 0.85))
			if state == State.ACTIVE and _shine_t < 0.6:
				var x: float = rect.size.x * (_shine_t / 0.6)
				draw_line(Vector2(x, 8), Vector2(x - 14, rect.size.y - 10), Color(1, 1, 1, 0.35), 6.0, true)
		State.DISABLED:
			main_color = UITokens.TEXT_MUTED
			sub_color = UITokens.TEXT_DISABLED
			_draw_dashed(rect)
		State.MAXED:
			var sec: StyleBoxFlat = StyleBoxFlat.new()
			sec.bg_color = Color(0, 0, 0, 0)
			sec.border_color = UITokens.LIGHT_500
			sec.set_border_width_all(2)
			sec.set_corner_radius_all(UITokens.R14)
			sec.anti_aliasing = true
			draw_style_box(sec, rect)
			main_color = UITokens.TEXT_SECONDARY_BUTTON
		State.SYNCING:
			var sync_box: StyleBoxFlat = StyleBoxFlat.new()
			sync_box.bg_color = UITokens.INK_600
			sync_box.set_corner_radius_all(UITokens.R16)
			draw_style_box(sync_box, rect)
			for i: int in 3:
				var a: float = 0.3 + 0.7 * absf(sin(Time.get_ticks_msec() / 400.0 + i))
				draw_circle(size * 0.5 + Vector2((i - 1) * 16, 0), 4.0, Color(UITokens.LIGHT_500, a))
			return
	var lines: PackedStringArray = _lines()
	var y_shift: float = 2.0 if state == State.HOLDING else 0.0
	var main_font: Font = UIFonts.font(&"button")
	var main_text: String = lines[0].to_upper() if state != State.DISABLED else lines[0]
	var main_size: int = 17
	var main_w: float = main_font.get_string_size(main_text, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size).x
	var has_sub: bool = not lines[1].is_empty()
	var main_y: float = size.y * 0.5 + (-2.0 if has_sub else main_size * 0.35) + y_shift - 2.0
	draw_string(main_font, Vector2((size.x - main_w) * 0.5, main_y), main_text, HORIZONTAL_ALIGNMENT_LEFT, -1, main_size, main_color)
	if has_sub:
		var sub_font: Font = UIFonts.font(&"body_s")
		var sub_w: float = sub_font.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(sub_font, Vector2((size.x - sub_w) * 0.5, main_y + 17.0), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sub_color)


func _draw_gradient(body: Rect2, stops: Array[Color]) -> void:
	var points: PackedVector2Array = ButtonFace.rounded_rect(body, UITokens.R16)
	var colors: PackedColorArray = PackedColorArray()
	for p: Vector2 in points:
		var t: float = clampf((p.y - body.position.y) / body.size.y, 0.0, 1.0)
		colors.append(stops[0].lerp(stops[1], t / 0.5) if t < 0.5 else stops[1].lerp(stops[2], (t - 0.5) * 1.2))
	draw_polygon(points, colors)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	var outline_colors: PackedColorArray = colors.duplicate()
	outline_colors.append(colors[0])
	draw_polyline_colors(outline, outline_colors, 1.0, true)


func _draw_dashed(rect: Rect2) -> void:
	var pts: PackedVector2Array = ButtonFace.rounded_rect(rect.grow(-1), UITokens.R14)
	pts.append(pts[0])
	for i: int in pts.size() - 1:
		draw_dashed_line(pts[i], pts[i + 1], UITokens.LINE_STRONG, 1.5, 6.0)
