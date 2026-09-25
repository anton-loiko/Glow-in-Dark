extends Control
## S04 · Выбор главы (DS S04): пройдена ✓ / СЕЙЧАС / закрыта (условие). Тап по открытой — выбор,
## по закрытой — покачивание и тост с условием. Primary «ИГРАТЬ · ГЛАВА N» → S05 («нырок в свет» 600 мс).

var _selected: int = 1
var _play: GlowButton
var _cards: Dictionary = {}


func _ready() -> void:
	_selected = GameManager.profile.current_chapter
	var column: VBoxContainer = UIKit.screen_root(self)
	var header: HBoxContainer = UIKit.hbox(UITokens.S3)
	column.add_child(header)
	header.add_child(UIKit.button("‹", GlowButton.Variant.ICON, SceneRouter.go.bind(&"S02")))
	header.add_child(UIKit.mono(tr("Главы"), UITokens.TEXT_MUTED))
	for id: int in [1, 2, 3]:
		var chapter: ChapterDef = ConfigDB.get_chapter(id)
		if chapter != null:
			var card: Button = _card(chapter)
			_cards[id] = card
			column.add_child(card)
	column.add_child(UIKit.spacer())
	_play = UIKit.button("", GlowButton.Variant.PRIMARY, _on_play)
	column.add_child(_play)
	_refresh()


## Текущая глава — самая дальняя открытая и ещё не пройденная.
func _current_chapter() -> int:
	var profile: PlayerProfile = GameManager.profile
	var current: int = 1
	for id: int in [1, 2, 3]:
		var chapter: ChapterDef = ConfigDB.get_chapter(id)
		if chapter != null and profile.unlocked_chapters.has(id):
			current = id
			if profile.best_time_s.get(id, 0.0) < chapter.duration_s:
				break
	return current


func _card(chapter: ChapterDef) -> Button:
	var profile: PlayerProfile = GameManager.profile
	var unlocked: bool = profile.unlocked_chapters.has(chapter.id)
	var best: float = profile.best_time_s.get(chapter.id, 0.0)
	var cleared: bool = best >= chapter.duration_s
	var current: bool = unlocked and not cleared and chapter.id == _current_chapter()
	var card: Button = Button.new()
	card.theme_type_variation = &"ButtonQuiet"
	card.custom_minimum_size = Vector2(0, 148 if current else 100)
	card.pressed.connect(_on_card.bind(chapter.id, unlocked))
	var row: HBoxContainer = UIKit.hbox(UITokens.S3)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UITokens.S4
	row.offset_right = -UITokens.S4
	row.offset_top = UITokens.S4
	row.offset_bottom = -UITokens.S4
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(_thumb(chapter, unlocked, 76.0 if current else 64.0))
	var box: VBoxContainer = UIKit.vbox(2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	# Статус читается в грейскейле: ✓ пройдена · бейдж «СЕЙЧАС» · закрыта + замок и пунктир (правило 6).
	if current:
		box.add_child(_now_badge())
	else:
		var state: String = tr("✓ Пройдена") if cleared else (tr("Открыта") if unlocked else tr("Закрыта"))
		box.add_child(UIKit.mono(tr("Глава %d · %s") % [chapter.id, state], UITokens.TEXT_MUTED))
	box.add_child(UIKit.label(tr(chapter.name_key), &"h2", UITokens.TEXT_PRIMARY if unlocked else UITokens.TEXT_MUTED))
	if not unlocked:
		box.add_child(UIKit.label(tr("Откроется: Маяк главы %d на 100%%") % int(chapter.unlock.get("beacon_chapter", chapter.id - 1)), &"body_s", UITokens.TEXT_MUTED))
	elif current:
		box.add_child(UIKit.label(tr("Цель: продержаться %s") % UIKit.format_time(chapter.duration_s), &"body_s", UITokens.TEXT_SECONDARY))
		if best > 0.0:
			box.add_child(UIKit.label(tr("Рекорд %s") % UIKit.format_time(best), &"body_s", UITokens.TEXT_MUTED))
		var bar: Control = Control.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(_draw_marks.bind(bar, best / chapter.duration_s))
		box.add_child(bar)
	elif best > 0.0:
		box.add_child(UIKit.label(tr("Рекорд %s") % UIKit.format_time(best), &"body_s", UITokens.TEXT_SECONDARY))
	card.draw.connect(_draw_card.bind(card, chapter.id, unlocked))
	return card


func _now_badge() -> Control:
	var holder: HBoxContainer = UIKit.hbox()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(UITokens.LIGHT_500, 0.12)
	st.border_color = UITokens.LIGHT_500
	st.set_border_width_all(1)
	st.set_corner_radius_all(UITokens.R8)
	st.content_margin_left = 6
	st.content_margin_right = 6
	badge.add_theme_stylebox_override(&"panel", st)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UIKit.mono(tr("Сейчас"), UITokens.LIGHT_500))
	holder.add_child(badge)
	return holder


