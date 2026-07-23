extends StdTest
## Fixed-seed model and stress tests for [StdGrid2D].


const DIRECTIONS4: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]
const DIRECTIONS8: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]


func _test_geometry_matches_reference_model_across_many_sizes() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x5A17
	for case_index: int in 48:
		var grid_size: Vector2i = Vector2i(
				rng.randi_range(1, 18),
				rng.randi_range(1, 14))
		var cell_size: Vector2 = Vector2(
				rng.randf_range(0.125, 30.0),
				rng.randf_range(0.125, 30.0))
		var origin: Vector2 = Vector2(
				rng.randf_range(-500.0, 500.0),
				rng.randf_range(-500.0, 500.0))
		var wraps: bool = rng.randi_range(0, 1) == 1
		var grid: StdGrid2D = StdGrid2D.new(grid_size, cell_size, origin, wraps)
		var cells: Array[Vector2i] = grid.all_cells()
		assert_eq(
				cells.size(),
				grid_size.x * grid_size.y,
				"case %d enumerates the expected cell count" % case_index)
		var unique: Dictionary[Vector2i, bool] = {}
		for cell: Vector2i in cells:
			unique[cell] = true
			assert_true(grid.contains(cell), "case %d enumerates in-bounds cell" % case_index)
			assert_eq(
					grid.world_to_cell(grid.cell_to_world(cell)),
					cell,
					"case %d roundtrips %s" % [case_index, cell])
			assert_eq(
					grid.neighbors4(cell),
					_model_neighbors(cell, DIRECTIONS4, grid_size, wraps),
					"case %d neighbors4 matches model at %s" % [case_index, cell])
			assert_eq(
					grid.neighbors8(cell),
					_model_neighbors(cell, DIRECTIONS8, grid_size, wraps),
					"case %d neighbors8 matches model at %s" % [case_index, cell])
		assert_eq(
				unique.size(),
				cells.size(),
				"case %d enumeration contains no duplicates" % case_index)
		var probes: Array[Vector2i] = [
			Vector2i(-1, 0),
			Vector2i(0, -1),
			Vector2i(grid_size.x, grid_size.y - 1),
			Vector2i(grid_size.x - 1, grid_size.y),
			Vector2i(-9999, 9999),
		]
		for probe: Vector2i in probes:
			assert_eq(
					grid.wrap(probe),
					Vector2i(posmod(probe.x, grid_size.x), posmod(probe.y, grid_size.y)),
					"case %d wrap matches posmod for %s" % [case_index, probe])
			assert_eq(
					grid.clamp_cell(probe),
					probe.clamp(Vector2i.ZERO, grid_size - Vector2i.ONE),
					"case %d clamp matches model for %s" % [case_index, probe])
			assert_eq(
					grid.neighbors8(probe),
					[] as Array[Vector2i],
					"case %d invalid source %s has no neighbors" % [case_index, probe])
	return


func _test_step_matches_reference_model_across_board_shapes() -> void:
	for width: int in range(1, 13):
		for height: int in range(1, 10):
			var grid_size: Vector2i = Vector2i(width, height)
			for wraps: bool in [false, true]:
				var grid: StdGrid2D = StdGrid2D.new(
						grid_size, Vector2.ONE, Vector2.ZERO, wraps)
				for cell: Vector2i in grid.all_cells():
					for dir: Vector2i in DIRECTIONS8:
						var destination: Vector2i = cell + dir
						var result: StdResult = grid.step(cell, dir)
						if wraps:
							assert_ok(result, "wrapped step succeeds")
							assert_eq(
									result.unwrap(),
									Vector2i(
											posmod(destination.x, width),
											posmod(destination.y, height)),
									"wrapped step matches model")
						elif _model_contains(destination, grid_size):
							assert_ok(result, "in-bounds step succeeds")
							assert_eq(result.unwrap(), destination, "bounded step matches model")
						else:
							assert_err(result, "off-board step errs")
							assert_eq(
									result.unwrap_err(),
									"%s" % destination,
									"off-board step reports destination")
				for invalid_source: Vector2i in [
					Vector2i(-1, 0),
					Vector2i(width, height - 1),
				]:
					assert_err(
							grid.step(invalid_source, Vector2i.RIGHT),
							"invalid source errs regardless of wrapping")
	return


