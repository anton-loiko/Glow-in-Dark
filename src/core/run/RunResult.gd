class_name RunResult
extends RefCounted
## Итог забега: причина завершения и статистика для S09 и телеметрии run_ended.

const REASON_DEATH: StringName = &"death"
const REASON_QUIT: StringName = &"quit"
const REASON_CHAPTER_CLEARED: StringName = &"chapter_cleared"

var reason: StringName = REASON_DEATH
var time_s: float = 0.0
var kills: int = 0
var player_level: int = 1
var run_sparks: int = 0
var chests: Array[StringName] = []
var is_record: bool = false


func to_telemetry() -> Dictionary:
	return {
		"reason": String(reason),
		"time_s": snappedf(time_s, 0.1),
		"kills": kills,
		"level": player_level,
		"sparks": run_sparks,
	}
