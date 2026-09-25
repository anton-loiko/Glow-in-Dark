extends Control
## S02 · Хаб (DS S02, Meta DS §02): сверху вниз — статус · валюта · глава · Маяк · прогресс · CTA · навигация.
## Очередь после входа: кат-сцена тира/вехи (если не показана) → S14 новых Огоньков → сундуки из pending_rewards.

var _chapter_id: int = 1
var _stage: BeaconStage
var _cta: BeaconCTA
var _gift: GlowButton
var _progress_title: Label
var _progress_pct: Label
var _tier_bar: Control
var _total_bar: Control
var _next_label: Label
var _daily_button: GlowButton
var _tab_bar: GlowTabBar
var _cutscene: BeaconCutscene


func _ready() -> void:
	_chapter_id = GameManager.profile.current_chapter
	var column: VBoxContainer = UIKit.screen_root(self)
	var top: HBoxContainer = UIKit.hbox(UITokens.S2)
	column.add_child(top)
	var settings: GlowButton = UIKit.button("⚙", GlowButton.Variant.ICON, SceneRouter.go.bind(&"S13"))
	top.add_child(settings)
	top.add_child(UIKit.spacer(false))
	top.add_child(_pill(GameManager.SPARKS))
	top.add_child(_pill(GameManager.CRYSTALS))

	var chapter_row: HBoxContainer = UIKit.hbox(UITokens.S2, BoxContainer.ALIGNMENT_CENTER)
	column.add_child(chapter_row)
	chapter_row.add_child(UIKit.button("‹", GlowButton.Variant.QUIET, SceneRouter.go.bind(&"S04")))
	var chapter: ChapterDef = ConfigDB.get_chapter(_chapter_id)
	var chapter_title: Button = Button.new()
	chapter_title.theme_type_variation = &"ButtonQuiet"
	chapter_title.text = (tr("Глава %d · %s") % [chapter.id, tr(chapter.name_key)]).to_upper()
	UIFonts.apply(chapter_title, &"label", UITokens.TEXT_MUTED)
	chapter_title.pressed.connect(SceneRouter.go.bind(&"S04"))
	chapter_row.add_child(chapter_title)
	chapter_row.add_child(UIKit.button("›", GlowButton.Variant.QUIET, SceneRouter.go.bind(&"S04")))

	_stage = BeaconStage.new()
	_stage.chapter_id = _chapter_id
	_stage.custom_minimum_size = Vector2(0, 280)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_stage)
	_daily_button = UIKit.button(tr("Дар дня"), GlowButton.Variant.QUIET, SceneRouter.open_modal.bind(&"S03"))
	_daily_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_daily_button.position = Vector2(0, -56)
	_stage.add_child(_daily_button)
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS

	column.add_child(_build_progress())
	_cta = BeaconCTA.new()
	_cta.chapter_id = _chapter_id
	_cta.deposited.connect(_on_deposited)
	_cta.tier_lit.connect(_on_tier_lit)
	_cta.need_sparks.connect(_on_need_sparks)
	_cta.maxed_pressed.connect(SceneRouter.go.bind(&"S04"))
	column.add_child(_cta)
	_gift = UIKit.button(tr("+300 Искр"), GlowButton.Variant.QUIET, AdManager.show_rewarded.bind(&"hub_sparks"))
	_gift.ad = true
	column.add_child(_gift)
	column.add_child(UIKit.gap(UITokens.S8)) # Ember «В БОЙ» выступает над таб-баром

	_tab_bar = GlowTabBar.new()
	_tab_bar.active = &"S02"
	column.add_child(_tab_bar)
	EventBus.screen_changed.connect(_on_screen_changed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.cloud_sync_state_changed.connect(_on_sync_state)
	_refresh()


func on_screen_enter(params: Dictionary) -> void:
	if bool(params.get("open_daily", false)):
		SceneRouter.open_modal.call_deferred(&"S03")
	else:
		_run_queue.call_deferred()


## Очередь отложенных событий: кат-сцена → новые Огоньки → сундуки. Вызывается и после закрытия модалов.
func _run_queue() -> void:
	if not is_inside_tree() or _cutscene != null or SceneRouter.top_screen_id() != &"S02":
		return
	var profile: PlayerProfile = GameManager.profile
	var state: PlayerProfile.BeaconState = profile.get_beacon(_chapter_id)
	var milestone: int = BeaconService.pending_milestone(profile, _chapter_id)
	if state.pending_tier_cutscene or milestone > 0:
		var tier: int = 0
		if state.pending_tier_cutscene:
			tier = floori(float(state.level) / BeaconService.levels_per_tier())
		_play_cutscene(tier, milestone)
		return
	if not profile.skins_to_reveal.is_empty():
		SceneRouter.open_modal(&"S14", {"skin": profile.skins_to_reveal[0]})
		return
	for reward: Dictionary in profile.pending_rewards:
		if reward.has("chest"):
			SceneRouter.open_modal(&"S17", {"pending": true})
			return


func _play_cutscene(tier: int, milestone: int) -> void:
	_cta.release()
	_cutscene = BeaconCutscene.new()
	add_child(_cutscene)
	_cutscene.flash_peak.connect(_refresh)
	_cutscene.finished.connect(_on_cutscene_finished.bind(milestone))
	_cutscene.play(_chapter_id, tier, milestone)


func _on_cutscene_finished(skipped: bool, milestone: int) -> void:
	BeaconService.mark_cutscene_seen(GameManager.profile, _chapter_id, milestone, skipped)
	_cutscene = null
	_refresh()
	_run_queue.call_deferred()


func _on_deposited(_levels: int) -> void:
	_stage.flash_rune()
	_refresh()
	if BeaconService.pending_milestone(GameManager.profile, _chapter_id) > 0 \
			and not BeaconService.is_tier_ready(GameManager.profile, _chapter_id):
		_run_queue.call_deferred()


func _on_tier_lit(_tier: int) -> void:
	_run_queue()


## Искр не хватает: Ember «В БОЙ» вспыхивает — туда за Искрами.
func _on_need_sparks() -> void:
	var ember: EmberButton = _tab_bar.ember
	var t: Tween = UIMotion.tween(ember)
	t.tween_property(ember, ^"scale", Vector2.ONE * 1.12, 0.12)
	t.tween_property(ember, ^"scale", Vector2.ONE, 0.24)


func _on_screen_changed(id: StringName) -> void:
	_refresh()
	if id == &"S02":
		_run_queue.call_deferred()


func _on_currency_changed(_currency: StringName, _total: int, _delta: int) -> void:
	_refresh()


func _on_sync_state(state: StringName) -> void:
	_cta.syncing = state == &"syncing"
	_cta.refresh()


func _refresh() -> void:
	if _cta == null:
		return
	var profile: PlayerProfile = GameManager.profile
	_stage.refresh()
	_cta.refresh()
	# Бюджет glow: CTA активна → Ember без свечения; Искр не хватает → Ember «дышит».
	_tab_bar.ember.glow_enabled = _cta.state in [BeaconCTA.State.DISABLED, BeaconCTA.State.MAXED]
	_gift.visible = _cta.state == BeaconCTA.State.DISABLED and StoreManager.free_gift_ready()
	var available: bool = DailyGiftService.is_available(profile)
	_daily_button.set_label(("● " if available else "") + tr("Дар дня"))
	var level: int = BeaconService.level(profile, _chapter_id)
	var per_tier: int = BeaconService.levels_per_tier()
	_progress_pct.text = "%d%%" % level
	if BeaconService.is_max(profile, _chapter_id):
		_progress_title.text = tr("Маяк восстановлен · все баффы активны")
		_next_label.text = ""
	else:
		var next_tier: int = floori(float(level) / per_tier) + 1
		var left: int = next_tier * per_tier - level
		_progress_title.text = tr("До тира %d · ещё %d ур.") % [next_tier, left]
		var parts: Array[String] = []
		var buff_text: String = BeaconBuffText.buff(BeaconService.buff_for(next_tier))
		if not buff_text.is_empty():
			parts.append(buff_text)
		var reward_text: String = BeaconBuffText.reward(BeaconService.reward_for(_chapter_id, next_tier))
		if not reward_text.is_empty():
			parts.append(reward_text)
		_next_label.text = tr("Дальше: %s") % " · ".join(parts)
	_tier_bar.queue_redraw()
	_total_bar.queue_redraw()


func _build_progress() -> Control:
	var box: VBoxContainer = UIKit.vbox(UITokens.S1)
	var head: HBoxContainer = UIKit.hbox()
	box.add_child(head)
	_progress_title = UIKit.label("", &"body_s", UITokens.TEXT_SECONDARY)
	_progress_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_progress_title)
	_progress_pct = UIKit.label("", &"number", UITokens.LIGHT_500)
	head.add_child(_progress_pct)
	_tier_bar = Control.new()
	_tier_bar.custom_minimum_size = Vector2(0, 10)
	_tier_bar.draw.connect(_draw_tier_bar)
	box.add_child(_tier_bar)
	_total_bar = Control.new()
	_total_bar.custom_minimum_size = Vector2(0, 8)
	_total_bar.draw.connect(_draw_total_bar)
	box.add_child(_total_bar)
	_next_label = UIKit.label("", &"body_s", UITokens.TEXT_MUTED)
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_next_label)
	return box


