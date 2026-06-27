extends Control
class_name PauseMenu


@onready var skills_grid: GridContainer = %SkillsGrid
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton

const SKILL_CARD_THUMB := preload("res://src/core_loop/HUD/skill_choice/SkillCardThumb/SkillCardThumb.tscn")

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func _notification(what: int) -> void:
	# Отслеживаем сворачивание приложения или потерю фокуса на Android/iOS
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# Ставим на паузу только если мы в процессе игры и экран смерти/победы не активен
		if get_tree() and not get_tree().paused and is_inside_tree():
			open_pause()

func open_pause() -> void:
	get_tree().paused = true
	_update_stats_and_skills()
	show()

func _update_stats_and_skills() -> void:
	# Очистка старых иконок навыков
	for child in skills_grid.get_children():
		child.queue_free()
	
	var active_skills_ids: Array = GameManager.active_skills.keys()
	# Отображение уже выбранных навыков
	for skill_id in active_skills_ids:
		if SkillsManager.SKILLS_DB.has(skill_id):
			var skill_data = SkillsManager.SKILLS_DB[skill_id]
			var active_skill = GameManager.active_skills[skill_id]
			
			var skill_card_thumb: SkillsCardThumb = SKILL_CARD_THUMB.instantiate()
			skills_grid.add_child(skill_card_thumb)
			
			if skill_card_thumb.has_method('setup') and skill_data and active_skill:
				skill_card_thumb.setup(skill_data, active_skill)
			else:
				print("[skill_data]:::::", skill_data)
				print("[active_skill]:::", active_skill)

func _on_resume_pressed() -> void:
	hide()
	get_tree().paused = false

func _on_menu_button_pressed() -> void:
	hide()
	get_tree().paused = false
	GameManager.go_to_main_menu()
