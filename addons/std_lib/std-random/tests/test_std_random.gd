extends StdTest
## Headless tests for the StdRandom facade and StdRandomStream.


const FACADE_PATH: String = "res://addons/std_lib/std-random/scripts/std_random.gd"


func _make_facade(seed_value: int = 1234) -> Node:
	var script: GDScript = load(FACADE_PATH)
	var facade: Node = script.new()
	facade.set_seed(seed_value)
	return facade


func _make_stream(seed_value: int) -> StdRandomStream:
	var stream: StdRandomStream = StdRandomStream.new()
	stream.seed = seed_value
	return stream


func _test_named_streams_are_deterministic() -> void:
	var a: Node = _make_facade(42)
	var b: Node = _make_facade(42)
	var a_loot: StdRandomStream = a.stream(&"loot")
	var b_loot: StdRandomStream = b.stream(&"loot")
	for i: int in 16:
		if a_loot.randi() != b_loot.randi() or a_loot.randf() != b_loot.randf():
			assert_true(false, "same named streams diverged at draw %d" % i)
			a.free()
			b.free()
			return
		pass
	assert_true(true, "same seed and stream name produce the same sequence")
	assert_eq(a.get_seed(), 42, "get_seed reports the session seed")
	a.free()
	b.free()
	return


func _test_streams_are_isolated_and_lookup_order_independent() -> void:
	var a: Node = _make_facade(77)
	var b: Node = _make_facade(77)
	var a_loot: StdRandomStream = a.stream(&"loot")
	var a_spawn: StdRandomStream = a.stream(&"spawn")
	var b_spawn: StdRandomStream = b.stream(&"spawn")
	var b_loot: StdRandomStream = b.stream(&"loot")

	for _i: int in 32:
		var _burned: int = a_loot.randi()
		pass
	for i: int in 16:
		if a_spawn.randi() != b_spawn.randi():
			assert_true(false, "loot draws shifted spawn stream at draw %d" % i)
			a.free()
			b.free()
			return
		pass
	assert_true(true, "one stream does not shift another")
	assert_eq(a_loot.seed, b_loot.seed, "stream derivation does not depend on lookup order")
	assert_true(a_loot.seed != a_spawn.seed, "different names derive different stream seeds")
	a.free()
	b.free()
	return


func _test_stream_lookup_and_reseed_preserve_references() -> void:
	var facade: Node = _make_facade(9)
	var held: StdRandomStream = facade.stream(&"world")
	assert_true(is_same(held, facade.stream(&"world")), "repeated lookup returns the cached stream")
	var first: int = held.randi()
	var _advanced: int = held.randi()

	facade.set_seed(9)
	assert_true(is_same(held, facade.stream(&"world")), "reseed keeps the cached object")
	assert_eq(held.randi(), first, "reseed restarts a held stream reference")

	facade.randomize_seed()
	assert_true(is_same(held, facade.stream(&"world")), "randomize keeps the cached object")
	facade.free()
	return


func _test_stream_state_restores_exact_position() -> void:
	var facade: Node = _make_facade(55)
	var stream: StdRandomStream = facade.stream(&"combat")
	var _first: int = stream.randi()
	var saved_state: int = stream.state
	var expected: Array[int] = []
	for _i: int in 8:
		expected.append(stream.randi())
		pass
	stream.state = saved_state
	var restored: Array[int] = []
	for _i: int in 8:
		restored.append(stream.randi())
		pass
	assert_eq(restored, expected, "restored state resumes the exact sequence")
	facade.free()
	return


func _test_native_ranges() -> void:
	var stream: StdRandomStream = _make_stream(1234)
	assert_eq(stream.randi_range(7, 7), 7, "degenerate range is exact")
	for i: int in 32:
		var value: int = stream.randi_range(-3, 3)
		if value < -3 or value > 3:
			assert_true(false, "randi_range escaped its bounds at draw %d: %d" % [i, value])
			return
		pass
	assert_true(true, "native randi_range stays in bounds")
	return


func _test_chance_edges() -> void:
	expect_warning("chance probability 2.000000 outside 0..1", "out-of-range chance warns")
	expect_warning("chance probability is NAN", "NAN chance warns")
	var stream: StdRandomStream = _make_stream(1234)
	for _i: int in 16:
		if stream.chance(0.0):
			assert_true(false, "chance(0) fired")
			return
		if not stream.chance(1.0):
			assert_true(false, "chance(1) missed")
			return
		pass
	assert_true(true, "chance edges are exact")
	var clamped: bool = stream.chance(2.0)
	assert_true(clamped, "chance above 1 clamps to certain")
	assert_true(not stream.chance(NAN), "NAN chance is safely false")
	return


func _test_pick_and_shuffle() -> void:
	var stream: StdRandomStream = _make_stream(7)
	assert_true(stream.pick([]).is_none(), "pick from empty is none")
	assert_eq(stream.pick([42]).unwrap(), 42, "pick from singleton")

	var items: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var shuffle_state: int = stream.state
	var shuffled: Array = items.duplicate()
	stream.shuffle(shuffled)
	assert_eq(shuffled.size(), items.size(), "shuffle keeps every element")
	var sorted_copy: Array = shuffled.duplicate()
	sorted_copy.sort()
	assert_eq(sorted_copy, items, "shuffle is a permutation")

	stream.state = shuffle_state
	var shuffled_other: Array = items.duplicate()
	stream.shuffle(shuffled_other)
	assert_eq(shuffled_other, shuffled, "restored state produces the same shuffle")
	return


func _test_gaussian_runs() -> void:
	var stream: StdRandomStream = _make_stream(1234)
	var total: float = 0.0
	for _i: int in 64:
		total += stream.gaussian(100.0, 1.0)
		pass
	var mean: float = total / 64.0
	assert_true(mean > 90.0 and mean < 110.0, "gaussian mean lands near its center (got %f)" % mean)
	return


func _test_dice_notation() -> void:
	var stream: StdRandomStream = _make_stream(5)
	var d20: StdResult = stream.roll("d20")
	assert_ok(d20, "d20 rolls")
	assert_true(d20.unwrap() >= 1 and d20.unwrap() <= 20, "d20 in range")

	for i: int in 16:
		var rv: StdResult = stream.roll("3d6+2")
		if rv.is_err() or rv.unwrap() < 5 or rv.unwrap() > 20:
			assert_true(false, "3d6+2 out of range at draw %d: %s" % [i, rv.unwrap_or(rv.unwrap_err())])
			return
		pass
	assert_true(true, "3d6+2 stays in [5, 20]")
	assert_true(stream.roll("2d8-1").unwrap() >= 1, "negative modifier applies")
	assert_ok(stream.roll("  D20  "), "case and whitespace tolerated")
	assert_err(stream.roll("banana"), "garbage errs")
	assert_err(stream.roll("0d6"), "zero dice errs")
	assert_err(stream.roll("3d0"), "zero sides errs")
	assert_err(stream.roll("3d"), "missing sides errs")
	assert_err(stream.roll("d6+"), "dangling modifier errs")
	assert_err(stream.roll(""), "empty string errs")
	return