## Тир-бар: 10 сегментов текущего тира («оранжевое топливо» light.700 → spark).
func _draw_tier_bar() -> void:
	var per_tier: int = BeaconService.levels_per_tier()
	var level: int = BeaconService.level(GameManager.profile, _chapter_id)
	var lit: int = per_tier if BeaconService.is_max(GameManager.profile, _chapter_id) else level % per_tier
	var gap: float = 4.0
	var w: float = (_tier_bar.size.x - gap * (per_tier - 1)) / per_tier
	for i: int in per_tier:
		var rect: Rect2 = Rect2(Vector2(i * (w + gap), 0), Vector2(w, _tier_bar.size.y))
		var color: Color = UITokens.LIGHT_700.lerp(UITokens.SPARK, float(i) / per_tier) if i < lit else UITokens.INK_600
		_tier_bar.draw_rect(rect, color)


## Общая линия 0–100 с вехами 25/50/75/100.
func _draw_total_bar() -> void:
	var s: Vector2 = _total_bar.size
	var level: int = BeaconService.level(GameManager.profile, _chapter_id)
	var k: float = float(level) / BeaconService.max_level()
	_total_bar.draw_rect(Rect2(Vector2(0, s.y * 0.5 - 1.0), Vector2(s.x, 2.0)), UITokens.LINE_STRONG)
	_total_bar.draw_rect(Rect2(Vector2(0, s.y * 0.5 - 1.0), Vector2(s.x * k, 2.0)), UITokens.LIGHT_500)
	for m: Variant in BeaconService.config().get("milestones", []):
		var x: float = s.x * float(m) / BeaconService.max_level()
		var reached: bool = level >= int(m)
		_total_bar.draw_circle(Vector2(clampf(x, 4.0, s.x - 4.0), s.y * 0.5), 3.5, UITokens.RUNE if reached else UITokens.LINE_STRONG)


func _pill(currency: StringName) -> CurrencyPill:
	var pill: CurrencyPill = CurrencyPill.new()
	pill.currency = currency
	return pill
