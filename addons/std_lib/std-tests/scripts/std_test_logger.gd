class_name StdTestLogger
extends Logger
## Thread-safe in-memory logger for the StdTest framework.
##
## Register an instance with [method OS.add_logger] to capture Godot's message
## and diagnostic streams. Registration is additive: the engine's normal
## console output is not suppressed. Remove it with [method OS.remove_logger]
## when capture is complete.


var _entries: Array[StdTestLogEntry] = []
var _mutex: Mutex = Mutex.new()


#region Public API
## Returns a snapshot of every captured entry in arrival order.
func entries() -> Array[StdTestLogEntry]:
	_mutex.lock()
	var snapshot: Array[StdTestLogEntry] = _entries.duplicate()
	_mutex.unlock()
	return snapshot


## Returns a snapshot containing entries whose kind equals [param kind].
func entries_of_kind(kind: int) -> Array[StdTestLogEntry]:
	var matches: Array[StdTestLogEntry] = []
	_mutex.lock()
	for entry: StdTestLogEntry in _entries:
		if entry.kind == kind:
			matches.append(entry)
		continue
	_mutex.unlock()
	return matches


## Returns the number of captured entries whose kind equals [param kind].
func count(kind: int) -> int:
	var matches: int = 0
	_mutex.lock()
	for entry: StdTestLogEntry in _entries:
		if entry.kind == kind:
			matches += 1
		continue
	_mutex.unlock()
	return matches


## Returns the total number of captured entries.
func size() -> int:
	_mutex.lock()
	var entry_count: int = _entries.size()
	_mutex.unlock()
	return entry_count


## Removes every captured entry without unregistering this logger.
func clear() -> void:
	_mutex.lock()
	_entries.clear()
	_mutex.unlock()
	return
#endregion Public API


#region Logger Callbacks
func _log_message(message: String, error: bool) -> void:
	var kind: int = StdTestLogEntry.Kind.STDERR if error else StdTestLogEntry.Kind.MESSAGE
	_append(StdTestLogEntry.new(kind, message))
	return


func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		editor_notify: bool,
		error_type: int,
		script_backtraces: Array[ScriptBacktrace],
) -> void:
	var message: String = rationale if not rationale.is_empty() else code
	var kind: int = _kind_from_error_type(error_type)
	var entry: StdTestLogEntry = StdTestLogEntry.new(
			kind, message, function, file, line, code, editor_notify, script_backtraces)
	_append(entry)
	return
#endregion Logger Callbacks


#region Private Helpers
func _append(entry: StdTestLogEntry) -> void:
	_mutex.lock()
	_entries.append(entry)
	_mutex.unlock()
	return


func _kind_from_error_type(error_type: int) -> int:
	match error_type:
		Logger.ERROR_TYPE_WARNING:
			return StdTestLogEntry.Kind.WARNING
		Logger.ERROR_TYPE_SCRIPT:
			return StdTestLogEntry.Kind.SCRIPT_ERROR
		Logger.ERROR_TYPE_SHADER:
			return StdTestLogEntry.Kind.SHADER_ERROR
		_:
			return StdTestLogEntry.Kind.ERROR
#endregion Private Helpers
