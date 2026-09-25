extends GdUnitTestSuite
## Экраны помещаются в 390pt по ширине (DS: артборды 390 × 844): ни один контрол не требует больше —
## иначе контент вылезает за край (так было в S10 и S13 до ревью).

const WIDTH: float = 390.0
const SCREENS: Array[StringName] = [&"S02", &"S03", &"S04", &"S10", &"S11", &"S12", &"S13"]


func test_screens_fit_390pt() -> void:
	var host: Control = auto_free(Control.new())
	host.size = Vector2(WIDTH, 844)
	add_child(host)
	for id: StringName in SCREENS:
		var screen: Node = SceneRouter._instantiate(id)
		host.add_child(screen)
		await await_idle_frame()
		var widest: Array = [0.0, ""]
		_walk(screen, widest)
		assert_float(widest[0]).override_failure_message("%s: %s требует %.0fpt" % [id, widest[1], widest[0]]).is_less_equal(WIDTH)
		screen.queue_free()
		await await_idle_frame()


func _walk(node: Node, widest: Array) -> void:
	if node is Control and not node is ScrollContainer:
		var w: float = (node as Control).get_combined_minimum_size().x
		if w > float(widest[0]):
			widest[0] = w
			widest[1] = str(node.get_path())
	if node is ScrollContainer and (node as ScrollContainer).vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return # горизонтальные ленты (скины в S12) прокручиваются намеренно
	for child: Node in node.get_children():
		_walk(child, widest)
