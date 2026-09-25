extends Control
## S11 · Навыки · Архив (DS S11, D6 — без «Силы Огонька»): 12 рогалик-навыков V1, встреченные — в цвете
## категории, невстреченные — пунктир «?». Тап по навыку → описание пяти уровней и рецепт эволюции.

var _details: PanelContainer
var _details_box: VBoxContainer


func _ready() -> void:
	var column: VBoxContainer = UIKit.screen_root(self)
	column.add_child(UIKit.label(tr("Навыки"), &"h1"))
	var seen: Array[StringName] = GameManager.profile.skills_seen
	column.add_child(UIKit.mono(tr("Архив · %d/%d") % [seen.size(), SkillsManager.all_ids().size()]))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", UITokens.S3)
	grid.add_theme_constant_override(&"v_separation", UITokens.S3)
	column.add_child(grid)
	var ids: Array[StringName] = SkillsManager.all_ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return _rank(a) < _rank(b))
	for id: StringName in ids:
		grid.add_child(_tile(id, seen.has(id)))
	_details = UIKit.panel(&"PanelModal")
	_details.visible = false
	_details_box = UIKit.vbox(UITokens.S2)
	_details.add_child(_details_box)
	column.add_child(_details)
	column.add_child(UIKit.spacer())
	var tabs: GlowTabBar = GlowTabBar.new()
	tabs.active = &"S11"
	column.add_child(tabs)


func _rank(id: StringName) -> int:
	return int(OfferGenerator.CATEGORY_ORDER.get(SkillsManager.get_def(id).category, 3))


func _tile(id: StringName, seen: bool) -> Control:
	var def: SkillDef = SkillsManager.get_def(id)
	var tokens: Dictionary = UITokens.CATEGORY[def.category]
	var tile: Button = Button.new()
	tile.theme_type_variation = &"ButtonQuiet"
	tile.custom_minimum_size = Vector2(106, 96)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.text = def.display_name if seen else "?"
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_theme_color_override(&"font_color", tokens["300"] if seen else UITokens.TEXT_DISABLED)
	tile.add_theme_font_size_override(&"font_size", 12)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(UITokens.R16)
	box.bg_color = tokens["bg"] if seen else Color(0, 0, 0, 0)
	box.set_border_width_all(2 if seen else 0)
	box.border_color = tokens["700"]
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		tile.add_theme_stylebox_override(state, box)
	if not seen:
		tile.draw.connect(_draw_dashed.bind(tile))
	if seen:
		tile.pressed.connect(_show_details.bind(def))
	return tile


## Неоткрытое — пунктирный слот с «?» (DS §02 Иконография).
func _draw_dashed(tile: Button) -> void:
	var r: Rect2 = Rect2(Vector2.ONE, tile.size - Vector2.ONE * 2.0)
	for edge: Array in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		tile.draw_dashed_line(edge[0], edge[1], UITokens.LINE_STRONG, 1.5, 6.0)


func _show_details(def: SkillDef) -> void:
	for child: Node in _details_box.get_children():
		child.queue_free()
	_details_box.add_child(UIKit.label(def.display_name, &"h2"))
	for lvl: int in range(1, def.max_level + 1):
		var note: String = def.level_note(lvl)
		_details_box.add_child(UIKit.label(tr("Ур. %d: %s") % [lvl, def.level_value(lvl)] + ((" · " + note) if not note.is_empty() else ""), &"body_s", UITokens.TEXT_SECONDARY))
	var evolutions: Array = SkillsManager.get_tuning().get("evolutions", []) if ConfigDB.feature("evolutions_enabled") else []
	for evolution: Variant in evolutions:
		var requires: Dictionary = (evolution as Dictionary).get("requires", {}) as Dictionary
		if requires.has(String(def.id)):
			_details_box.add_child(UIKit.mono(tr("Эволюция: %s") % (evolution as Dictionary).get("name", ""), UITokens.GOLD_300))
	_details.visible = true
