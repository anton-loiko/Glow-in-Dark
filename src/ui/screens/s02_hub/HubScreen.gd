extends Control
## S02 · Хаб (DS S02, Meta DS §02): сверху вниз — статус · валюта · глава · Маяк · прогресс · CTA · навигация.
## Очередь после входа: кат-сцена тира/вехи (если не показана) → S14 новых Огоньков → сундуки из pending_rewards.

const DAILY_CHEST: Texture2D = preload("res://src/assets/chests/chest_basic_closed.png")

var _chapter_id: int = 1
var _stage: BeaconStage
var _cta: BeaconCTA
var _gift: GlowButton
var _progress_title: Label
var _progress_pct: Label
var _tier_bar: Control
var _total_bar: Control
var _next_label: RichTextLabel
var _daily: Button
var _daily_dot: Control
var _tab_bar: GlowTabBar
var _cutscene: BeaconCutscene
var _sparks_pill: CurrencyPill
var _flow: SparkFlow


func _ready() -> void:
	_chapter_id = GameManager.profile.current_chapter
	var column: VBoxContainer = UIKit.screen_root(self)
	var top: HBoxContainer = UIKit.hbox(UITokens.S2)
	column.add_child(top)
	var settings: GlowButton = UIKit.button("⚙", GlowButton.Variant.ICON, SceneRouter.go.bind(&"S13"))
	top.add_child(settings)
	top.add_child(UIKit.spacer(false))
	_sparks_pill = _pill(GameManager.SPARKS)
	top.add_child(_sparks_pill)
	top.add_child(_pill(GameManager.CRYSTALS))

	# Глава: янтарная mono-метка + «Маяк» display (Meta DS §02 S02 v2); тап → S04.
	var chapter: ChapterDef = ConfigDB.get_chapter(_chapter_id)
	var chapter_title: Button = Button.new()
	chapter_title.theme_type_variation = &"ButtonQuiet"
	chapter_title.text = (tr("Глава %d · %s") % [chapter.id, tr(chapter.name_key)]).to_upper()
	chapter_title.custom_minimum_size.y = UITokens.TOUCH_MIN
	UIFonts.apply(chapter_title, &"label", UITokens.LIGHT_500)
	chapter_title.pressed.connect(SceneRouter.go.bind(&"S04"))
	column.add_child(chapter_title)
	var beacon_title: Label = UIKit.label(tr("Маяк"), &"display", UITokens.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	beacon_title.mouse_filter = Control.MOUSE_FILTER_STOP
	beacon_title.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			SceneRouter.go(&"S04"))
	column.add_child(beacon_title)

	_stage = BeaconStage.new()
	_stage.chapter_id = _chapter_id
	_stage.custom_minimum_size = Vector2(0, 280)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_stage)
	# «Дар дня» — объект диорамы: сундук с красной точкой и подписью (Meta DS: диорама по бокам — S03).
	_daily = _daily_prop()
	_stage.add_child(_daily)
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS

	column.add_child(_build_progress())
	_cta = BeaconCTA.new()
	_cta.chapter_id = _chapter_id
	_cta.deposited.connect(_on_deposited)
	_cta.tier_lit.connect(_on_tier_lit)
	_cta.need_sparks.connect(_on_need_sparks)
	_cta.maxed_pressed.connect(SceneRouter.go.bind(&"S04"))
	column.add_child(_cta)
	_gift = UIKit.ad_button(tr("+300 Искр"), GlowButton.Variant.QUIET, &"hub_sparks")
	column.add_child(_gift)
	column.add_child(UIKit.gap(UITokens.S8)) # Ember «В БОЙ» выступает над таб-баром

	_tab_bar = GlowTabBar.new()
	_tab_bar.active = &"S02"
	column.add_child(_tab_bar)
	_flow = SparkFlow.new()
	add_child(_flow)
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
	if GameManager.should_suggest_ghost():
		profile.contact_death_streak = 0
		EventBus.toast_requested.emit(tr("Попробуй Призрачного: враги наносят на 30% меньше урона"), &"skin")
	for item: PlayerProfile.GearItem in GearService.claim_pending_items(profile):
		EventBus.toast_requested.emit(tr("Новый предмет: %s") % GearText.item_name(item), &"gear")
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
	# Поток искр: пилюля → кристалл; при удержании поток гуще.
	var from: Vector2 = _sparks_pill.get_global_rect().get_center() - global_position
	var to: Vector2 = _stage.global_position - global_position + Vector2(_stage.size.x * 0.5, _stage.size.y * 0.78 - 100.0)
	_flow.emit(from, to, 10 if _cta.state == BeaconCTA.State.HOLDING else 5)
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
	_daily_dot.visible = DailyGiftService.is_available(profile)
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
		_next_label.text = _next_bbcode(next_tier * per_tier, BeaconService.buff_for(next_tier), BeaconService.reward_for(_chapter_id, next_tier))
	_tier_bar.queue_redraw()
	_total_bar.queue_redraw()


