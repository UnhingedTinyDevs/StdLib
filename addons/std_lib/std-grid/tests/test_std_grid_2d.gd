extends StdTest
## Geometry, bounds, movement, and wall tests for [StdGrid2D].


func _make_grid(wraps: bool = false) -> StdGrid2D:
	return StdGrid2D.new(Vector2i(4, 3), Vector2(10, 10), Vector2.ZERO, wraps)


func _test_construction_sanitizes_invalid_values() -> void:
	expect_warning("StdGrid2D size must be at least 1x1", "degenerate grid size warns")
	expect_warning(
			"StdGrid2D cell size must be positive, got (-1.0, 0.0)",
			"nonpositive cell size warns")
	expect_warning(
			"StdGrid2D cell size must be positive, got (nan, inf)",
			"non-finite cell size warns")
	expect_warning("StdGrid2D origin must be finite", "non-finite origin warns")
	var grid: StdGrid2D = StdGrid2D.new(Vector2i(0, -5), Vector2(-1, 0))
	assert_eq(grid.size(), Vector2i.ONE, "size clamps to 1x1")
	assert_eq(grid.cell_size(), Vector2.ONE, "cell size axes clamp to one")
	assert_eq(grid.cell_count(), 1, "sanitized grid has one cell")
	assert_eq(
			grid.world_to_cell(Vector2(0.5, 0.5)),
			Vector2i.ZERO,
			"sanitized cell size remains safe for division")
	var non_finite: StdGrid2D = StdGrid2D.new(
			Vector2i.ONE, Vector2(NAN, INF), Vector2(NAN, INF))
	assert_eq(non_finite.cell_size(), Vector2.ONE, "non-finite cell axes become one")
	assert_eq(non_finite.origin(), Vector2.ZERO, "non-finite origin axes become zero")
	return


func _test_construction_preserves_each_valid_axis() -> void:
	expect_warning("StdGrid2D cell size must be positive", "one invalid cell-size axis warns")
	expect_warning("StdGrid2D origin must be finite", "one invalid origin axis warns")
	var grid: StdGrid2D = StdGrid2D.new(
			Vector2i(4, 3), Vector2(2.5, -1.0), Vector2(17.25, NAN), true)
	assert_eq(grid.size(), Vector2i(4, 3), "valid size is preserved")
	assert_eq(grid.cell_size(), Vector2(2.5, 1.0), "valid cell-size axis is preserved")
	assert_eq(grid.origin(), Vector2(17.25, 0.0), "valid origin axis is preserved")
	assert_true(grid.wraps(), "wrapping option is preserved")
	return


func _test_bounds_wrap_and_clamp() -> void:
	var grid: StdGrid2D = _make_grid()
	assert_true(grid.contains(Vector2i.ZERO), "contains top-left corner")
	assert_true(grid.contains(Vector2i(3, 2)), "contains bottom-right corner")
	assert_true(not grid.contains(Vector2i(4, 2)), "x at width is out of bounds")
	assert_true(not grid.contains(Vector2i(3, 3)), "y at height is out of bounds")
	assert_true(not grid.contains(Vector2i(-1, 0)), "negative x is out of bounds")
	assert_true(not grid.contains(Vector2i(0, -1)), "negative y is out of bounds")
	assert_eq(grid.wrap(Vector2i(4, 3)), Vector2i.ZERO, "wrap one past both axes")
	assert_eq(grid.wrap(Vector2i(-1, -1)), Vector2i(3, 2), "wrap negative axes")
	assert_eq(grid.wrap(Vector2i(-9, 7)), Vector2i(3, 1), "wrap far out-of-range cell")
	assert_eq(grid.clamp_cell(Vector2i(99, -99)), Vector2i(3, 0), "clamp mixed overflow")
	assert_eq(grid.clamp_cell(Vector2i(1, 1)), Vector2i(1, 1), "clamp in-bounds identity")
	return


