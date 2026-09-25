extends Control

const font = preload("res://src/assets/fonts/Kenney/Kenney Pixel Square.ttf")

@onready var leaderboard_list_container: VBoxContainer = %LeaderboardList
@onready var leaderboard_status_label:Label = %LeaderboardStatusLabel
@onready var basePanel: PanelContainer = get_node("%BasePanel")  

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	LeaderboardManager.leaderboard_loaded.connect(_on_leaderboard_data_received)
	basePanel.visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if basePanel.visible:
		_fetch_leaderboard()

func _on_leaderboard_data_received(players: Array) -> void:
	leaderboard_status_label.text = ""
	leaderboard_status_label.hide()
	
	# Если массив пустой (интернета нет или в базе никого нет)
	if players.is_empty():
		leaderboard_status_label.show()
		leaderboard_status_label.text = "Unable to load the leaderboard"
		return
	
	for child in leaderboard_list_container.get_children():
		child.queue_free()
		
	# Перебираем массив игроков, полученный из LeaderboardManager
	var place = 1
	for player_info in players:
		# Создаем новый узел текста для каждой строчки таблицы
		var player_row = Label.new()
		
		player_row.add_theme_font_override("font", font)
		player_row.add_theme_font_size_override("font_size", 8)
		player_row.add_theme_color_override("font_color",Color(1.0, 1.0, 1.0, 1.0))

		# Формируем красивую строку, например: "1. Игрок_a3d8f1 — Уровень: 12"
		player_row.text = str(place) + ". " + player_info["name"] + " — Level: " + str(player_info["level"])

		# Выделяем первые три призовых места золотым цветом
		if place == 1:
			player_row.modulate = Color(1.0, 0.85, 0.2) # Золото
		elif place == 2:
			player_row.modulate = Color(0.75, 0.75, 0.75) # Серебро
		elif place == 3:
			player_row.modulate = Color(0.6, 0.4, 0.2) # Бронза
			
		# Добавляем готовую строчку внутрь вертикального списка на экране
		leaderboard_list_container.add_child(player_row)
		
		place += 1

func _fetch_leaderboard() -> void:
	#if leaderboard_list_container.get_children().size() <= 0:
	leaderboard_status_label.show()
	leaderboard_status_label.text = "Loading..."

	LeaderboardManager.fetch_top_players()
