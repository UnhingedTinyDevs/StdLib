extends StdTest
## Headless tests for [StdSignals].


class Emitter:
	extends RefCounted

	signal fired(a, b)
	signal ping


#region Tests
func _test_connect_sig() -> void:
	var emitter: Emitter = Emitter.new()
	var calls: Array = []
	var cb: Callable = func(a: Variant, b: Variant) -> void: calls.append([a, b])

	var first: StdResult = StdSignals.connect_sig(emitter.fired, cb)
	assert_ok(first, "valid callback connects")
	assert_eq(first.unwrap_or(false), true, "new connection reports a change")

	var repeated: StdResult = StdSignals.connect_sig(
			emitter.fired, cb, Object.CONNECT_DEFERRED)
	assert_ok(repeated, "existing connection is successful")
	assert_eq(repeated.unwrap_or(true), false, "existing connection reports no change")

	emitter.fired.emit(1, 2)
	assert_eq(calls, [[1, 2]], "callback is connected once")
	return


func _test_disconnect_sig() -> void:
	var emitter: Emitter = Emitter.new()
	var cb: Callable = func() -> void: return

	var absent: StdResult = StdSignals.disconnect_sig(emitter.ping, cb)
	assert_ok(absent, "absent callback is successful")
	assert_eq(absent.unwrap_or(true), false, "absent callback reports no change")

	assert_ok(StdSignals.connect_sig(emitter.ping, cb), "callback connects")
	var removed: StdResult = StdSignals.disconnect_sig(emitter.ping, cb)
	assert_ok(removed, "connected callback disconnects")
	assert_eq(removed.unwrap_or(false), true, "disconnect reports a change")
	assert_true(not emitter.ping.is_connected(cb), "callback is disconnected")
	return


func _test_connect_once() -> void:
	var emitter: Emitter = Emitter.new()
	var calls: Array = []
	var cb: Callable = func(a: Variant, b: Variant) -> void: calls.append([a, b])

	var connected: StdResult = StdSignals.connect_once(emitter.fired, cb)
	assert_ok(connected, "one-shot callback connects")
	assert_eq(connected.unwrap_or(false), true, "one-shot connection reports a change")

	emitter.fired.emit(1, 2)
	emitter.fired.emit(3, 4)
	assert_eq(calls, [[1, 2]], "one-shot callback fires once")
	assert_true(not emitter.fired.is_connected(cb), "one-shot callback disconnects")
	return


func _test_invalid_endpoints() -> void:
	var emitter: Emitter = Emitter.new()
	var cb: Callable = func() -> void: return

	assert_err(StdSignals.connect_sig(Signal(), cb), "empty signal is rejected")
	assert_err(
			StdSignals.connect_sig(Signal(emitter, &"missing"), cb),
			"missing signal is rejected")
	assert_err(StdSignals.connect_sig(emitter.ping, Callable()), "empty callback is rejected")
	assert_err(StdSignals.disconnect_sig(emitter.ping, Callable()),
			"empty disconnect callback is rejected")

	var dead_signal: Signal = emitter.ping
	emitter = null
	assert_err(StdSignals.connect_sig(dead_signal, cb), "dead signal emitter is rejected")
	assert_err(StdSignals.disconnect_sig(dead_signal, cb), "dead disconnect emitter is rejected")
	return
#endregion Tests
