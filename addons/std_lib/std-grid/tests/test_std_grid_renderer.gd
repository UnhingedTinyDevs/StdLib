extends StdTest
## Headless state, validation, and draw-path tests for [StdGridRenderer].



func _test_set_grid() -> void:
	var renderer: StdGridRenderer = StdGridRenderer.new()
	assert_true(renderer.grid().is_none(), "starts without a grid")
	assert_err(renderer.set_grid(null), "null grid errs")

	var grid: StdGrid2D = StdGrid2D.new(Vector2i(4, 4), Vector2(8, 8))
	var rv: StdResult = renderer.set_grid(grid)
	assert_ok(rv, "set_grid ok")
	assert_eq(rv.unwrap(), grid, "ok value is the grid")
	assert_eq(renderer.grid().unwrap(), grid, "grid() returns the assigned grid")
	renderer.free()
	return


func _test_highlights() -> void:
	var renderer: StdGridRenderer = StdGridRenderer.new()
	var _g: StdResult = renderer.set_grid(StdGrid2D.new(Vector2i(4, 4), Vector2(8, 8)))

	assert_eq(renderer.highlights(), [] as Array[Vector2i], "starts with no highlights")
	renderer.highlight(Vector2i(2, 1), Color.YELLOW)
	renderer.highlight(Vector2i(0, 3), Color.RED)
	renderer.highlight(Vector2i(2, 1), Color.BLUE)  # replaces, no duplicate
	assert_eq(renderer.highlights(), [Vector2i(0, 3), Vector2i(2, 1)] as Array[Vector2i],
			"highlights sorted, re-highlight replaces")
	renderer.highlight(Vector2i(-1, 8), Color.WHITE)
	assert_true(renderer.highlights().has(Vector2i(-1, 8)),
			"out-of-bounds highlights are retained")
	var replacement: StdGrid2D = StdGrid2D.new(Vector2i.ONE, Vector2.ONE)
	assert_ok(renderer.set_grid(replacement), "grid can be replaced")
	assert_true(renderer.highlights().has(Vector2i(-1, 8)),
			"replacing the grid preserves highlights")
	renderer.clear_highlights()
	assert_eq(renderer.highlights(), [] as Array[Vector2i], "clear removes everything")
	renderer.free()
	return


func _test_highlights_returns_an_independent_snapshot() -> void:
	var renderer: StdGridRenderer = StdGridRenderer.new()
	renderer.highlight(Vector2i(2, 1), Color.YELLOW)
	var snapshot: Array[Vector2i] = renderer.highlights()
	snapshot.clear()
	assert_eq(
			renderer.highlights(),
			[Vector2i(2, 1)] as Array[Vector2i],
			"mutating a snapshot does not mutate renderer state")
	renderer.free()
	return


func _test_draw_path_runs_headless_after_runtime_changes() -> void:
	var renderer: StdGridRenderer = StdGridRenderer.new()
	var _tracked: Node = add_to_tree(renderer)
	var grid: StdGrid2D = StdGrid2D.new(
			Vector2i(8, 6), Vector2(3.5, 4.25), Vector2(-9.0, 2.0))
	assert_ok(renderer.set_grid(grid), "grid is assigned in the scene tree")
	renderer.highlight(Vector2i(3, 2), Color.YELLOW)
	renderer.highlight(Vector2i(-1, 9), Color.RED)
	renderer.color_a = Color.BLUE
	renderer.color_b = Color.GREEN
	await process_wait(2)
	assert_eq(renderer.color_a, Color.BLUE, "runtime color_a assignment is retained")
	assert_eq(renderer.color_b, Color.GREEN, "runtime color_b assignment is retained")
	assert_true(is_instance_valid(renderer), "draw path completes without invalidating renderer")
	return
