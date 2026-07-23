@tool
extends EditorPlugin
## Enables the verified StdLib module subplugins as one unit.


# Enable in dependency order. Disable uses the reverse of this list.
const SUBPLUGIN_IDS: PackedStringArray = [
	"std_lib/std-returns",
	"std_lib/std-collections",
	"std_lib/std-fsm",
	"std_lib/std-algorithms",
	"std_lib/std-timer",
	"std_lib/std-signals",
	"std_lib/std-node",
	"std_lib/std-random",
	"std_lib/std-audio",
	"std_lib/std-effects",
	"std_lib/std-tests",
]


#region Plugin Lifecycle
func _enable_plugin() -> void:
	_enable_subplugins()
	return


func _disable_plugin() -> void:
	_disable_subplugins(SUBPLUGIN_IDS)
	return
#endregion Plugin Lifecycle


#region Private Helpers
func _enable_subplugins() -> void:
	var enabled_subplugin_ids: PackedStringArray = []
	for subplugin_id: String in SUBPLUGIN_IDS:
		EditorInterface.set_plugin_enabled(subplugin_id, true)
		if EditorInterface.is_plugin_enabled(subplugin_id):
			enabled_subplugin_ids.append(subplugin_id)
			continue
		push_error("StdLib could not enable subplugin %s" % subplugin_id)
		_disable_subplugins(enabled_subplugin_ids)
		return
	return


func _disable_subplugins(subplugin_ids: PackedStringArray) -> void:
	var reverse_order: PackedStringArray = subplugin_ids.duplicate()
	reverse_order.reverse()
	for subplugin_id: String in reverse_order:
		if not EditorInterface.is_plugin_enabled(subplugin_id):
			continue
		EditorInterface.set_plugin_enabled(subplugin_id, false)
		pass
	return
#endregion Private Helpers
