@tool
extends EditorPlugin
## Регистрирует экспорт-плагин обёртки Appodeal (D17).

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("res://addons/glow_appodeal/export_plugin.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
