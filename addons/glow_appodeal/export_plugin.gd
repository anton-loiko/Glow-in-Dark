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


func _get_android_dependencies_maven_repos(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["https://artifactory.appodeal.com/appodeal"])
