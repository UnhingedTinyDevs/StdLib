extends StdTest
## Deterministic placement and RNG-contract tests for [StdGrid2D].


const FAILURE_PROBE: String = "res://addons/std_lib/std-grid/tests/fixtures/grid_failure_probe.gd"


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_random_free_cell_returns_only_eligible_cells() -> void:
	var grid: StdGrid2D = StdGrid2D.new(Vector2i(3, 2), Vector2.ONE)
	assert_ok(
			grid.add_portal(Vector2i(0, 0), Vector2i(2, 1), false),
			"one-way portal reserves two cells")
	var occupied: StdSet = StdSet.new()
	occupied.push(Vector2i(1, 0))
	occupied.push(Vector2i(2, 0))
	var rng: RandomNumberGenerator = _rng(1234)
	for draw: int in 64:
		var found: StdOption = grid.random_free_cell(occupied, rng)
		assert_true(found.is_some(), "draw %d finds an eligible cell" % draw)
		var cell: Vector2i = found.unwrap()
		assert_true(grid.contains(cell), "draw %d stays in bounds" % draw)
		assert_true(not grid.is_portal(cell), "draw %d avoids portal endpoints" % draw)
		assert_true(not occupied.has(cell), "draw %d avoids occupied cells" % draw)
	return


func _test_random_free_cell_handles_one_and_zero_candidates() -> void:
	var grid: StdGrid2D = StdGrid2D.new(Vector2i(2, 2), Vector2.ONE)
	assert_ok(grid.add_portal(Vector2i(0, 0), Vector2i(1, 1), false), "portal pair")
	var occupied: StdSet = StdSet.new()
	occupied.push(Vector2i(1, 0))
	var rng: RandomNumberGenerator = _rng(7)
	for draw: int in 16:
		assert_eq(
				grid.random_free_cell(occupied, rng).unwrap(),
				Vector2i(0, 1),
				"single eligible cell is stable on draw %d" % draw)
	occupied.push(Vector2i(0, 1))
	assert_true(
			grid.random_free_cell(occupied, rng).is_none(),
			"no eligible cell returns none")
	assert_true(
			StdGrid2D.new(Vector2i.ONE, Vector2.ONE).random_free_cell(null, rng).is_some(),
			"null occupied set means no occupancy exclusions")
	return


func _test_random_free_cell_is_seed_deterministic() -> void:
	var grid: StdGrid2D = StdGrid2D.new(Vector2i(7, 5), Vector2.ONE)
	var occupied: StdSet = StdSet.new()
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 3), Vector2i(6, 4)]:
		occupied.push(cell)
	var rng_a: RandomNumberGenerator = _rng(99881)
	var rng_b: RandomNumberGenerator = _rng(99881)
	for draw: int in 128:
		assert_eq(
				grid.random_free_cell(occupied, rng_a).unwrap(),
				grid.random_free_cell(occupied, rng_b).unwrap(),
				"same seed gives same free-cell draw %d" % draw)
	return


func _test_random_free_cell_reaches_every_candidate() -> void:
	var grid: StdGrid2D = StdGrid2D.new(Vector2i(4, 1), Vector2.ONE)
	var rng: RandomNumberGenerator = _rng(20260723)
	var seen: Dictionary[Vector2i, bool] = {}
	for draw: int in 512:
		seen[grid.random_free_cell(null, rng).unwrap()] = true
	assert_eq(seen.size(), 4, "reservoir sampler reaches every eligible cell")
	return


func _test_random_wall_cell_respects_wall_exclusions_and_portals() -> void:
	var grid: StdGrid2D = StdGrid2D.new(Vector2i(6, 4), Vector2.ONE)
	assert_ok(
			grid.add_portal(Vector2i(1, 0), Vector2i(4, 0), false),
			"one-way pair reserves both top-wall endpoints")
	var excluded: StdSet = StdSet.new()
	excluded.push(Vector2i(2, 0))
	var rng: RandomNumberGenerator = _rng(61)
	for draw: int in 64:
		var found: StdOption = grid.random_wall_cell(StdGrid2D.Side.TOP, rng, excluded)
		assert_true(found.is_some(), "draw %d finds remaining wall cell" % draw)
		assert_eq(found.unwrap(), Vector2i(3, 0), "draw %d returns sole candidate" % draw)
	excluded.push(Vector2i(3, 0))
	assert_true(
			grid.random_wall_cell(StdGrid2D.Side.TOP, rng, excluded).is_none(),
			"fully reserved wall returns none")
	return


func _test_random_wall_cell_is_seed_deterministic() -> void:
	var grid: StdGrid2D = StdGrid2D.new(Vector2i(9, 5), Vector2.ONE)
	var rng_a: RandomNumberGenerator = _rng(302)
	var rng_b: RandomNumberGenerator = _rng(302)
	for side: StdGrid2D.Side in [
		StdGrid2D.Side.TOP,
		StdGrid2D.Side.BOTTOM,
		StdGrid2D.Side.LEFT,
		StdGrid2D.Side.RIGHT,
	]:
		for draw: int in 32:
			assert_eq(
					grid.random_wall_cell(side, rng_a).unwrap(),
					grid.random_wall_cell(side, rng_b).unwrap(),
					"same seed gives same wall draw %s/%d" % [side, draw])
	return


func _test_random_wall_cell_handles_degenerate_walls() -> void:
	var rng: RandomNumberGenerator = _rng(1)
	var dot: StdGrid2D = StdGrid2D.new(Vector2i.ONE, Vector2.ONE)
	for side: StdGrid2D.Side in [
		StdGrid2D.Side.TOP,
		StdGrid2D.Side.BOTTOM,
		StdGrid2D.Side.LEFT,
		StdGrid2D.Side.RIGHT,
	]:
		assert_true(
				dot.random_wall_cell(side, rng).is_none(),
				"1x1 board has no non-corner candidate on side %s" % side)
	return


func _test_random_methods_reject_null_rng() -> void:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		FAILURE_PROBE,
		"--",
		"random_free",
		"random_wall",
	])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "\n".join(output)
	assert_true(code != 0, "null-RNG probe does not exit normally")
	assert_true(
			text.contains("StdGrid2D.random_free_cell() requires a RandomNumberGenerator"),
			"random_free_cell reports its RNG contract")
	assert_true(
			text.contains("StdGrid2D.random_wall_cell() requires a RandomNumberGenerator"),
			"random_wall_cell reports its RNG contract")
	assert_true(text.contains("PROBE_CONTINUED"), "probe exercised both failure paths")
	return
