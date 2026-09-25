class_name MockAdsBackend
extends AdsBackend
## Симуляция Rewarded Video для редактора и тестов.

var loaded: bool = true
var grant_reward: bool = true
var delay_s: float = 0.5


func is_rewarded_ready() -> bool:
	return loaded


func show_rewarded(placement: StringName) -> void:
	if not loaded:
		rewarded_failed.emit(placement, "not_loaded")
		return
	if delay_s > 0.0:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		await tree.create_timer(delay_s, true, false, true).timeout
	rewarded_finished.emit(placement, grant_reward)
