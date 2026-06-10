extends Control
class_name SkillChoicePanel

@export var skill_card_scene: PackedScene = preload("res://src/core_loop/HUD/skill_choice/SkillCard.tscn")

@onready var container: HBoxContainer = %CardsContainer

func _ready() -> void:
	hide()
	# Разрешаем этому узлу работать, когда вся игра стоит на паузе
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	GameManager.skill_choice_triggered.connect(_on_skill_choice_triggered)

func _on_skill_choice_triggered() -> void:
	get_tree().paused = true
	show()
	_generate_cards()

func _generate_cards() -> void:
	# Очищаем старые карточки, если они остались от предыдущего выбора
	for child in container.get_children():
		child.queue_free()

	# Получаем все доступные ID навыков и перемешиваем их
	var available_skills: Array = GameManager.SKILLS_DB.keys()
	available_skills.shuffle()
	
	# Берем ровно 3 (или меньше, если в базе их мало)
	var selected_skills: Array = available_skills.slice(0, min(3, available_skills.size()))

	# Создаем инстансы карточек
	for skill_id in selected_skills:
		var card: SkillCard = skill_card_scene.instantiate() as SkillCard
		container.add_child(card)
		card.setup(skill_id, GameManager.SKILLS_DB[skill_id])
		card.card_selected.connect(_on_card_selected)

func _on_card_selected(skill_id: String) -> void:
	GameManager.apply_skill(skill_id)
	
	# Задержка уже отработала внутри SkillCard.gd перед отправкой сигнала
	hide()
	get_tree().paused = false
