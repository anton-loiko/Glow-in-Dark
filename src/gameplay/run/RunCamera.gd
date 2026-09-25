class_name RunCamera
extends Camera2D
## Камера забега (task_2 §9): Огонёк по центру X и на 51% высоты, тряска с затуханием
## (выключается тогглом «Тряска камеры»), отдаление от Фокусной линзы (−1.5% за уровень, до −7.5%).

var shake_decay: float = 2.2
var zoom_step: float = 0.015
var zoom_max: float = 0.075

var _shake_amplitude: float = 0.0
var _shake_left: float = 0.0
var _shake_total: float = 0.0
var _zoom_tween: Tween


func setup(balance: Dictionary) -> void:
	var cfg: Dictionary = balance.get("camera", {}) as Dictionary
	var viewport_height: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 844))
	var screen_y: float = float(cfg.get("player_screen_y", 0.51))
	position = Vector2(0.0, (0.5 - screen_y) * viewport_height)
	shake_decay = float(cfg.get("shake_decay_per_s", shake_decay))
	zoom_step = float(cfg.get("lens_zoom_step", zoom_step))
	zoom_max = float(cfg.get("lens_zoom_max", zoom_max))
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	make_current()


## Тряска амплитудой amplitude_pt на duration_s секунд (сильнейшая перекрывает слабую).
func shake(amplitude_pt: float, duration_s: float) -> void:
	var settings: PlayerProfile.Settings = GameManager.profile.settings
	if not settings.camera_shake:
		return
	if amplitude_pt >= _shake_amplitude * (_shake_left / maxf(0.001, _shake_total)):
		_shake_amplitude = amplitude_pt
		_shake_left = duration_s
		_shake_total = duration_s


## Отдаление камеры на уровнях Фокусной линзы (0–5).
func set_lens_level(level: int) -> void:
	var target: float = 1.0 - minf(zoom_max, level * zoom_step)
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, ^"zoom", Vector2(target, target), 0.4).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	if _shake_left <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var strength: float = _shake_amplitude * (_shake_left / maxf(0.001, _shake_total))
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
