extends StdTest
## Headless tests for StdTickClock. Most cases drive it through advance() with
## hand-fed deltas; one verifies autostart in the test SceneTree.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . --
## addons/std_lib/std-timer/tests/test_std_tick_clock.gd



func _make_clock(tps: float = 4.0) -> StdTickClock:
	var clock: StdTickClock = StdTickClock.new()
	clock.ticks_per_second = tps
	return clock


func _test_start_and_stop() -> void:
	var clock: StdTickClock = _make_clock()
	assert_true(not clock.is_running(), "clock starts stopped")
	assert_ok(clock.start(), "start ok")
	assert_true(clock.is_running(), "running after start")
	assert_err(clock.start(), "double start errs")
	clock.stop()
	assert_true(not clock.is_running(), "stopped after stop")
	assert_ok(clock.start(), "restart after stop ok")
	clock.free()
	return


func _test_start_rejects_bad_rate() -> void:
	var clock: StdTickClock = _make_clock()
	clock.ticks_per_second = 0.0
	assert_err(clock.start(), "start with zero rate errs")
	clock.ticks_per_second = -3.0
	assert_err(clock.start(), "start with negative rate errs")
	clock.ticks_per_second = NAN
	assert_err(clock.start(), "start with NaN rate errs")
	clock.ticks_per_second = INF
	assert_err(clock.start(), "start with infinite rate errs")
	clock.free()
	return


func _test_advance_fires_ticks() -> void:
	var clock: StdTickClock = _make_clock(4.0)
	var seen: Array[int] = []
	clock.ticked.connect(func(tick: int) -> void: seen.append(tick))

	assert_eq(clock.advance(1.0), 0, "advance while stopped fires nothing")
	assert_ok(clock.start(), "start for advance")
	assert_eq(clock.advance(0.5), 2, "0.5s at 4 tps is 2 ticks")
	assert_eq(seen, [1, 2], "tick payloads are monotonic from 1")
	assert_eq(clock.tick_count(), 2, "tick_count tracks emissions")
	assert_eq(clock.advance(-1.0), 0, "negative delta fires nothing")
	assert_eq(clock.tick_count(), 2, "negative delta leaves state alone")
	clock.free()
	return


func _test_fractional_accumulation() -> void:
	var clock: StdTickClock = _make_clock(4.0)  # interval 0.25, exact in binary
	assert_ok(clock.start(), "start for accumulation")
	assert_eq(clock.advance(0.125), 0, "half an interval fires nothing")
	assert_eq(clock.advance(0.0625), 0, "still under one interval")
	assert_eq(clock.advance(0.0625), 1, "accumulated to one interval fires")
	clock.free()
	return


func _test_common_rates_do_not_lose_boundary_ticks() -> void:
	for rate: float in [10.0, 60.0]:
		var clock: StdTickClock = _make_clock(rate)
		assert_ok(clock.start(), "%s tps starts" % rate)
		assert_eq(clock.advance(1.0), int(rate), "%s tps emits every tick in one second" % rate)
		clock.free()
		pass
	return


func _test_stop_preserves_accumulator() -> void:
	var clock: StdTickClock = _make_clock(4.0)
	assert_ok(clock.start(), "start before pause")
	assert_eq(clock.advance(0.125), 0, "partial interval buffered")
	clock.stop()
	assert_ok(clock.start(), "resume")
	assert_eq(clock.advance(0.125), 1, "resumed accumulator completes the interval")
	clock.free()
	return


func _test_reset_zeroes_everything() -> void:
	var clock: StdTickClock = _make_clock(4.0)
	assert_ok(clock.start(), "start before reset")
	var _fired: int = clock.advance(1.0)
	assert_eq(clock.tick_count(), 4, "ticks before reset")
	clock.reset()
	assert_true(not clock.is_running(), "reset stops the clock")
	assert_eq(clock.tick_count(), 0, "reset zeroes tick_count")
	assert_ok(clock.start(), "restart after reset")
	assert_eq(clock.advance(0.1), 0, "reset dropped the old accumulator")
	clock.free()
	return


func _test_set_speed() -> void:
	var clock: StdTickClock = _make_clock(4.0)
	assert_err(clock.set_speed(0.0), "zero rate errs")
	assert_err(clock.set_speed(-1.0), "negative rate errs")
	assert_err(clock.set_speed(NAN), "NaN rate errs")
	assert_err(clock.set_speed(INF), "infinite rate errs")
	var rv: StdResult = clock.set_speed(8.0)
	assert_ok(rv, "set_speed ok")
	assert_eq(rv.unwrap(), 8.0, "set_speed ok value is the new rate")
	assert_ok(clock.start(), "start at new speed")
	assert_eq(clock.advance(0.5), 4, "0.5s at 8 tps is 4 ticks")
	clock.free()
	return


func _test_autostart_starts_when_added_to_tree() -> void:
	var clock: StdTickClock = StdTickClock.new()
	clock.autostart = true
	var _tracked: Node = add_to_tree(clock)
	await process_wait()
	assert_true(clock.is_running(), "autostart starts the clock in ready")
	return


func _test_advance_rejects_non_finite_state() -> void:
	expect_warning("StdTickClock stopped because ticks_per_second became invalid",
			"invalid live tick rate warns")
	var clock: StdTickClock = _make_clock()
	assert_ok(clock.start(), "start for non-finite advance")
	assert_eq(clock.advance(NAN), 0, "NaN delta fires nothing")
	assert_eq(clock.advance(INF), 0, "infinite delta fires nothing")
	clock.ticks_per_second = NAN
	assert_eq(clock.advance(1.0), 0, "externally corrupted rate fires nothing")
	assert_true(not clock.is_running(), "invalid live rate stops the clock")
	clock.free()
	return


func _test_speed_change_inside_handler_applies_next_tick() -> void:
	# 4 tps (0.25s), handler doubles to 8 tps (0.125s) on the first
	# tick: advance(0.5) = tick@0.25 + tick@0.125 + tick@0.125 = 3.
	var clock: StdTickClock = _make_clock(4.0)
	clock.ticked.connect(func(tick: int) -> void:
		if tick == 1:
			var _rv: StdResult = clock.set_speed(8.0)
	)
	assert_ok(clock.start(), "start for mid-advance speed change")
	assert_eq(clock.advance(0.5), 3, "new speed applies within the same advance")
	clock.free()
	return


func _test_stop_inside_handler_halts_loop() -> void:
	var clock: StdTickClock = _make_clock(4.0)
	clock.ticked.connect(func(_tick: int) -> void: clock.stop())
	assert_ok(clock.start(), "start for handler stop")
	assert_eq(clock.advance(10.0), 1, "handler stop halts the advance loop")
	assert_true(not clock.is_running(), "clock stays stopped")
	clock.free()
	return


func _test_runaway_advance_is_capped() -> void:
	expect_warning("StdTickClock dropped", "capped runaway advance warns")
	var clock: StdTickClock = _make_clock(4.0)
	assert_ok(clock.set_speed(100000.0), "extreme speed is allowed")
	assert_ok(clock.start(), "start for runaway advance")
	var fired: int = clock.advance(60.0)
	assert_eq(fired, StdTickClock.MAX_TICKS_PER_ADVANCE, "one advance caps its tick storm")
	assert_eq(clock.advance(0.0), 0, "capped advance dropped the leftover accumulator")
	clock.free()
	return
