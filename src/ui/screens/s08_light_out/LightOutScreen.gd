extends Control
## S08 · Свет угас (DS S08): весь экран в тоне cold, кольцо таймера янтарное — надежда. Отсчёт 5 с
## (ведёт RunDirector), по окончании — S09. «▶ Разжечь снова» (плейсмент revive) → +50% света, Взрыв Света,
## 2 с неуязвимости; «Разжечь за 30 ◆» — альтернатива без рекламы. Один раз за забег. «Назад» игнорируется.

var _ring: CountdownRing
var _count: Label

## Пары красных глаз во тьме вокруг кольца (доли экрана).
const EYES: Array[Vector2] = [Vector2(0.14, 0.2), Vector2(0.8, 0.27), Vector2(0.2, 0.5), Vector2(0.74, 0.47)]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Весь экран в тоне cold: почти непрозрачные чернила, остывший Огонёк в янтарном кольце — надежда.
	var column: VBoxContainer = UIKit.screen_root(self, Color(UITokens.INK_900, 0.96))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var eyes: Control = Control.new()
	eyes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eyes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eyes.draw.connect(_draw_eyes.bind(eyes))
	add_child(eyes)
	move_child(eyes, 1)
	column.add_child(UIKit.spacer())
	_ring = CountdownRing.new()
	_ring.diameter = 156.0
	_ring.number_inside = false
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_ring)
	var hero: HeroGlyph = HeroGlyph.new()
	hero.color = UITokens.COLD
	hero.diameter = 44.0
	hero.glow = UITokens.G1
	hero.breathe = false
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.add_child(hero)
	_ring.start(float((ConfigDB.get_balance().get("run", {}) as Dictionary).get("revive_countdown_s", 5.0)))
	_count = UIKit.label("", &"display", UITokens.GOLD_300, HORIZONTAL_ALIGNMENT_CENTER)
	_count.add_theme_font_size_override(&"font_size", 44)
	column.add_child(_count)
	column.add_child(UIKit.label(tr("Свет угас"), &"h1", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	var run: RunContext = GameManager.current_run
	if run != null:
		var best: float = maxf(run.elapsed_s, float(GameManager.profile.best_time_s.get(run.chapter_id, 0.0)))
		column.add_child(UIKit.label(tr("%s · твой лучший забег в этой главе") % UIKit.format_time(best), &"body_s", UITokens.COLD, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIKit.spacer())
	var revive: GlowButton = UIKit.ad_button(tr("Разжечь снова"), GlowButton.Variant.PRIMARY, &"revive")
	column.add_child(revive)
	var cost: int = int((ConfigDB.get_balance().get("run", {}) as Dictionary).get("revive_crystal_cost", 30))
	var crystal: GlowButton = UIKit.button(tr("Разжечь за %d ◆") % cost, GlowButton.Variant.CRYSTAL, _revive_crystal)
	if not GameManager.can_afford(GameManager.CRYSTALS, cost):
		crystal.set_blocked(true, tr("Нужно %d ◆") % cost)
	column.add_child(crystal)
	column.add_child(UIKit.button(tr("Завершить забег"), GlowButton.Variant.QUIET, _give_up))


func _process(_delta: float) -> void:
	_count.text = str(_ring.seconds_left())


func _draw_eyes(target: Control) -> void:
	for p: Vector2 in EYES:
		var c: Vector2 = p * target.size
		target.draw_circle(c + Vector2(-5, 0), 2.6, UITokens.THREAT, true, -1.0, true)
		target.draw_circle(c + Vector2(5, 0), 2.6, UITokens.THREAT, true, -1.0, true)


func _revive_crystal() -> void:
	GameManager.request_revive(&"crystal")


func _give_up() -> void:
	var result: RunResult = RunResult.new()
	result.reason = RunResult.REASON_DEATH
	result.time_s = GameManager.current_run.elapsed_s if GameManager.current_run != null else 0.0
	GameManager.end_run(result)