func _test_random_portal_mutations_match_reference_registry() -> void:
	var grid_size: Vector2i = Vector2i(17, 13)
	var grid: StdGrid2D = StdGrid2D.new(grid_size, Vector2.ONE)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xC011EC7
	var links: Dictionary[Vector2i, Vector2i] = {}
	var endpoints: Dictionary[Vector2i, bool] = {}
	for operation: int in 6000:
		var action: int = rng.randi_range(0, 9)
		if action <= 5:
			var a: Vector2i = _random_probe(rng, grid_size)
			var b: Vector2i = _random_probe(rng, grid_size)
			var two_way: bool = rng.randi_range(0, 1) == 1
			var should_succeed: bool = (
				_model_contains(a, grid_size)
				and _model_contains(b, grid_size)
				and a != b
				and not endpoints.has(a)
				and not endpoints.has(b)
			)
			var added: StdResult = grid.add_portal(a, b, two_way)
			if should_succeed:
				assert_ok(added, "operation %d valid add succeeds" % operation)
				links[a] = b
				endpoints[a] = true
				endpoints[b] = true
				if two_way:
					links[b] = a
			else:
				assert_err(added, "operation %d invalid add errs" % operation)
		elif action <= 8:
			var entrance: Vector2i = _random_probe(rng, grid_size)
			var expected_exit: Variant = links.get(entrance)
			var removed: StdOption = grid.remove_portal(entrance)
			if expected_exit == null:
				assert_true(removed.is_none(), "operation %d absent remove is none" % operation)
			else:
				assert_eq(
						removed.unwrap(),
						expected_exit,
						"operation %d remove returns model exit" % operation)
				links.erase(entrance)
				if links.get(expected_exit) == entrance:
					links.erase(expected_exit)
				endpoints.erase(entrance)
				endpoints.erase(expected_exit)
		else:
			grid.clear_portals()
			links.clear()
			endpoints.clear()
			assert_eq(
					grid.portal_cells(),
					[] as Array[Vector2i],
					"operation %d clear empties registry" % operation)
		assert_eq(
				grid.portal_cells(),
				_sorted_cells(endpoints),
				"operation %d endpoint registry matches model" % operation)
		var inspection_cell: Vector2i = Vector2i(
				rng.randi_range(0, grid_size.x - 1),
				rng.randi_range(0, grid_size.y - 1))
		assert_eq(
				grid.is_portal(inspection_cell),
				endpoints.has(inspection_cell),
				"operation %d endpoint lookup matches model" % operation)
		var exit: StdOption = grid.portal_exit(inspection_cell)
		assert_eq(
				exit.is_some(),
				links.has(inspection_cell),
				"operation %d entrance lookup matches model" % operation)
		if exit.is_some():
			assert_eq(
					exit.unwrap(),
					links.get(inspection_cell),
					"operation %d portal exit matches model" % operation)
	return


func _model_contains(cell: Vector2i, grid_size: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < grid_size.x
		and cell.y < grid_size.y
	)


func _model_neighbors(
	cell: Vector2i,
	directions: Array[Vector2i],
	grid_size: Vector2i,
	wraps: bool,
) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir: Vector2i in directions:
		var destination: Vector2i = cell + dir
		if wraps:
			neighbors.append(Vector2i(
					posmod(destination.x, grid_size.x),
					posmod(destination.y, grid_size.y)))
		elif _model_contains(destination, grid_size):
			neighbors.append(destination)
	return neighbors


func _random_probe(rng: RandomNumberGenerator, grid_size: Vector2i) -> Vector2i:
	return Vector2i(
			rng.randi_range(-1, grid_size.x),
			rng.randi_range(-1, grid_size.y))


func _sorted_cells(endpoints: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in endpoints:
		cells.append(cell)
	cells.sort()
	return cells
