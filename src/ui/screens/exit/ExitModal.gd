extends Control
## Системный диалог выхода (DS §04: «назад» на S02).


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame: ModalFrame = ModalFrame.new()
	add_child(frame)
	var content: VBoxContainer = frame.build(tr("Выйти из игры?"))
	content.add_child(UIKit.label(tr("Прогресс сохранён."), &"body", UITokens.TEXT_SECONDARY))
	content.add_child(UIKit.button(tr("Выйти"), GlowButton.Variant.SECONDARY, SceneRouter.quit_game))
	content.add_child(UIKit.button(tr("Остаться"), GlowButton.Variant.QUIET, SceneRouter.close_top))
