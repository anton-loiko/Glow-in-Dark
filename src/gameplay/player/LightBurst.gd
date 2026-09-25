class_name LightBurst
extends Node2D
## Взрыв Света (DS §05, Art Direction VFX): hit-stop 60 мс → сжатие 60 мс → белый кадр 2 фрейма
## и тряска 6pt/180 мс → кольцо ударной волны 250 мс → радиус с перелётом 8% к 500 мс → магнит искр к 900 мс.
## «Без белых вспышек» / Reduce Motion: янтарь 40% вместо белого, тряска 3pt. Вспышки чаще 3/с склеиваются (WCAG 2.3.1).

signal burst_started(world_pos: Vector2)

const FLASH_WHITE: Color = Color(1, 1, 1, 1)
const FLASH_AMBER: Color = Color(1.0, 0.71, 0.28, 0.4)

@export var player: Player
@export var camera: RunCamera
@export var pickups: PickupSystem
@export var flash_rect: ColorRect

var cfg: Dictionary = {}
var overshoot_ratio: float = 0.08
var _ring_radius: float = 0.0
var _ring_alpha: float = 0.0
var _ring_color: Color = Color.WHITE
var _last_burst_ms: int = -100000


func setup(balance: Dictionary) -> void:
	cfg = balance.get("burst", {}) as Dictionary
	overshoot_ratio = float((balance.get("player", {}) as Dictionary).get("burst_overshoot", 0.08))
	flash_rect.visible = false
	z_index = 5


## Взрыв в позиции игрока. damage_player = false всегда: Взрыв никогда не ранит Огонька.
func trigger() -> void:
	var now: int = Time.get_ticks_msec()
	var merge_ms: int = int(float(cfg.get("merge_window_s", 0.34)) * 1000.0)
	if now - _last_burst_ms < merge_ms:
		return
	_last_burst_ms = now
	var origin: Vector2 = player.global_position
	global_position = origin
	burst_started.emit(origin)
	EventBus.light_burst_triggered.emit(origin)
	FeedbackManager.cue(&"light_burst")
	_run_sequence()


func _run_sequence() -> void:
	var no_flashes: bool = GameManager.profile.settings.no_flashes
	# 0–60 мс: hit-stop.
	await TimeService.hit_stop(int(cfg.get("hit_stop_ms", 60)))
	# 60–120 мс: сжатие — Огонёк втягивает свет.
	var squash: Tween = create_tween()
	squash.tween_property(player, ^"radius_boost", 0.85, float(cfg.get("squash_ms", 60)) / 1000.0)
	await squash.finished
	# 120 мс: вспышка 2 кадра + тряска.
	_flash(no_flashes)
	camera.shake(3.0 if no_flashes else float(cfg.get("shake_pt", 6.0)), float(cfg.get("shake_ms", 180)) / 1000.0)
	# Кольцо ударной волны 250 мс и радиус с перелётом 8% к 500 мс.
	_ring_color = player.visual.light_color
	var overshoot: float = 1.0 + overshoot_ratio
	var wave: Tween = create_tween().set_parallel(true)
	wave.tween_method(_set_ring, 0.0, 1.0, float(cfg.get("ring_ms", 250)) / 1000.0)
	wave.tween_property(player, ^"radius_boost", overshoot, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	wave.chain().tween_property(player, ^"radius_boost", 1.0, (float(cfg.get("radius_ms", 500)) - 200.0) / 1000.0).set_trans(Tween.TRANS_SINE)
	await wave.finished
	# 900 мс: пепел оседает, искры магнитом к герою.
	pickups.attract_all(get_viewport_rect().size.length())


func _flash(no_flashes: bool) -> void:
	flash_rect.color = FLASH_AMBER if no_flashes else FLASH_WHITE
	flash_rect.visible = true
	for i: int in int(cfg.get("flash_frames", 2)):
		await get_tree().process_frame
	flash_rect.visible = false


func _set_ring(t: float) -> void:
	_ring_radius = player.light_radius() * (0.2 + 1.2 * t)
	_ring_alpha = 1.0 - t
	queue_redraw()


func _draw() -> void:
	if _ring_alpha <= 0.0:
		return
	draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 64, Color(_ring_color, _ring_alpha), 4.0)
