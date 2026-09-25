@tool
extends EditorExportPlugin
## Android: подключает AAR обёртки (plugins/appodeal/android → bin/), Appodeal SDK и адаптеры медиации
## из android_dependencies.txt и Maven-репозиторий Appodeal. Обновление SDK — правка одного текстового файла.

const PLUGIN_NAME: String = "GlowAppodeal"
const DEPENDENCIES_FILE: String = "res://addons/glow_appodeal/android_dependencies.txt"


func _get_name() -> String:
	return PLUGIN_NAME


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(["glow_appodeal/bin/GlowAppodeal.%s.aar" % ("debug" if debug else "release")])


func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	var deps: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(DEPENDENCIES_FILE).split("\n"):
		var dep: String = line.strip_edges()
		if not dep.is_empty() and not dep.begins_with("#"):
			deps.append(dep)
	return deps


## Адаптер AdMob в Appodeal требует APPLICATION_ID в манифесте, иначе краш при старте (найдено на эмуляторе).
func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://configs/ads.json"))
	var app_id: String = ""
	if parsed is Dictionary:
		app_id = str(((parsed as Dictionary).get("admob_app_id", {}) as Dictionary).get("android", ""))
	if app_id.is_empty():
		return ""
	return '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s" />\n' % app_id


func _get_android_dependencies_maven_repos(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["https://artifactory.appodeal.com/appodeal"])
