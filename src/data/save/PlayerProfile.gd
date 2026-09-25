class_name PlayerProfile
extends RefCounted
## Единая модель профиля игрока. Сериализуется в JSON через to_dict()/from_dict();
## отсутствующие ключи берут значения по умолчанию, StringName пишутся строками.

const SCHEMA_VERSION: int = 1
const GEAR_SLOTS: Array[StringName] = [&"head", &"core", &"feet", &"amulet", &"amulet_2"]

var schema_version: int = SCHEMA_VERSION

# wallet
var sparks: int = 0
var crystals: int = 0

# chapters
var current_chapter: int = 1
var unlocked_chapters: Array[int] = [1]
var best_time_s: Dictionary[int, float] = {}

# beacon: chapter_id -> состояние Маяка главы
var beacons: Dictionary[int, BeaconState] = {}

# skins
var skins_unlocked: Array[StringName] = [&"base"]
var skin_equipped: StringName = &"base"
var skins_new_badge: Array[StringName] = []

# gear
var gear_equipped: Dictionary[StringName, String] = {}
var gear_inventory: Array[GearItem] = []

# chests
var premium_pity: int = 0
var basic_ads_today: int = 0
var ads_day_stamp: int = 0

# skills archive
var skills_seen: Array[StringName] = []

# daily gift
var daily_streak_day: int = 0
var daily_last_claim_day: int = 0
var free_gift_ts: int = 0 ## последний бесплатный дар магазина (unix)
## Награды, которые выдаст система соответствующей задачи (предметы, сундуки — task_6).
var pending_rewards: Array[Dictionary] = []

# purchases
var starter_pack_bought: bool = false
var starter_pack_expires_at: int = 0
var receipts: Array[String] = []

var settings: Settings = Settings.new()

# meta
var install_ts: int = 0
var updated_at: int = 0
var device_id: String = ""


class BeaconState:
	var level: int = 0
	var pending_tier_cutscene: bool = false
	var seen_milestones: Array[int] = []

	func to_dict() -> Dictionary:
		return {
			"level": level,
			"pending_tier_cutscene": pending_tier_cutscene,
			"seen_milestones": seen_milestones.duplicate(),
		}

	static func from_dict(d: Dictionary) -> BeaconState:
		var s: BeaconState = BeaconState.new()
		s.level = int(d.get("level", 0))
		s.pending_tier_cutscene = bool(d.get("pending_tier_cutscene", false))
		for m: Variant in d.get("seen_milestones", []):
			s.seen_milestones.append(int(m))
		return s


class GearItem:
	var uid: String = ""
	var base_id: StringName
	var slot: StringName
	var rarity: StringName = &"common"
	var level: int = 1
	var sparks_invested: int = 0
	var is_new: bool = true

	func to_dict() -> Dictionary:
		return {
			"uid": uid,
			"base_id": String(base_id),
			"slot": String(slot),
			"rarity": String(rarity),
			"level": level,
			"sparks_invested": sparks_invested,
			"is_new": is_new,
		}

	static func from_dict(d: Dictionary) -> GearItem:
		var item: GearItem = GearItem.new()
		item.uid = str(d.get("uid", ""))
		item.base_id = StringName(str(d.get("base_id", "")))
		item.slot = StringName(str(d.get("slot", "")))
		item.rarity = StringName(str(d.get("rarity", "common")))
		item.level = int(d.get("level", 1))
		item.sparks_invested = int(d.get("sparks_invested", 0))
		item.is_new = bool(d.get("is_new", false))
		return item


class Settings:
	var music: bool = true
	var sfx: bool = true
	var vibration: bool = true
	var no_flashes: bool = false
	var camera_shake: bool = true
	var damage_numbers: int = 1 ## 0 выкл · 1 обычные · 2 крупные
	var language: String = ""

	func to_dict() -> Dictionary:
		return {
			"music": music,
			"sfx": sfx,
			"vibration": vibration,
			"no_flashes": no_flashes,
			"camera_shake": camera_shake,
			"damage_numbers": damage_numbers,
			"language": language,
		}

	static func from_dict(d: Dictionary) -> Settings:
		var s: Settings = Settings.new()
		s.music = bool(d.get("music", true))
		s.sfx = bool(d.get("sfx", true))
		s.vibration = bool(d.get("vibration", true))
		s.no_flashes = bool(d.get("no_flashes", false))
		s.camera_shake = bool(d.get("camera_shake", true))
		s.damage_numbers = int(d.get("damage_numbers", 1))
		s.language = str(d.get("language", ""))
		return s


func _init() -> void:
	for slot: StringName in GEAR_SLOTS:
		gear_equipped[slot] = ""


static func create_new() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new()
	var now: int = int(Time.get_unix_time_from_system())
	p.install_ts = now
	p.updated_at = now
	p.device_id = OS.get_unique_id()
	return p


func get_beacon(chapter_id: int) -> BeaconState:
	if not beacons.has(chapter_id):
		beacons[chapter_id] = BeaconState.new()
	return beacons[chapter_id]


func find_gear(uid: String) -> GearItem:
	for item: GearItem in gear_inventory:
		if item.uid == uid:
			return item
	return null