func _test_world_conversions_with_fractional_values() -> void:
	var grid: StdGrid2D = StdGrid2D.new(
			Vector2i(4, 3), Vector2(2.5, 7.25), Vector2(-11.75, 3.125))
	assert_eq(
			grid.cell_to_world(Vector2i.ZERO),
			Vector2(-10.5, 6.75),
			"cell_to_world returns the first cell center")
	assert_eq(
			grid.world_to_cell(Vector2(-11.75, 3.125)),
			Vector2i.ZERO,
			"origin belongs to the first cell")
	assert_eq(
			grid.world_to_cell(Vector2(-11.7501, 3.125)),
			Vector2i(-1, 0),
			"position just left of origin floors out of bounds")
	for cell: Vector2i in grid.all_cells():
		assert_eq(
				grid.world_to_cell(grid.cell_to_world(cell)),
				cell,
				"cell/world roundtrip for %s" % cell)
	assert_eq(
			grid.cell_to_world(Vector2i(-2, 8)),
			Vector2(-15.5, 64.75),
			"cell_to_world remains total outside the board")
	return


func _test_step_accepts_exactly_one_valid_direction() -> void:
	var grid: StdGrid2D = _make_grid()
	var directions: Array[Vector2i] = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
	]
	for dir: Vector2i in directions:
		var result: StdResult = grid.step(Vector2i(1, 1), dir)
		assert_ok(result, "valid direction %s succeeds" % dir)
		assert_eq(result.unwrap(), Vector2i(1, 1) + dir, "direction %s moves once" % dir)
	var invalid_directions: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i(2, 0),
		Vector2i(-2, 1),
		Vector2i(1, 99),
		Vector2i(-999, -999),
	]
	for dir: Vector2i in invalid_directions:
		var result: StdResult = grid.step(Vector2i(1, 1), dir)
		assert_err(result, "invalid direction %s errs" % dir)
		assert_eq(
				result.unwrap_err(),
				"direction %s must be one orthogonal or diagonal step" % dir,
				"invalid direction %s explains the contract" % dir)
	return


func _test_step_checks_source_and_destination_bounds() -> void:
	var grid: StdGrid2D = _make_grid()
	var source_error: StdResult = grid.step(Vector2i(-1, 0), Vector2i.RIGHT)
	assert_err(source_error, "out-of-bounds source errs")
	assert_eq(
			source_error.unwrap_err(),
			"source cell (-1, 0) is out of bounds",
			"source error identifies the bad cell")
	var destination_error: StdResult = grid.step(Vector2i(3, 2), Vector2i.RIGHT)
	assert_err(destination_error, "out-of-bounds destination errs")
	assert_eq(destination_error.unwrap_err(), "(4, 2)", "destination error is the landing cell")
	assert_err(grid.step(Vector2i(0, 0), Vector2i.UP), "top edge step errs")
	assert_err(grid.step(Vector2i(0, 0), Vector2i.LEFT), "left edge step errs")
	return


func _test_step_wraps_edges_but_not_invalid_sources() -> void:
	var grid: StdGrid2D = _make_grid(true)
	assert_eq(
			grid.step(Vector2i(3, 1), Vector2i.RIGHT).unwrap(),
			Vector2i(0, 1),
			"right edge wraps")
	assert_eq(
			grid.step(Vector2i(0, 0), Vector2i(-1, -1)).unwrap(),
			Vector2i(3, 2),
			"diagonal corner wraps")
	assert_err(
			grid.step(Vector2i(4, 1), Vector2i.LEFT),
			"wrapping does not legitimize an invalid source")
	return


func _test_neighbors_bounded_and_reject_invalid_sources() -> void:
	var grid: StdGrid2D = _make_grid()
	assert_eq(grid.neighbors4(Vector2i.ZERO).size(), 2, "corner has two neighbors4")
	assert_eq(grid.neighbors4(Vector2i(1, 0)).size(), 3, "edge has three neighbors4")
	assert_eq(grid.neighbors4(Vector2i(1, 1)).size(), 4, "center has four neighbors4")
	assert_eq(grid.neighbors8(Vector2i.ZERO).size(), 3, "corner has three neighbors8")
	assert_eq(grid.neighbors8(Vector2i(1, 1)).size(), 8, "center has eight neighbors8")
	assert_eq(
			grid.neighbors4(Vector2i(-1, 0)),
			[] as Array[Vector2i],
			"negative source has no neighbors")
	assert_eq(
			grid.neighbors8(Vector2i(4, 2)),
			[] as Array[Vector2i],
			"past-edge source has no neighbors")
	return


