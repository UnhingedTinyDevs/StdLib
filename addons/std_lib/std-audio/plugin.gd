@tool
extends EditorPlugin

const AUTOLOAD_NAME: String = "StdAudio"
const AUTOLOAD_PATH: String = "res://addons/std_lib/std-audio/scripts/std_audio.gd"


#region Plugin Lifecycle
func _enable_plugin() -> void:
	var setting: String = "autoload/%s" % AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting):
		var current_path: String = _canonical_resource_path(
				str(ProjectSettings.get_setting(setting)).trim_prefix("*"))
		if current_path != AUTOLOAD_PATH:
			push_error("%s cannot enable: the host project already owns this autoload name" % AUTOLOAD_NAME)
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	return


func _disable_plugin() -> void:
	var setting: String = "autoload/%s" % AUTOLOAD_NAME
	if not ProjectSettings.has_setting(setting):
		return
	var current_path: String = _canonical_resource_path(
			str(ProjectSettings.get_setting(setting)).trim_prefix("*"))
	if current_path == AUTOLOAD_PATH:
		remove_autoload_singleton(AUTOLOAD_NAME)
	return


func _canonical_resource_path(path: String) -> String:
	if not path.begins_with("uid://"):
		return path
	var resource_id: int = ResourceUID.text_to_id(path)
	if resource_id == ResourceUID.INVALID_ID:
		return path
	var resolved_path: String = ResourceUID.get_id_path(resource_id)
	return resolved_path if not resolved_path.is_empty() else path
#endregion Plugin Lifecycle
