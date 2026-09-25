class_name RunContext
extends RefCounted
## Состояние одного забега. Создаётся GameManager.start_run(), живёт до зачисления наград на S09.
## Все случайности забега берутся из rng, засеянного run_seed, — оферы навыков и спавн детерминированы.

var run_id: String = ""
var run_seed: int = 0
var chapter_id: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stats: StatBlock

var elapsed_s: float = 0.0
var run_sparks: int = 0
var xp: int = 0
var player_level: int = 1
var level_up_idx: int = 0
var kills: int = 0

var skills: Dictionary[StringName, int] = {} ## id навыка → уровень
var offer_history: Array[Array] = [] ## показанные оферы по левел-апам
var current_offer: Array[SkillOffer] = []
var last_rejected: Array[StringName] = [] ## показаны и не выбраны на прошлом левел-апе (M_fresh)
var magnet_seen: bool = false
var reroll_idx: int = 0 ## рероллы текущего левел-апа (для seed)
var reroll_count: int = 0
var revive_used: bool = false
var take_all_used: bool = false
var ad_reroll_used: bool = false
var run_chests: Array[StringName] = []

var result: RunResult


func _init(p_chapter_id: int, p_seed: int, p_stats: StatBlock) -> void:
	chapter_id = p_chapter_id
	run_seed = p_seed
	stats = p_stats
	rng.seed = p_seed
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), p_seed & 0xFFFF]
	run_sparks = p_stats.start_sparks


func skill_level(id: StringName) -> int:
	return skills.get(id, 0)


func slots_used() -> int:
	return skills.size()
