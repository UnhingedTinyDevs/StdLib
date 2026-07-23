extends StdTest
## Portal contract and mutation tests for [StdGrid2D].


func _make_grid(wraps: bool = false) -> StdGrid2D:
	return StdGrid2D.new(Vector2i(4, 3), Vector2.ONE, Vector2.ZERO, wraps)


func _test_two_way_portal_reserves_both_endpoints() -> void:
	var grid: StdGrid2D = _make_grid()
	var a: Vector2i = Vector2i(0, 1)
	var b: Vector2i = Vector2i(3, 2)
	var result: StdResult = grid.add_portal(a, b)
	assert_ok(result, "valid portal is added")
	assert_eq(result.unwrap(), [a, b], "ok payload is the endpoint pair")
	assert_true(grid.is_portal(a), "first endpoint is reserved")
	assert_true(grid.is_portal(b), "second endpoint is reserved")
	assert_eq(grid.portal_exit(a).unwrap(), b, "forward exit")
	assert_eq(grid.portal_exit(b).unwrap(), a, "reverse exit")
	assert_eq(grid.portal_cells(), [a, b] as Array[Vector2i], "endpoints are sorted")
	return


func _test_one_way_exit_is_reserved_but_has_no_reverse_link() -> void:
	var grid: StdGrid2D = _make_grid()
	var entrance: Vector2i = Vector2i.ZERO
	var exit_cell: Vector2i = Vector2i(3, 2)
	assert_ok(grid.add_portal(entrance, exit_cell, false), "one-way portal is added")
	assert_true(grid.is_portal(entrance), "entrance is reserved")
	assert_true(grid.is_portal(exit_cell), "one-way exit is also reserved")
	assert_eq(
			grid.portal_cells(),
			[entrance, exit_cell] as Array[Vector2i],
			"listing includes both one-way endpoints")
	assert_eq(grid.portal_exit(entrance).unwrap(), exit_cell, "entrance has an exit")
	assert_true(grid.portal_exit(exit_cell).is_none(), "one-way exit has no reverse link")
	assert_err(
			grid.add_portal(exit_cell, Vector2i(1, 1), false),
			"one-way exit cannot be reused as an entrance")
	assert_err(
			grid.add_portal(Vector2i(1, 1), exit_cell, false),
			"one-way exit cannot be reused as an exit")
	return


func _test_invalid_additions_are_atomic() -> void:
	var grid: StdGrid2D = _make_grid()
	var a: Vector2i = Vector2i(0, 1)
	var b: Vector2i = Vector2i(3, 2)
	assert_ok(grid.add_portal(a, b, false), "baseline portal is added")
	var expected: Array[Vector2i] = [a, b]
	assert_err(grid.add_portal(Vector2i(-1, 0), Vector2i(1, 1)), "bad entrance errs")
	assert_eq(grid.portal_cells(), expected, "bad entrance does not mutate registry")
	assert_err(grid.add_portal(Vector2i(1, 1), Vector2i(9, 9)), "bad exit errs")
	assert_eq(grid.portal_cells(), expected, "bad exit does not mutate registry")
	assert_err(grid.add_portal(Vector2i(1, 1), Vector2i(1, 1)), "self-link errs")
	assert_eq(grid.portal_cells(), expected, "self-link does not mutate registry")
	assert_err(grid.add_portal(a, Vector2i(1, 1)), "reused endpoint errs")
	assert_eq(grid.portal_cells(), expected, "reused endpoint does not mutate registry")
	assert_err(grid.add_portal(Vector2i(1, 1), b), "reused destination errs")
	assert_eq(grid.portal_cells(), expected, "reused destination does not mutate registry")
	return


func _test_step_resolves_portal_once() -> void:
	var grid: StdGrid2D = _make_grid()
	var entrance: Vector2i = Vector2i(2, 1)
	var exit_cell: Vector2i = Vector2i(0, 2)
	assert_ok(grid.add_portal(entrance, exit_cell), "portal is added")
	assert_eq(
			grid.step(Vector2i(1, 1), Vector2i.RIGHT).unwrap(),
			exit_cell,
			"landing on entrance teleports to exit")
	assert_eq(
			grid.step(Vector2i(1, 2), Vector2i.LEFT).unwrap(),
			entrance,
			"two-way link works in reverse")
	assert_eq(
			grid.step(exit_cell, Vector2i.RIGHT).unwrap(),
			Vector2i(1, 2),
			"stepping away from an endpoint is ordinary movement")
	assert_err(
			grid.step(Vector2i(3, 1), Vector2i.RIGHT),
			"portal does not rescue an off-board destination")
	return


func _test_wrapping_resolves_before_portal() -> void:
	var grid: StdGrid2D = _make_grid(true)
	assert_ok(
			grid.add_portal(Vector2i(0, 1), Vector2i(2, 2)),
			"portal is added to wrapping grid")
	assert_eq(
			grid.step(Vector2i(3, 1), Vector2i.RIGHT).unwrap(),
			Vector2i(2, 2),
			"wrapped landing cell triggers portal")
	return


func _test_remove_two_way_portal_releases_both_endpoints() -> void:
	var grid: StdGrid2D = _make_grid()
	var a: Vector2i = Vector2i(0, 1)
	var b: Vector2i = Vector2i(3, 2)
	assert_ok(grid.add_portal(a, b), "portal is added")
	var removed: StdOption = grid.remove_portal(b)
	assert_true(removed.is_some(), "either two-way entrance can remove the pair")
	assert_eq(removed.unwrap(), a, "remove returns the former exit")
	assert_true(not grid.is_portal(a), "first endpoint is released")
	assert_true(not grid.is_portal(b), "second endpoint is released")
	assert_true(grid.portal_exit(a).is_none(), "forward link is gone")
	assert_true(grid.portal_exit(b).is_none(), "reverse link is gone")
	assert_true(grid.remove_portal(a).is_none(), "removing again returns none")
	assert_ok(grid.add_portal(a, b), "released endpoints can be reused")
	return


func _test_remove_one_way_requires_entrance_and_releases_exit() -> void:
	var grid: StdGrid2D = _make_grid()
	var entrance: Vector2i = Vector2i(0, 1)
	var exit_cell: Vector2i = Vector2i(3, 2)
	assert_ok(grid.add_portal(entrance, exit_cell, false), "one-way portal is added")
	assert_true(
			grid.remove_portal(exit_cell).is_none(),
			"one-way exit cannot remove a link it does not own")
	assert_eq(grid.portal_cells().size(), 2, "failed removal leaves endpoints reserved")
	assert_eq(grid.remove_portal(entrance).unwrap(), exit_cell, "entrance removes link")
	assert_eq(
			grid.portal_cells(),
			[] as Array[Vector2i],
			"one-way removal releases both endpoints")
	return


func _test_clear_portals_releases_every_endpoint() -> void:
	var grid: StdGrid2D = _make_grid()
	assert_ok(grid.add_portal(Vector2i(0, 0), Vector2i(3, 2)), "first pair")
	assert_ok(
			grid.add_portal(Vector2i(1, 0), Vector2i(2, 2), false),
			"second one-way pair")
	grid.clear_portals()
	assert_eq(grid.portal_cells(), [] as Array[Vector2i], "registry is empty")
	for cell: Vector2i in grid.all_cells():
		assert_true(not grid.is_portal(cell), "cell %s is released" % cell)
		assert_true(grid.portal_exit(cell).is_none(), "cell %s has no link" % cell)
	assert_ok(
			grid.add_portal(Vector2i(0, 0), Vector2i(3, 2)),
			"cleared endpoints can be reused")
	return
