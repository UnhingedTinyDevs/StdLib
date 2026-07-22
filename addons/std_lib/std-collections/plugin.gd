@tool
extends EditorPlugin
## Enables the StdLib collection classes in the editor.


#region Engine Methods
# Performs no registration because collection classes are globally named scripts.
func _enter_tree() -> void:
	return


# Performs no cleanup because the plugin registers no editor state.
func _exit_tree() -> void:
	return
#endregion Engine Methods
