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


func _label() -> String:
	var profile: PlayerProfile = GameManager.profile
	match state:
		State.TIER_READY:
			return tr("Зажечь тир %d") % (floori(float(BeaconService.level(profile, chapter_id)) / BeaconService.levels_per_tier()) + 1)
		State.DISABLED:
			return tr("Нужно ещё %s ✦") % UIKit.format_number(sparks_missing())
		State.MAXED:
			return tr("К главам")
		State.SYNCING:
			return ""
		State.HOLDING:
			return tr("+%d уровней") % _hold_levels
	return tr("Внести Искры") + "  ·  " + UIKit.format_number(BeaconService.next_cost(profile, chapter_id)) + " ✦"


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(UITokens.R16)
	var text_color: Color = UITokens.TEXT_ON_LIGHT
	match state:
		State.ACTIVE, State.HOLDING, State.TIER_READY:
			var glow: float = float(UITokens.G3 if state == State.TIER_READY else UITokens.G2)
			for i: int in 3:
				var grow: float = glow * (i + 1) / 3.0
				var halo: StyleBoxFlat = StyleBoxFlat.new()
				halo.bg_color = Color(UITokens.LIGHT_500, 0.07)
				halo.set_corner_radius_all(UITokens.R16 + int(grow))
				halo.draw(get_canvas_item(), rect.grow(grow * 0.5))
			box.bg_color = UITokens.LIGHT_500
			if state != State.HOLDING:
				# цоколь light.900 3pt; в HOLDING кнопка «вдавлена» — цоколь 0
				var base: StyleBoxFlat = StyleBoxFlat.new()
				base.bg_color = UITokens.LIGHT_900
				base.set_corner_radius_all(UITokens.R16)
				base.draw(get_canvas_item(), Rect2(rect.position + Vector2(0, 3), rect.size))
		State.DISABLED:
			box.bg_color = Color(UITokens.INK_700, 1.0)
			text_color = UITokens.TEXT_MUTED
		State.MAXED:
			box.bg_color = Color(0, 0, 0, 0)
			box.border_color = UITokens.LIGHT_500
			box.set_border_width_all(1)
			text_color = UITokens.TEXT_SECONDARY_BUTTON
		State.SYNCING:
			box.bg_color = UITokens.INK_600
	box.draw(get_canvas_item(), rect)
	if state == State.HOLDING or state == State.ACTIVE:
		# заливка = прогресс внутри тира
		var lv: int = BeaconService.level(GameManager.profile, chapter_id)
		var k: float = float(lv % BeaconService.levels_per_tier()) / BeaconService.levels_per_tier()
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = Color(UITokens.LIGHT_300, 0.45 if state == State.HOLDING else 0.18)
		fill.set_corner_radius_all(UITokens.R16)
		if k > 0.0:
			fill.draw(get_canvas_item(), Rect2(rect.position, Vector2(maxf(UITokens.R16 * 2.0, rect.size.x * k), rect.size.y)))
		if state == State.ACTIVE and _shine_t < 0.6:
			var x: float = rect.size.x * (_shine_t / 0.6)
			draw_line(Vector2(x, 6), Vector2(x - 14, rect.size.y - 6), Color(1, 1, 1, 0.35), 6.0)
	if state == State.DISABLED:
		_draw_dashed(rect)
	if state == State.SYNCING:
		for i: int in 3:
			var a: float = 0.3 + 0.7 * absf(sin(Time.get_ticks_msec() / 400.0 + i))
			draw_circle(size * 0.5 + Vector2((i - 1) * 16, 0), 4.0, Color(UITokens.LIGHT_500, a))
		return
	var font: Font = UIFonts.font(&"button")
	var font_size: int = 17
	var text: String = _label().to_upper()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.5 + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _draw_dashed(rect: Rect2) -> void:
	var r: Rect2 = rect.grow(-1)
	var pts: PackedVector2Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i: int in 4:
		draw_dashed_line(pts[i], pts[i + 1], UITokens.LINE_STRONG, 1.5, 6.0)
