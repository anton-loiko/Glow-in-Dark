extends Control
## S01 · Сплэш / синхронизация (DS S01, §07): ink.900 от края до края, свечение от знака, центр группы
## на 36% высоты, три тлеющие точки на 76%. Ждёт облако (CloudManager) и вход в гейм-центр;
## дольше 6 с — «Нет сети · играть офлайн». Затем S02 (+ S03 поверх при первом входе за день).

const MIN_SHOW_S: float = 1.2
const TIMEOUT_S: float = 6.0

var _status: Label
var _offline: GlowButton
var _done: bool = false
var _glow_rect: TextureRect
var _mark: TextureRect

const MARK: Texture2D = preload("res://src/assets/brand/splash_mark.png")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = UITokens.INK_900
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_glow())
	var group: VBoxContainer = UIKit.vbox(UITokens.S2, BoxContainer.ALIGNMENT_CENTER)
	group.set_anchors_preset(Control.PRESET_CENTER)
	group.anchor_top = 0.36
	group.anchor_bottom = 0.36
	group.grow_horizontal = Control.GROW_DIRECTION_BOTH
	group.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(group)
	# Знак 200px на 1080 → 72pt (DS §07); Огонёк с лицом из бренд-пака.
	var mark: TextureRect = TextureRect.new()
	mark.texture = MARK
	mark.custom_minimum_size = Vector2(128, 128) # капля ≈ 64pt
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.pivot_offset = Vector2(64, 76)
	group.add_child(mark)
	_mark = mark
	var title: Label = UIKit.label("Glow\nin the Dark", &"display", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override(&"line_spacing", -8) # 34/38
	group.add_child(title)
	group.add_child(UIKit.mono("С в е т   в о   т ь м е", UITokens.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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
	studio.position.y -= 64 # 150px на 1920 → ~64pt от низа
	studio.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(studio)
	_boot()


func _boot() -> void:
	Telemetry.log_event(&"app_open")
	add_child(ShaderWarmup.new())
	GameServices.sign_in_silently()
	var started: int = Time.get_ticks_msec()
	CloudManager.sync()
	# Реальное время, а не таймер дерева: первые кадры после загрузки приходят с огромной delta
	# (компиляция шейдеров, ShaderWarmup), и таймер на 1.2 с истекал за ~60 мс — сплэш мелькал.
	while Time.get_ticks_msec() - started < MIN_SHOW_S * 1000.0:
		await get_tree().process_frame
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


## Радиальный градиент от знака, R = 60% ширины (DS §07) — текстурой, без ступенек.
func _glow() -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(UITokens.LIGHT_500, 0.28))
	gradient.set_color(1, Color(UITokens.LIGHT_700, 0.0))
	gradient.add_point(0.45, Color(UITokens.LIGHT_700, 0.08))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_glow_rect = rect
	return rect


func _process(_delta: float) -> void:
	var view: Vector2 = size
	var r: float = view.x * 0.6
	_glow_rect.position = Vector2(view.x * 0.5 - r, view.y * 0.36 - 70 - r)
	_glow_rect.size = Vector2(r, r) * 2.0
	_mark.scale = Vector2.ONE * (1.0 + 0.04 * TimeService.breath_phase())
