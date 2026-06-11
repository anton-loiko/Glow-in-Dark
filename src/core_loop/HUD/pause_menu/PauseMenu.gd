extends Control
class_name PauseMenu

@onready var level_label: Label = %LevelLabel
@onready var sparks_label: Label = %SparksLabel
@onready var skills_grid: GridContainer = %SkillsGrid
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton

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
	# Обновление общих статов забега
	level_label.text = "Текущий уровень: " + str(GameManager.current_level)
	sparks_label.text = "Всего искр: " + str(GameManager.sparks)
	
	# Очистка старых иконок навыков
	for child in skills_grid.get_children():
		child.queue_free()
		
	# Отображение уже выбранных навыков
	for skill_id in GameManager.active_skills:
		if GameManager.SKILLS_DB.has(skill_id):
			var skill_data = GameManager.SKILLS_DB[skill_id]
			
			# Создаем простую цветную текстуру-иконку для отображения в строке
			var tex_rect = TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(24, 24)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			if ResourceLoader.exists(skill_data["icon"]):
				tex_rect.texture = load(skill_data["icon"])
			
			# Подкрашиваем иконку в цвет категории для быстрого считывания UX
			tex_rect.modulate = skill_data["bg_color"]
			skills_grid.add_child(tex_rect)

func _on_resume_pressed() -> void:
	hide()
	get_tree().paused = false

func _on_menu_button_pressed() -> void:
	hide()
	get_tree().paused = false
	GameManager.go_to_main_menu()
