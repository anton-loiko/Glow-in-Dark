extends Control
## S08 · Свет угас (DS S08): весь экран в тоне cold, кольцо таймера янтарное — надежда. Отсчёт 5 с
## (ведёт RunDirector), по окончании — S09. «▶ Разжечь снова» (плейсмент revive) → +50% света, Взрыв Света,
## 2 с неуязвимости; «Разжечь за 30 ◆» — альтернатива без рекламы. Один раз за забег. «Назад» игнорируется.

var _ring: CountdownRing


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column: VBoxContainer = UIKit.screen_root(self, Color(UITokens.COLD.darkened(0.75), 0.92))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(UIKit.spacer())
	column.add_child(UIKit.label(tr("Свет угас"), &"h1", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	var run: RunContext = GameManager.current_run
	if run != null:
		column.add_child(UIKit.label(UIKit.format_time(run.elapsed_s), &"number", UITokens.COLD, HORIZONTAL_ALIGNMENT_CENTER))
	_ring = CountdownRing.new()
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_ring)
	_ring.start(float((ConfigDB.get_balance().get("run", {}) as Dictionary).get("revive_countdown_s", 5.0)))
	column.add_child(UIKit.spacer())
	var revive: GlowButton = UIKit.button(tr("Разжечь снова"), GlowButton.Variant.PRIMARY, AdManager.show_rewarded.bind(&"revive"))
	revive.ad = true
	if not AdManager.is_rewarded_ready(&"revive"):
		revive.set_blocked(true, tr("Реклама недоступна"))
	column.add_child(revive)
	var cost: int = int((ConfigDB.get_balance().get("run", {}) as Dictionary).get("revive_crystal_cost", 30))
	var crystal: GlowButton = UIKit.button(tr("Разжечь за %d ◆") % cost, GlowButton.Variant.CRYSTAL, _revive_crystal)
	if not GameManager.can_afford(GameManager.CRYSTALS, cost):
		crystal.set_blocked(true, tr("Нужно %d ◆") % cost)
	column.add_child(crystal)
	column.add_child(UIKit.button(tr("Завершить забег"), GlowButton.Variant.QUIET, _give_up))


func _revive_crystal() -> void:
	GameManager.request_revive(&"crystal")


func _give_up() -> void:
	var result: RunResult = RunResult.new()
	result.reason = RunResult.REASON_DEATH
	result.time_s = GameManager.current_run.elapsed_s if GameManager.current_run != null else 0.0
	GameManager.end_run(result)
