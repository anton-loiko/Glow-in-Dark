extends Control
## S01 · Сплэш / синхронизация (DS S01, §07): ink.900 от края до края, свечение от знака, центр группы
## на 36% высоты, три тлеющие точки на 76%. Ждёт облако (CloudManager) и вход в гейм-центр;
## дольше 6 с — «Нет сети · играть офлайн». Затем S02 (+ S03 поверх при первом входе за день).

const MIN_SHOW_S: float = 1.2
const TIMEOUT_S: float = 6.0

var _status: Label
var _offline: GlowButton
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = UITokens.INK_900
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow: Control = Control.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.draw.connect(_draw_glow.bind(glow))
	add_child(glow)
	var group: VBoxContainer = UIKit.vbox(UITokens.S2, BoxContainer.ALIGNMENT_CENTER)
	group.set_anchors_preset(Control.PRESET_CENTER)
	group.anchor_top = 0.36
	group.anchor_bottom = 0.36
	group.grow_horizontal = Control.GROW_DIRECTION_BOTH
	group.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(group)
	var mark: Control = Control.new()
	mark.custom_minimum_size = Vector2(96, 96)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.draw.connect(_draw_mark.bind(mark))
	group.add_child(mark)
	group.add_child(UIKit.label("Glow\nin the Dark", &"display", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	group.add_child(UIKit.mono("С в е т   в о   т ь м е", UITokens.LIGHT_500, HORIZONTAL_ALIGNMENT_CENTER))
	var bottom: VBoxContainer = UIKit.vbox(UITokens.S3, BoxContainer.ALIGNMENT_CENTER)
	bottom.set_anchors_preset(Control.PRESET_CENTER)
	bottom.anchor_top = 0.76
	bottom.anchor_bottom = 0.76
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(bottom)
	var dots: EmberDots = EmberDots.new()
	dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(dots)
	_status = UIKit.label(tr("Разжигаем свет…"), &"body_s", UITokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(_status)
	_offline = UIKit.button(tr("Нет сети · играть офлайн"), GlowButton.Variant.QUIET, _go_next)
	_offline.visible = false
	bottom.add_child(_offline)
	var studio: Label = UIKit.mono("A game by studio", UITokens.TEXT_DISABLED, HORIZONTAL_ALIGNMENT_CENTER)
	studio.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	studio.position.y -= 60
	studio.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(studio)
	_boot()


func _boot() -> void:
	Telemetry.log_event(&"app_open")
	add_child(ShaderWarmup.new())
	GameServices.sign_in_silently()
	var started: int = Time.get_ticks_msec()
	CloudManager.sync()
	await get_tree().create_timer(MIN_SHOW_S, true, false, true).timeout
	while CloudManager.state == &"syncing" and Time.get_ticks_msec() - started < TIMEOUT_S * 1000.0:
		await get_tree().process_frame
	if CloudManager.state == &"syncing":
		Telemetry.log_event(&"sync_timeout")
		_status.text = ""
		_offline.visible = true
		return
	_go_next()


func _go_next() -> void:
	if _done:
		return
	_done = true
	SceneRouter.go(&"S02", {"open_daily": DailyGiftService.is_available(GameManager.profile)})


func _draw_glow(target: Control) -> void:
	var center: Vector2 = Vector2(target.size.x * 0.5, target.size.y * 0.36 - 60)
	var radius: float = target.size.x * 0.6
	for i: int in 12:
		var t: float = float(i) / 12.0
		target.draw_circle(center, radius * (1.0 - t), Color(UITokens.LIGHT_500, 0.012 + t * 0.012))


func _draw_mark(mark: Control) -> void:
	var c: Vector2 = mark.size * 0.5 + Vector2(0, 4)
	var breath: float = 1.0 + 0.04 * TimeService.breath_phase()
	mark.draw_circle(c + Vector2(0, 6), 26.0 * breath, UITokens.LIGHT_500)
	mark.draw_colored_polygon(PackedVector2Array([c + Vector2(-19, -6), c + Vector2(0, -36) * breath, c + Vector2(19, -6)]), UITokens.LIGHT_500)
	mark.draw_circle(c + Vector2(0, 12), 11.0, UITokens.HERO_CORE)
	mark.queue_redraw()
