extends Node
## Сохранение профиля в JSON.
## Запись атомарная: profile.json.tmp → (profile.json → profile.bak.json) → profile.json.
## Во время забега профиль на диск не пишется: искры забега живут в RunContext и зачисляются
## одной транзакцией на S09. Исключение — критичные операции (трата Кристаллов, покупки): request_save(true).

signal saved

const FILE_NAME: String = "profile.json"
const TMP_NAME: String = "profile.json.tmp"
const BAK_NAME: String = "profile.bak.json"
const LEGACY_NAME: String = "save_data.cfg"
const LEGACY_MIGRATED_NAME: String = "save_data.cfg.migrated"

## Миграции схемы: версия N → N+1. Callable принимает и возвращает Dictionary.
var migrations: Dictionary[int, Callable] = {}

var save_dir: String = "user://"
var debounce_s: float = 1.0
var write_count: int = 0

var _profile: PlayerProfile
var _run_active: bool = false
var _dirty: bool = false
var _debounce_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


func bind_profile(profile: PlayerProfile) -> void:
	_profile = profile


func is_run_active() -> bool:
	return _run_active


## Включается на время забега: обычные сохранения откладываются до его конца.
func set_run_active(active: bool) -> void:
	_run_active = active
	if not active and _dirty:
		request_save()


## Сохранение с задержкой debounce_s (по реальному времени, не зависит от time_scale).
func request_save(critical: bool = false) -> void:
	if _run_active and not critical:
		_dirty = true
		_log("save deferred: run is active")
		return
	if critical:
		_write_now()
		return
	_dirty = true
	if _debounce_pending:
		return
	_debounce_pending = true
	var timer: SceneTreeTimer = get_tree().create_timer(debounce_s, true, false, true)
	timer.timeout.connect(_on_debounce_timeout)


## Немедленная запись несохранённых изменений (уход приложения в фон, выход, после S09).
func flush(critical: bool = false) -> void:
	if _run_active and not critical:
		_log("flush skipped: run is active")
		return
	if _dirty or critical:
		_write_now()


func load_profile() -> PlayerProfile:
	for file_name: String in [FILE_NAME, TMP_NAME, BAK_NAME]:
		var data: Dictionary = _read_json(_path(file_name))
		if not data.is_empty():
			if file_name != FILE_NAME:
				push_warning("[SaveManager] profile restored from %s" % file_name)
			return PlayerProfile.from_dict(migrate_dict(data))

	var legacy_path: String = _path(LEGACY_NAME)
	if FileAccess.file_exists(legacy_path):
		var config: ConfigFile = ConfigFile.new()
		if config.load(legacy_path) == OK:
			var migrated: PlayerProfile = LegacySaveMigration.migrate(config)
			_profile = migrated
			if _write_now():
				DirAccess.rename_absolute(_abs(legacy_path), _abs(_path(LEGACY_MIGRATED_NAME)))
			_log("legacy save migrated to schema v%d" % PlayerProfile.SCHEMA_VERSION)
			return migrated

	return PlayerProfile.create_new()


func migrate_dict(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("schema_version", PlayerProfile.SCHEMA_VERSION))
	if version > PlayerProfile.SCHEMA_VERSION:
		push_warning("[SaveManager] profile schema v%d is newer than app v%d" % [version, PlayerProfile.SCHEMA_VERSION])
		return data
	while version < PlayerProfile.SCHEMA_VERSION:
		if not migrations.has(version):
			push_error("[SaveManager] no migration from schema v%d" % version)
			break
		data = migrations[version].call(data)
		version += 1
		data["schema_version"] = version
	return data


func _on_debounce_timeout() -> void:
	_debounce_pending = false
	flush()


func _write_now() -> bool:
	if _profile == null:
		push_error("[SaveManager] no profile bound")
		return false
	_profile.updated_at = int(Time.get_unix_time_from_system())
	var main_path: String = _path(FILE_NAME)
	var tmp_path: String = _path(TMP_NAME)
	var bak_path: String = _path(BAK_NAME)

	DirAccess.make_dir_recursive_absolute(_abs(save_dir))
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] cannot open %s: %s" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(_profile.to_dict(), "\t"))
	file.close()

	if FileAccess.file_exists(main_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(_abs(bak_path))
		DirAccess.rename_absolute(_abs(main_path), _abs(bak_path))
	var err: Error = DirAccess.rename_absolute(_abs(tmp_path), _abs(main_path))
	if err != OK:
		push_error("[SaveManager] cannot move tmp to %s: %s" % [main_path, error_string(err)])
		return false

	_dirty = false
	write_count += 1
	_log("profile written (#%d)" % write_count)
	saved.emit()
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_warning("[SaveManager] corrupted save ignored: %s" % path)
	return {}


func _path(file_name: String) -> String:
	return save_dir.path_join(file_name)


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _log(message: String) -> void:
	if OS.is_debug_build():
		print("[SaveManager] ", message)
