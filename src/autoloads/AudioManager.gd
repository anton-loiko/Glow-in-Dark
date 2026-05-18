extends Node

var music_player: AudioStreamPlayer
var current_track_index: int = 0

var playlist: Array[AudioStream] = [
preload("res://src/assets/audio/Piano_1.ogg"),
preload("res://src/assets/audio/Piano_2.ogg"),
preload("res://src/assets/audio/Piano_3.ogg"),
preload("res://src/assets/audio/Piano_4.ogg"),
preload("res://src/assets/audio/Piano_5.ogg"),
preload("res://src/assets/audio/Piano_6.ogg"),
preload("res://src/assets/audio/Piano_7.ogg"),
preload("res://src/assets/audio/Piano_8.ogg"),
]


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	music_player.finished.connect(_on_music_finished)
	
	# Перемешиваем список песен случайным образом при запуске игры
	playlist.shuffle()
	
	play_current_track()


func play_current_track() -> void:
	# Берем трек из списка под текущим номером и передаем в плеер
	music_player.stream = playlist[current_track_index]
	music_player.play()

func _on_music_finished() -> void:
	# Увеличиваем номер трека на 1 (переходим к следующему)
	current_track_index += 1
	
	# Если мы вышли за пределы списка (треки закончились)
	if current_track_index >= playlist.size():
		current_track_index = 0 # Возвращаемся к первой песне
		playlist.shuffle()      # И снова перемешиваем плейлист
		
	play_current_track()

# Универсальная функция для воспроизведения любых коротких звуков
func play_sfx(stream: AudioStream) -> void:
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = stream
	add_child(sfx_player)
	sfx_player.play()
	
	# Подписываемся на встроенный сигнал окончания звука.
	# Когда звук доиграет, узел сам себя безопасно удалит из памяти.
	sfx_player.finished.connect(sfx_player.queue_free)
