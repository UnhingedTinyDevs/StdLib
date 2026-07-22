class_name StdSignals
extends RefCounted
## Idempotent, result-returning signal connection helpers.
##
## Methods return [code]ok(true)[/code] when they change a connection and
## [code]ok(false)[/code] when the requested connection state already exists.
## Invalid endpoints and engine connection failures return an error [String].


#region Public API
## Connects [param cb] to [param sig] when it is not already connected.
## Existing connections are left unchanged, including their flags.
static func connect_sig(sig: Signal, cb: Callable, flags: int = 0) -> StdResult:
	var valid: StdResult = _validate(sig, cb)
	if valid.is_err():
		return valid
	if sig.is_connected(cb):
		return StdResult.ok(false)

	var error: Error = sig.connect(cb, flags)
	if error != OK:
		return StdResult.err(
				"could not connect %s to %s: %s" % [sig, cb, error_string(error)])
	return StdResult.ok(true)


## Disconnects [param cb] from [param sig] when it is connected.
static func disconnect_sig(sig: Signal, cb: Callable) -> StdResult:
	var valid: StdResult = _validate(sig, cb)
	if valid.is_err():
		return valid
	if not sig.is_connected(cb):
		return StdResult.ok(false)

	sig.disconnect(cb)
	return StdResult.ok(true)


## Connects [param cb] for one emission when it is not already connected.
## Existing connections are left unchanged.
static func connect_once(sig: Signal, cb: Callable, flags: int = 0) -> StdResult:
	return connect_sig(sig, cb, flags | Object.CONNECT_ONE_SHOT)
#endregion Public API


#region Private Helpers
static func _validate(sig: Signal, cb: Callable) -> StdResult:
	var source: Object = sig.get_object()
	if not is_instance_valid(source):
		return StdResult.err("signal has no live emitter: %s" % sig)
	var signal_name: StringName = sig.get_name()
	if signal_name.is_empty() or not source.has_signal(signal_name):
		return StdResult.err("%s has no signal named '%s'" % [source, signal_name])
	if not cb.is_valid():
		return StdResult.err("%s is not a valid callback for %s" % [cb, sig])
	return StdResult.ok(true)
#endregion Private Helpers