func _test_wrapped_neighbors_preserve_directional_duplicates() -> void:
	var dot: StdGrid2D = StdGrid2D.new(
			Vector2i.ONE, Vector2.ONE, Vector2.ZERO, true)
	assert_eq(
			dot.neighbors4(Vector2i.ZERO),
			[Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO],
			"1x1 wrapped grid returns one entry per direction")
	var line: StdGrid2D = StdGrid2D.new(
			Vector2i(2, 1), Vector2.ONE, Vector2.ZERO, true)
	assert_eq(line.neighbors4(Vector2i.ZERO).size(), 4, "2x1 wrapped grid has four entries")
	assert_eq(
			line.neighbors4(Vector2i.ZERO).count(Vector2i(1, 0)),
			2,
			"left and right may resolve to the same neighbor")
	return


func _test_all_cells_are_row_major_and_unique() -> void:
	var grid: StdGrid2D = _make_grid()
	var cells: Array[Vector2i] = grid.all_cells()
	assert_eq(cells.size(), grid.cell_count(), "all_cells count matches cell_count")
	assert_eq(cells.front(), Vector2i.ZERO, "enumeration starts at top-left")
	assert_eq(cells[1], Vector2i(1, 0), "x advances first")
	assert_eq(cells.back(), Vector2i(3, 2), "enumeration ends at bottom-right")
	var unique: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		unique[cell] = true
	assert_eq(unique.size(), grid.cell_count(), "enumeration has no duplicates")
	return


func _test_border_side_and_inward_direction() -> void:
	var grid: StdGrid2D = _make_grid()
	assert_true(grid.is_border(Vector2i.ZERO), "corner is a border")
	assert_true(not grid.is_border(Vector2i(1, 1)), "interior is not a border")
	assert_true(not grid.is_border(Vector2i(-1, 0)), "out-of-bounds is not a border")
	assert_eq(grid.side_of(Vector2i(0, 1)).unwrap(), StdGrid2D.Side.LEFT, "left side")
	assert_eq(grid.side_of(Vector2i(3, 1)).unwrap(), StdGrid2D.Side.RIGHT, "right side")
	assert_eq(grid.side_of(Vector2i(1, 0)).unwrap(), StdGrid2D.Side.TOP, "top side")
	assert_eq(grid.side_of(Vector2i(1, 2)).unwrap(), StdGrid2D.Side.BOTTOM, "bottom side")
	assert_eq(
			grid.side_of(Vector2i.ZERO).unwrap(),
			StdGrid2D.Side.LEFT,
			"corner consistently prefers its x-axis side")
	assert_true(grid.side_of(Vector2i(1, 1)).is_none(), "interior has no side")
	assert_eq(grid.inward_dir(Vector2i(1, 0)), Vector2i.DOWN, "top points down")
	assert_eq(grid.inward_dir(Vector2i(1, 2)), Vector2i.UP, "bottom points up")
	assert_eq(grid.inward_dir(Vector2i(0, 1)), Vector2i.RIGHT, "left points right")
	assert_eq(grid.inward_dir(Vector2i(3, 1)), Vector2i.LEFT, "right points left")
	assert_eq(grid.inward_dir(Vector2i(1, 1)), Vector2i.ZERO, "interior points nowhere")
	return


func _test_wall_cells_handle_regular_and_degenerate_boards() -> void:
	var grid: StdGrid2D = _make_grid()
	assert_eq(
			grid.wall_cells(StdGrid2D.Side.TOP),
			[Vector2i(1, 0), Vector2i(2, 0)],
			"top wall omits corners")
	assert_eq(
			grid.wall_cells(StdGrid2D.Side.TOP, true),
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
			"top wall can include corners")
	assert_eq(
			grid.wall_cells(StdGrid2D.Side.LEFT),
			[Vector2i(0, 1)],
			"left wall omits corners")
	var vertical: StdGrid2D = StdGrid2D.new(Vector2i(1, 5), Vector2.ONE)
	assert_eq(
			vertical.wall_cells(StdGrid2D.Side.TOP),
			[] as Array[Vector2i],
			"one-wide top wall has no non-corner cells")
	assert_true(vertical.is_border(Vector2i(0, 2)), "one-wide grid is entirely border")
	var horizontal: StdGrid2D = StdGrid2D.new(Vector2i(5, 1), Vector2.ONE)
	assert_eq(
			horizontal.wall_cells(StdGrid2D.Side.LEFT),
			[] as Array[Vector2i],
			"one-high left wall has no non-corner cells")
	return
