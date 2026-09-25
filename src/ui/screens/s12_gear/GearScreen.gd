extends Control
## S12 · Экипировка и скины (DS S12, Gear DS §01): Огонёк в центре светит цветом надетого скина, 4 слота
## крестом, лента Огоньков. Каркас: предметы, прокачка, слияние и сундуки — task_6.

var _hero: Control
var _skins_row: HBoxContainer


func _ready() -> void:
	var column: VBoxContainer = UIKit.screen_root(self)
	column.add_child(UIKit.label(tr("Экипировка"), &"h1"))
	_hero = Control.new()
	_hero.custom_minimum_size = Vector2(0, 260)
	_hero.draw.connect(_draw_doll)
	column.add_child(_hero)
	column.add_child(UIKit.mono(tr("Огоньки")))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 64)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_skins_row = UIKit.hbox(UITokens.S2)
	scroll.add_child(_skins_row)
	_build_skins()
	column.add_child(UIKit.mono(tr("Инвентарь · %d / 40") % GameManager.profile.gear_inventory.size()))
	column.add_child(UIKit.spacer())
	var tabs: GlowTabBar = GlowTabBar.new()
	tabs.active = &"S12"
	column.add_child(tabs)


func _build_skins() -> void:
	for child: Node in _skins_row.get_children():
		child.queue_free()
	var profile: PlayerProfile = GameManager.profile
	for id: StringName in ConfigDB.get_skin_ids():
		var skin: SkinDef = ConfigDB.get_skin(id)
		var unlocked: bool = profile.skins_unlocked.has(id)
		var equipped: bool = profile.skin_equipped == id
		var b: GlowButton = UIKit.button(tr(_skin_name(id)), GlowButton.Variant.SECONDARY, _equip.bind(id))
		b.add_theme_color_override(&"font_color", skin.light_color)
		if equipped:
			b.set_label(tr("Надет"))
		elif not unlocked:
			b.set_blocked(true, _lock_text(skin))
		_skins_row.add_child(b)


func _equip(id: StringName) -> void:
	var profile: PlayerProfile = GameManager.profile
	if not profile.skins_unlocked.has(id) or profile.skin_equipped == id:
		return
	profile.skin_equipped = id
	profile.skins_new_badge.erase(id)
	SaveManager.request_save()
	EventBus.skin_equipped.emit(id)
	Telemetry.log_event(&"skin_equipped", {"id": String(id), "source": "s12"})
	_build_skins()
	_hero.queue_redraw()


func _lock_text(skin: SkinDef) -> String:
	if String(skin.unlock.get("type", "")) == "beacon":
		return tr("Маяк %d%%") % (int(skin.unlock.get("tier", 0)) * 10)
	return tr("Магазин")


func _skin_name(id: StringName) -> String:
	return {&"base": "Базовый", &"ghost": "Призрачный", &"plasma": "Плазменный", &"blue": "Синее Пламя",
		&"pink": "Розовое Пламя", &"inferno": "Инферно", &"solar": "Солнечный", &"moon": "Лунный"}.get(id, String(id))


func _draw_doll() -> void:
	var c: Vector2 = _hero.size * 0.5
	var skin: SkinDef = ConfigDB.get_skin(GameManager.profile.skin_equipped)
	var color: Color = skin.light_color if skin != null else UITokens.LIGHT_500
	for i: int in 6:
		_hero.draw_circle(c, 110.0 * (1.0 - i / 6.0), Color(color, 0.04))
	_hero.draw_circle(c + Vector2(0, 6), 26.0, color)
	_hero.draw_colored_polygon(PackedVector2Array([c + Vector2(-19, -6), c + Vector2(0, -36), c + Vector2(19, -6)]), color)
	var slots: Dictionary = {tr("Шлем"): Vector2(0, -100), tr("Ядро"): Vector2(-120, 0), tr("Амулет"): Vector2(120, 0), tr("Ботинки"): Vector2(0, 100)}
	var font: Font = UIFonts.font(&"label")
	for title: String in slots:
		var pos: Vector2 = c + (slots[title] as Vector2)
		var rect: Rect2 = Rect2(pos - Vector2(38, 38), Vector2(76, 76))
		for edge: Array in [[rect.position, Vector2(rect.end.x, rect.position.y)], [Vector2(rect.end.x, rect.position.y), rect.end], [rect.end, Vector2(rect.position.x, rect.end.y)], [Vector2(rect.position.x, rect.end.y), rect.position]]:
			_hero.draw_dashed_line(edge[0], edge[1], UITokens.LINE_STRONG, 1.5, 6.0)
		_hero.draw_string(font, pos + Vector2(-6, 6), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITokens.TEXT_MUTED)
		var w: float = font.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_hero.draw_string(font, pos + Vector2(-w * 0.5, 52), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UITokens.TEXT_MUTED)
