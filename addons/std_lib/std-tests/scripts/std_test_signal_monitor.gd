class_name StdTestSignalMonitor
extends RefCounted
## Records every emission and argument list from one Godot [Signal].


var _signal: Signal
var _callback: Callable
var _emissions: Array[Array] = []
var _started: bool = false


#region Engine Methods
func _init(monitored_signal: Signal) -> void:
	_signal = monitored_signal
	_callback = _on_emitted
	return
#endregion Engine Methods


#region Public API
## Connects this monitor. Returns an error for an empty, dead, or invalid signal.
func start() -> Error:
	if _signal.is_null():
		return ERR_INVALID_PARAMETER
	var source: Object = _signal.get_object()
	if source == null or not is_instance_valid(source):
		return ERR_DOES_NOT_EXIST
	if not source.has_signal(_signal.get_name()):
		return ERR_DOES_NOT_EXIST
	if _signal.is_connected(_callback):
		_started = true
		return OK
	var error: Error = _signal.connect(_callback)
	_started = error == OK
	return error


## Disconnects this monitor when its source still exists.
func stop() -> void:
	if not _started or _signal.is_null():
		return
	var source: Object = _signal.get_object()
	if source != null and is_instance_valid(source) and _signal.is_connected(_callback):
		_signal.disconnect(_callback)
	_started = false
	return


## Returns the signal observed by this monitor.
func monitored_signal() -> Signal:
	return _signal


## Returns the number of recorded emissions.
func emission_count() -> int:
	return _emissions.size()


## Returns a snapshot of every recorded argument list.
func emissions() -> Array[Array]:
	return _emissions.duplicate()


## Removes all recorded emissions without disconnecting.
func clear() -> void:
	_emissions.clear()
	return
#endregion Public API


#region Signal Handlers
func _on_emitted(...args: Array) -> void:
	_emissions.append(args.duplicate())
	return
#endregion Signal Handlers