## Миниатюра биома (диорама главы), скруглённая r14; закрытая — пунктир и замок.
func _thumb(chapter: ChapterDef, unlocked: bool, side: float) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.set_corner_radius_all(UITokens.R14)
	st.anti_aliasing = true
	if not unlocked:
		st.bg_color = Color(0, 0, 0, 0)
		frame.add_theme_stylebox_override(&"panel", st)
		frame.draw.connect(func() -> void:
			var pts: PackedVector2Array = ButtonFace.rounded_rect(Rect2(Vector2.ONE, frame.size - Vector2.ONE * 2.0), UITokens.R14)
			pts.append(pts[0])
			for k: int in pts.size() - 1:
				frame.draw_dashed_line(pts[k], pts[k + 1], UITokens.LINE_STRONG, 1.0, 5.0)
			# Замок: дужка + корпус.
			var c: Vector2 = frame.size * 0.5
			frame.draw_arc(c + Vector2(0, -3), 6.0, PI, TAU, 12, UITokens.TEXT_MUTED, 2.0, true)
			frame.draw_line(c + Vector2(-6, -3), c + Vector2(-6, 1), UITokens.TEXT_MUTED, 2.0, true)
			frame.draw_line(c + Vector2(6, -3), c + Vector2(6, 1), UITokens.TEXT_MUTED, 2.0, true)
			var body: StyleBoxFlat = StyleBoxFlat.new()
			body.bg_color = UITokens.TEXT_MUTED
			body.set_corner_radius_all(3)
			frame.draw_style_box(body, Rect2(c + Vector2(-9, 1), Vector2(18, 13))))
		return frame
	st.bg_color = UITokens.INK_600
	frame.add_theme_stylebox_override(&"panel", st)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var path: String = "res://src/assets/beacon/hub_diorama_ch%d.png" % chapter.id
	if ResourceLoader.exists(path):
		var pic: TextureRect = TextureRect.new()
		pic.texture = load(path) as Texture2D
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
	return frame


## Прогресс главы: 5 сегментов по 2 минуты (лучшее время / длительность).
func _draw_marks(bar: Control, k: float) -> void:
	var gap: float = 4.0
	var w: float = (bar.size.x - gap * 4.0) / 5.0
	for i: int in 5:
		var filled: bool = k >= float(i + 1) / 5.0 - 0.001
		bar.draw_rect(Rect2(Vector2(i * (w + gap), 0), Vector2(w, bar.size.y)), UITokens.SPARK if filled else UITokens.LINE_STRONG)


func _on_card(id: int, unlocked: bool) -> void:
	if not unlocked:
		UIMotion.shake(_cards[id] as Control)
		EventBus.toast_requested.emit(tr("Откроется, когда Маяк прошлой главы засияет на 100%"), &"lock")
		return
	_selected = id
	_refresh()


func _refresh() -> void:
	_play.set_label(tr("Играть · глава %d") % _selected)
	for card: Variant in _cards.values():
		(card as Control).queue_redraw()


func _on_play() -> void:
	GameManager.start_run(_selected)


func _draw_card(card: Button, id: int, unlocked: bool) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UITokens.INK_700
	box.set_corner_radius_all(UITokens.R16)
	if id == _selected:
		box.set_border_width_all(2)
		box.border_color = UITokens.LIGHT_500
		box.shadow_color = Color(UITokens.LIGHT_500, 0.25)
		box.shadow_size = 8
	elif not unlocked:
		box.bg_color = Color(0, 0, 0, 0)
	card.draw_style_box(box, Rect2(Vector2.ZERO, card.size))
	if not unlocked and id != _selected:
		var pts: PackedVector2Array = ButtonFace.rounded_rect(Rect2(Vector2.ONE, card.size - Vector2.ONE * 2.0), UITokens.R16)
		pts.append(pts[0])
		for k: int in pts.size() - 1:
			card.draw_dashed_line(pts[k], pts[k + 1], UITokens.LINE_STRONG, 1.0, 6.0)
