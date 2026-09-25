extends MarginContainer

@onready var shop_button: Button = %ShopButton
@onready var skills_button: Button = %SkillsButton
@onready var home_button: Button = %HomeButton
@onready var gear_button: Button = %GearButton
@onready var base_button: Button = %BaseButton

@onready var shop_panel: PanelContainer = %ShopPanel
@onready var skills_panel: PanelContainer = %SkillsPanel
@onready var home_panel: PanelContainer = %HomePanel
@onready var gear_panel: PanelContainer = %GearPanel
@onready var base_panel: PanelContainer = %BasePanel
@onready var disable_description: Label = %DisableDescription

func _ready() -> void:
	show_panel(home_panel)
	home_button.grab_focus()
	home_button.button_pressed = true
	disable_description.hide()


	shop_button.pressed.connect(show_panel.bind(shop_panel))
	skills_button.pressed.connect(show_panel.bind(skills_panel))
	home_button.pressed.connect(show_panel.bind(home_panel))
	gear_button.pressed.connect(show_panel.bind(gear_panel))
	base_button.pressed.connect(show_panel.bind(base_panel))
	
	#base_button.lock()

func show_panel(panel_to_show: PanelContainer) -> void:
	_hide_all_panels()
	panel_to_show.show()

func _hide_all_panels()->void:
	shop_panel.hide()
	skills_panel.hide()
	home_panel.hide()
	gear_panel.hide()
	base_panel.hide()



# TODO: finihsed it with fake transparent button
func _show_disable_description() -> void:
	var tween = create_tween().set_parallel(true)
	disable_description.show()

	disable_description.scale = Vector2.ZERO
	disable_description.modulate.a = 0.3

	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(disable_description, "modulate:a", 1.0, 0.4)
	tween.tween_property(disable_description, "scale",  Vector2(4, 4), 0.4)
	
	tween.tween_property(disable_description, "modulate:a", 0, 4.0)
	tween.tween_property(disable_description, "scale",  Vector2.ZERO, 4.0)
 
