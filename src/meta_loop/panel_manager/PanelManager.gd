extends MarginContainer

@onready var shop_button: Button = %ShopButton
@onready var skills_button: Button = %SkillsButton
@onready var home_button: Button = %HomeButton
@onready var gear_button: Button = %GearButton
@onready var ranked_button: Button = %RankedButton

@onready var shop_panel: PanelContainer = %ShopPanel
@onready var skills_panel: PanelContainer = %SkillsPanel
@onready var home_panel: PanelContainer = %HomePanel
@onready var gear_panel: PanelContainer = %GearPanel
@onready var ranked_panel: PanelContainer = %RankedPanel

func _ready() -> void:
	show_panel(home_panel)
	home_button.grab_focus()
	home_button.button_pressed = true

	shop_button.pressed.connect(show_panel.bind(shop_panel))
	skills_button.pressed.connect(show_panel.bind(skills_panel))
	home_button.pressed.connect(show_panel.bind(home_panel))
	gear_button.pressed.connect(show_panel.bind(gear_panel))
	ranked_button.pressed.connect(show_panel.bind(ranked_panel))
	

func show_panel(panel_to_show: PanelContainer) -> void:
	_hide_all_panels()
	panel_to_show.show()

func _hide_all_panels()->void:
	shop_panel.hide()
	skills_panel.hide()
	home_panel.hide()
	gear_panel.hide()
	ranked_panel.hide()
