class_name StdTestLogEntry
extends RefCounted
## An immutable message or diagnostic captured by [StdTestLogger].
##
## Entries normalize Godot's message and error logger callbacks into one value
## while retaining diagnostic origin data and script backtraces when available.


## The category of a captured log entry.
enum Kind {
	## An ordinary stdout message.
	MESSAGE,
	## A message written to stderr without being an engine diagnostic.
	STDERR,
	## An engine error.
	ERROR,
	## An engine warning.
	WARNING,
	## A script runtime error.
	SCRIPT_ERROR,
	## A shader error.
	SHADER_ERROR,
}


## The normalized [enum StdTestLogEntry.Kind] category.
var kind: int:
	get:
		return _kind

## The message text, or the diagnostic rationale when one was supplied.
var message: String:
	get:
		return _message

## The function where a diagnostic originated, or an empty string for messages.
var function: String:
	get:
		return _function

## The file where a diagnostic originated, or an empty string for messages.
var file: String:
	get:
		return _file

## The source line where a diagnostic originated, or [code]-1[/code] for messages.
var line: int:
	get:
		return _line

## The engine diagnostic code, when supplied.
var code: String:
	get:
		return _code

## Whether the diagnostic requested an editor notification.
var editor_notify: bool:
	get:
		return _editor_notify

## Script backtraces supplied with the diagnostic.
var script_backtraces: Array[ScriptBacktrace]:
	get:
		return _script_backtraces.duplicate()

var _kind: int
var _message: String
var _function: String
var _file: String
var _line: int
var _code: String
var _editor_notify: bool
var _script_backtraces: Array[ScriptBacktrace]


#region Engine Methods
func _init(
		entry_kind: int,
		entry_message: String,
		origin_function: String = "",
		origin_file: String = "",
		origin_line: int = -1,
		diagnostic_code: String = "",
		notify_editor: bool = false,
		backtraces: Array[ScriptBacktrace] = [],
) -> void:
	_kind = entry_kind
	_message = entry_message
	_function = origin_function
	_file = origin_file
	_line = origin_line
	_code = diagnostic_code
	_editor_notify = notify_editor
	_script_backtraces = backtraces.duplicate()
	return
#endregion Engine Methods
