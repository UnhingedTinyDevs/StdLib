extends StdTest
## Headless tests for StdTickCountdown.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . --
## addons/std_lib/std-timer/tests/test_std_tick_countdown.gd



func _test_start_validation() -> void:
	var countdown: StdTickCountdown = StdTickCountdown.new()
	assert_true(not countdown.is_expired(), "fresh countdown is not expired")
	assert_err(countdown.start(0), "zero ticks errs")
	assert_err(countdown.start(-3), "negative ticks errs")
	assert_true(not countdown.is_running(), "rejected start stays idle")
	var rv: StdResult = countdown.start(5)
	assert_ok(rv, "start ok")
	assert_eq(rv.unwrap(), 5, "ok value is the tick count")
	return


func _test_expires_exactly_once() -> void:
	var countdown: StdTickCountdown = StdTickCountdown.new()
	assert_true(not countdown.tick(), "tick while idle is false")
	assert_ok(countdown.start(3), "start 3")
	assert_true(not countdown.tick(), "tick 1 not expiring")
	assert_true(not countdown.tick(), "tick 2 not expiring")
	assert_true(countdown.tick(), "tick 3 expires")
	assert_true(not countdown.tick(), "tick after expiry is false")
	assert_true(countdown.is_expired(), "expired flag set")
	assert_true(not countdown.is_running(), "not running after expiry")
	assert_eq(countdown.remaining(), 0, "nothing remaining")
	return


func _test_restart_after_expiry() -> void:
	var countdown: StdTickCountdown = StdTickCountdown.new()
	assert_ok(countdown.start(1), "start 1")
	assert_true(countdown.tick(), "expire immediately")
	assert_ok(countdown.start(2), "restart after expiry")
	assert_true(countdown.is_running(), "running again")
	assert_true(not countdown.is_expired(), "no longer expired")
	assert_true(not countdown.tick(), "fresh count ticks down")
	assert_true(countdown.tick(), "fresh count expires")
	return


func _test_cancel() -> void:
	var countdown: StdTickCountdown = StdTickCountdown.new()
	assert_ok(countdown.start(5), "start 5")
	var _t: bool = countdown.tick()
	countdown.cancel()
	assert_true(not countdown.is_running(), "cancel stops the countdown")
	assert_true(not countdown.is_expired(), "cancel does not expire the countdown")
	assert_true(not countdown.tick(), "tick after cancel is false")
	assert_eq(countdown.remaining(), 0, "cancel clears remaining")

	assert_ok(countdown.start(1), "restart after cancel")
	assert_true(countdown.tick(), "restarted countdown expires")
	countdown.cancel()
	assert_true(not countdown.is_expired(), "cancel clears a previous expiration")
	return
