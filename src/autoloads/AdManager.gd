extends Node

signal reward_earned()
signal ad_closed
signal ad_failed

var admob = null
var is_rewarded_loaded: bool = false
var is_interstitial_loaded: bool = false

# Официальные тестовые ID от Google (заменишь на свои реальные перед релизом)
const REWARDED_ID = "ca-app-pub-3940256099942544/5224354917"
const INTERSTITIAL_ID = "ca-app-pub-3940256099942544/1033173712"

func _ready() -> void:
	if Engine.has_singleton("GodotAdMob"):
		admob = Engine.get_singleton("GodotAdMob")
		admob.init(true, get_instance_id()) # Инициализация с тестовым режимом (true)
		
		admob.rewarded_ad_loaded.connect(func(): is_rewarded_loaded = true)
		admob.rewarded_ad_closed.connect(_on_rewarded_closed)
		admob.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
		admob.rewarded_user_earned_reward.connect(_on_rewarded_user_earned_reward)
		
		admob.interstitial_loaded.connect(func(): is_interstitial_loaded = true)
		admob.interstitial_closed.connect(_on_interstitial_closed)
		
		_load_all_ads()
	else:
		print("GodotAdMob плагин не найден. Режим симуляции рекламы (ПК).")
		is_rewarded_loaded = true
		is_interstitial_loaded = true

func _load_all_ads() -> void:
	if admob:
		admob.load_rewarded_ad(REWARDED_ID)
		admob.load_interstitial(INTERSTITIAL_ID)

func show_rewarded_ad() -> void:
	# FIXME: Probably it should be for "Foreced AD", not for rewarded.
	#if GameManager.has_no_ads:
		#reward_earned.emit()
		#return
		
	if admob and is_rewarded_loaded:
		is_rewarded_loaded = false
		admob.show_rewarded_ad()
	elif not admob:
		print("Симуляция просмотра Rewarded (ПК): Успешно")
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(func():
			reward_earned.emit()
			ad_closed.emit()
		)
	else:
		ad_failed.emit()
		_load_all_ads()

func show_interstitial_ad() -> void:
	if GameManager.has_no_ads:
		return
		
	if admob and is_interstitial_loaded:
		is_interstitial_loaded = false
		admob.show_interstitial()
	elif not admob:
		print("Симуляция просмотра Interstitial (ПК): Успешно")
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(func():
			ad_closed.emit()
		)

func _on_rewarded_closed() -> void:
	ad_closed.emit()
	_load_all_ads()

func _on_interstitial_closed() -> void:
	ad_closed.emit()
	_load_all_ads()

func _on_rewarded_ad_failed_to_load(err) -> void:
	print("[ERROR]::[_on_rewarded_ad_failed_to_load]:::: ", err)
	ad_failed.emit()
	
func _on_rewarded_user_earned_reward(reward_type, amount) -> void:
	print("[_on_rewarded_user_earned_reward]::[reward_type]::::", reward_type, "::[amount]:: ", amount)
	reward_earned.emit()