## «На 60%: +10% дохода Искр · Розовое Пламя» — иконка и имя скина в его цвете (Meta DS §02 Прогресс).
func _next_bbcode(pct: int, buff: Dictionary, reward: Dictionary) -> String:
	var parts: Array[String] = []
	var buff_text: String = BeaconBuffText.buff(buff)
	if not buff_text.is_empty():
		parts.append("[color=#%s]%s[/color]" % [UITokens.TEXT_PRIMARY.to_html(false), buff_text])
	var icon: String = ""
	var rest: Dictionary = reward.duplicate()
	if rest.has("skin"):
		var skin: SkinDef = ConfigDB.get_skin(StringName(str(rest["skin"])))
		rest.erase("skin")
		if skin != null:
			var hex: String = skin.light_color.to_html(false)
			icon = "[img=14x14 color=#%s]res://src/assets/brand/hero_ui_body.png[/img] " % hex
			parts.append("[color=#%s]%s[/color]" % [hex, tr(SkinService.display_name(skin.id))])
	var reward_text: String = BeaconBuffText.reward(rest)
	if not reward_text.is_empty():
		parts.append(reward_text)
	return icon + (tr("На %d%%:") % pct) + " " + " · ".join(parts)


func _daily_prop() -> Button:
	var prop: Button = Button.new()
	prop.flat = true
	prop.focus_mode = Control.FOCUS_NONE
	prop.custom_minimum_size = Vector2(88, 84)
	prop.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	prop.position = Vector2(4, -92)
	prop.pressed.connect(SceneRouter.open_modal.bind(&"S03"))
	var box: VBoxContainer = UIKit.vbox(2, BoxContainer.ALIGNMENT_CENTER)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prop.add_child(box)
	var chest: TextureRect = TextureRect.new()
	chest.texture = DAILY_CHEST
	chest.custom_minimum_size = Vector2(56, 52)
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(chest)
	box.add_child(UIKit.label(tr("Дар дня"), &"body_s", UITokens.TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))
	# Красная точка — «есть что забрать», без цифры (DS §02 BADGES).
	_daily_dot = Control.new()
	_daily_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_dot.position = Vector2(66, 8)
	_daily_dot.draw.connect(func() -> void:
		_daily_dot.draw_circle(Vector2.ZERO, 6.0, UITokens.INK_900)
		_daily_dot.draw_circle(Vector2.ZERO, 4.5, UITokens.THREAT))
	prop.add_child(_daily_dot)
	return prop


func _build_progress() -> Control:
	var box: VBoxContainer = UIKit.vbox(UITokens.S1)
	var head: HBoxContainer = UIKit.hbox()
	box.add_child(head)
	_progress_title = UIKit.label("", &"body_s", UITokens.TEXT_SECONDARY)
	_progress_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_progress_title)
	_progress_pct = UIKit.label("", &"h2", UITokens.LIGHT_500) # Unbounded 18
	head.add_child(_progress_pct)
	_tier_bar = Control.new()
	_tier_bar.custom_minimum_size = Vector2(0, 10)
	_tier_bar.draw.connect(_draw_tier_bar)
	box.add_child(_tier_bar)
	_total_bar = Control.new()
	_total_bar.custom_minimum_size = Vector2(0, 8)
	_total_bar.draw.connect(_draw_total_bar)
	box.add_child(_total_bar)
	_next_label = RichTextLabel.new()
	_next_label.bbcode_enabled = true
	_next_label.fit_content = true
	_next_label.scroll_active = false
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_label.add_theme_font_override(&"normal_font", UIFonts.font(&"body_s"))
	_next_label.add_theme_font_size_override(&"normal_font_size", 13)
	_next_label.add_theme_color_override(&"default_color", UITokens.TEXT_MUTED)
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
