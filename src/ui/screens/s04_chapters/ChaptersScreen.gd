extends Control
## S04 · Выбор главы (DS S04): пройдена ✓ / СЕЙЧАС / закрыта (условие). Тап по открытой — выбор,
## по закрытой — покачивание и тост с условием. Primary «ИГРАТЬ · ГЛАВА N» → S05 («нырок в свет» 600 мс).

var _selected: int = 1
var _play: GlowButton
var _cards: Dictionary = {}


func _ready() -> void:
	_selected = GameManager.profile.current_chapter
	var column: VBoxContainer = UIKit.screen_root(self)
	var header: HBoxContainer = UIKit.hbox()
	column.add_child(header)
	header.add_child(UIKit.button("‹", GlowButton.Variant.QUIET, SceneRouter.go.bind(&"S02")))
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


func _card(chapter: ChapterDef) -> Button:
	var profile: PlayerProfile = GameManager.profile
	var unlocked: bool = profile.unlocked_chapters.has(chapter.id)
	var cleared: bool = profile.best_time_s.get(chapter.id, 0.0) >= chapter.duration_s
	var card: Button = Button.new()
	card.theme_type_variation = &"ButtonQuiet"
	card.custom_minimum_size = Vector2(0, 108)
	card.pressed.connect(_on_card.bind(chapter.id, unlocked))
	var box: VBoxContainer = UIKit.vbox(UITokens.S1)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = UITokens.S4
	box.offset_top = UITokens.S3
	card.add_child(box)
	var state: String = tr("✓ Пройдена") if cleared else (tr("Открыта") if unlocked else tr("Закрыта"))
	box.add_child(UIKit.mono(tr("Глава %d · %s") % [chapter.id, state], UITokens.GAIN if cleared else UITokens.TEXT_MUTED))
	box.add_child(UIKit.label(tr(chapter.name_key), &"h2"))
	var info: String = tr("Рекорд %s") % UIKit.format_time(profile.best_time_s.get(chapter.id, 0.0))
	if not unlocked:
		info = tr("Откроется: Маяк главы %d на 100%%") % int(chapter.unlock.get("beacon_chapter", chapter.id - 1))
	box.add_child(UIKit.label(info, &"body_s", UITokens.TEXT_SECONDARY))
	card.draw.connect(_draw_card.bind(card, chapter.id, unlocked))
	return card


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
		box.bg_color = Color(UITokens.INK_700, 0.5)
	card.draw_style_box(box, Rect2(Vector2.ZERO, card.size))
