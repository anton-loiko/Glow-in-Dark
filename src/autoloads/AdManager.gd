extends Node

signal reward_earned(amount: int)
signal ad_closed
signal ad_failed
var is_ad_loaded: bool = false

func _ready() -> void:
	_load_ad()

func _load_ad() -> void:
	# Здесь будет вызов загрузки рекламы реального SDK (например, AdMob)
	is_ad_loaded = true

func show_rewarded_ad() -> void:
	if GameManager.has_no_ads:
		reward_earned.emit()
		return
		
	if is_ad_loaded:
		# Имитация просмотра видео (1 секунда задержки для тестов на ПК)
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(_on_ad_finished)
	else:
		ad_failed.emit()
		_load_ad()

func show_interstitial_ad() -> void:
	if GameManager.has_no_ads:
		return
		
	if is_ad_loaded:
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(_on_interstitial_finished)

func _on_ad_finished() -> void:
	reward_earned.emit()
	ad_closed.emit()
	_load_ad() 

func _on_interstitial_finished() -> void:
	ad_closed.emit()
	_load_ad()