func to_dict() -> Dictionary:
	var beacon_dict: Dictionary = {}
	for chapter_id: int in beacons:
		beacon_dict[str(chapter_id)] = beacons[chapter_id].to_dict()
	var best_dict: Dictionary = {}
	for chapter_id: int in best_time_s:
		best_dict[str(chapter_id)] = best_time_s[chapter_id]
	var equipped_dict: Dictionary = {}
	for slot: StringName in gear_equipped:
		equipped_dict[String(slot)] = gear_equipped[slot]
	var inventory_list: Array = []
	for item: GearItem in gear_inventory:
		inventory_list.append(item.to_dict())
	return {
		"schema_version": schema_version,
		"wallet": {"sparks": sparks, "crystals": crystals},
		"chapters": {
			"current_id": current_chapter,
			"unlocked_ids": unlocked_chapters.duplicate(),
			"best_time_s": best_dict,
		},
		"beacon": beacon_dict,
		"skins": {
			"unlocked": _names_to_strings(skins_unlocked),
			"equipped": String(skin_equipped),
			"new_badge": _names_to_strings(skins_new_badge),
		},
		"gear": {"equipped": equipped_dict, "inventory": inventory_list},
		"chests": {
			"premium_pity": premium_pity,
			"basic_ads_today": basic_ads_today,
			"ads_day_stamp": ads_day_stamp,
		},
		"skills_archive": {"seen": _names_to_strings(skills_seen)},
		"daily": {"streak_day": daily_streak_day, "last_claim_day": daily_last_claim_day, "free_gift_ts": free_gift_ts},
		"pending_rewards": pending_rewards.duplicate(true),
		"purchases": {
			"starter_pack": {"bought": starter_pack_bought, "expires_at": starter_pack_expires_at},
			"receipts": receipts.duplicate(),
		},
		"settings": settings.to_dict(),
		"meta": {"install_ts": install_ts, "updated_at": updated_at, "device_id": device_id},
	}


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new()
	p.schema_version = int(d.get("schema_version", SCHEMA_VERSION))

	var wallet: Dictionary = d.get("wallet", {}) as Dictionary
	p.sparks = int(wallet.get("sparks", 0))
	p.crystals = int(wallet.get("crystals", 0))

	var chapters: Dictionary = d.get("chapters", {}) as Dictionary
	p.current_chapter = int(chapters.get("current_id", 1))
	p.unlocked_chapters.clear()
	for id: Variant in chapters.get("unlocked_ids", [1]):
		p.unlocked_chapters.append(int(id))
	var best: Dictionary = chapters.get("best_time_s", {}) as Dictionary
	for key: Variant in best:
		p.best_time_s[int(key)] = float(best[key])

	var beacon: Dictionary = d.get("beacon", {}) as Dictionary
	for key: Variant in beacon:
		p.beacons[int(key)] = BeaconState.from_dict(beacon[key] as Dictionary)

	var skins: Dictionary = d.get("skins", {}) as Dictionary
	p.skins_unlocked = DefUtil.to_string_names(skins.get("unlocked", ["base"]))
	p.skin_equipped = StringName(str(skins.get("equipped", "base")))
	p.skins_new_badge = DefUtil.to_string_names(skins.get("new_badge", []))

	var gear: Dictionary = d.get("gear", {}) as Dictionary
	var equipped: Dictionary = gear.get("equipped", {}) as Dictionary
	for key: Variant in equipped:
		var uid: Variant = equipped[key]
		p.gear_equipped[StringName(str(key))] = "" if uid == null else str(uid)
	for entry: Variant in gear.get("inventory", []):
		p.gear_inventory.append(GearItem.from_dict(entry as Dictionary))

	var chests: Dictionary = d.get("chests", {}) as Dictionary
	p.premium_pity = int(chests.get("premium_pity", 0))
	p.basic_ads_today = int(chests.get("basic_ads_today", 0))
	p.ads_day_stamp = int(chests.get("ads_day_stamp", 0))

	var archive: Dictionary = d.get("skills_archive", {}) as Dictionary
	p.skills_seen = DefUtil.to_string_names(archive.get("seen", []))

	var daily: Dictionary = d.get("daily", {}) as Dictionary
	p.daily_streak_day = int(daily.get("streak_day", 0))
	p.daily_last_claim_day = int(daily.get("last_claim_day", 0))
	p.free_gift_ts = int(daily.get("free_gift_ts", 0))
	for reward: Variant in d.get("pending_rewards", []):
		p.pending_rewards.append(reward as Dictionary)

	var purchases: Dictionary = d.get("purchases", {}) as Dictionary
	var starter: Dictionary = purchases.get("starter_pack", {}) as Dictionary
	p.starter_pack_bought = bool(starter.get("bought", false))
	p.starter_pack_expires_at = int(starter.get("expires_at", 0))
	for r: Variant in purchases.get("receipts", []):
		p.receipts.append(str(r))

	p.settings = Settings.from_dict(d.get("settings", {}) as Dictionary)

	var meta: Dictionary = d.get("meta", {}) as Dictionary
	p.install_ts = int(meta.get("install_ts", 0))
	p.updated_at = int(meta.get("updated_at", 0))
	p.device_id = str(meta.get("device_id", ""))
	return p


func duplicate_profile() -> PlayerProfile:
	return PlayerProfile.from_dict(to_dict())


static func _names_to_strings(names: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for n: StringName in names:
		out.append(String(n))
	return out
