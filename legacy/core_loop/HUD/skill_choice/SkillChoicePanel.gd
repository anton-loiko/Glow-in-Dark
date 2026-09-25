extends Control
class_name SkillChoicePanel

const CLICK_SFX = preload("res://src/assets/audio/click_001.ogg")

@export var skill_card_scene: PackedScene = preload("res://src/core_loop/HUD/skill_choice/SkillCard.tscn")

@onready var cards_container: HBoxContainer = %CardsContainer
@onready var refresh_button: Button = %RefreshButton
@onready var reward_button: Button = %RewardButton
@onready var price_label: Label = %PriceLabel

const REFRESH_PRICES := [1, 40, 80, 100]

var current_refresh_price: int = REFRESH_PRICES[0]
var refresh_count = 0
var game_ui: GameUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS 
	hide()
	price_label.text = str(current_refresh_price)
	
	var parent = get_parent()
	game_ui = parent.get_node("UIControl")
	
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	reward_button.pressed.connect(_on_reward_button_pressed)
	visibility_changed.connect(_on_visibility_changed)
	EventBus.skill_choice_triggered.connect(_on_skill_choice_triggered)
	AdManager.reward_earned.connect(_on_reward_earned)

func disbale_refresh_button() -> void:
	refresh_button.disabled = game_ui.sparks_at_level < current_refresh_price

func set_price_label():
	price_label.text = str(current_refresh_price)

func _on_skill_choice_triggered() -> void:
	get_tree().paused = true
	show()
	_generate_cards()

func _generate_cards() -> void:
	# Очищаем старые карточки, если они остались от предыдущего выбора
	for child in cards_container.get_children():
		child.queue_free()

	# Получаем все доступные ID навыков и перемешиваем их
	var available_skills: Array = SkillsManager.SKILLS_DB.keys()
	available_skills.shuffle()
	
	var selected_skills: Array = available_skills.slice(0, 3)
	
	# Создаем инстансы карточек
	for skill_id in selected_skills:
		
		var card: SkillCard = skill_card_scene.instantiate() as SkillCard
		cards_container.add_child(card)
		card.setup(skill_id, SkillsManager.SKILLS_DB[skill_id])
		card.card_selected.connect(_on_card_selected)

func _on_card_selected(skill_id: String) -> void:
	GameManager.apply_skill(skill_id)
	
	# Задержка уже отработала внутри SkillCard.gd перед отправкой сигнала
	hide()
	get_tree().paused = false

func _on_refresh_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	refresh_count += 1
	
	_generate_cards()
	
	if refresh_count >= REFRESH_PRICES.size():
		current_refresh_price = REFRESH_PRICES[REFRESH_PRICES.size() - 1]
	else:
		current_refresh_price = REFRESH_PRICES[refresh_count] 
	
	game_ui.soft_currency.set_amount(game_ui.sparks_at_level - current_refresh_price)
	set_price_label()
	disbale_refresh_button()

func _on_reward_button_pressed() -> void:
	AudioManager.play_sfx(CLICK_SFX)
	reward_button.disabled = true
	AdManager.show_rewarded_ad()

func _on_visibility_changed() -> void:
	if not visible:
		return
	
	disbale_refresh_button()
	set_price_label()

func _on_reward_earned() -> void:
	if not visible:
		return

	_generate_cards()
	reward_button.disabled = false
