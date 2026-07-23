class_name StdGrid2D
extends RefCounted
## A rectangular grid of cells with world-space mapping.
##
## Pure board math for tile and grid games: convert between cell and
## world coordinates, query bounds and neighbors, step across the board
## (with optional edge wrapping), and pick random free cells. Holds no
## nodes and renders nothing, so it is fully usable headless.
## [codeblock lang=gdscript]
## var grid: StdGrid2D = StdGrid2D.new(Vector2i(24, 24), Vector2(32, 32))
## var world: Vector2 = grid.cell_to_world(Vector2i(3, 4))
## var rv: StdResult = grid.step(Vector2i(23, 0), Vector2i.RIGHT)
## if rv.is_err(): print("fell off the board")
## [/codeblock]

## The four walls of the board, used by the border queries.
enum Side { TOP, BOTTOM, LEFT, RIGHT }

const _DIRS4: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
]

const _DIRS8: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]

var _size: Vector2i
var _cell_size: Vector2
var _origin: Vector2
var _wraps: bool
# Portal links, entrance -> exit. A two-way pair stores both directions.
var _portals: Dictionary[Vector2i, Vector2i] = {}
# Every reserved endpoint, including one-way exits.
var _portal_endpoints: Dictionary[Vector2i, bool] = {}


#region Engine Methods
## Builds a grid of [param grid_size] cells, each [param cell_size]
## world units, anchored at [param origin] (the top-left corner of cell
## [code](0, 0)[/code]). When [param wraps] is true, [method step] and
## the neighbor queries wrap around the board edges. [param grid_size]
## is clamped to at least 1x1. Non-positive or non-finite
## [param cell_size] axes are individually replaced with [code]1.0[/code].
## Every correction warns. Non-finite [param origin] axes are individually
## replaced with [code]0.0[/code].
func _init(
	grid_size: Vector2i,
	cell_size: Vector2,
	origin: Vector2 = Vector2.ZERO,
	wraps: bool = false,
) -> void:
	if grid_size.x < 1 or grid_size.y < 1:
		push_warning("StdGrid2D size must be at least 1x1, got %s; clamping" % grid_size)
	_size = Vector2i(maxi(grid_size.x, 1), maxi(grid_size.y, 1))
	if (
		not is_finite(cell_size.x)
		or not is_finite(cell_size.y)
		or cell_size.x <= 0.0
		or cell_size.y <= 0.0
	):
		push_warning("StdGrid2D cell size must be positive, got %s; clamping to 1.0" % cell_size)
	_cell_size = Vector2(
		cell_size.x if is_finite(cell_size.x) and cell_size.x > 0.0 else 1.0,
		cell_size.y if is_finite(cell_size.y) and cell_size.y > 0.0 else 1.0,
	)
	if not is_finite(origin.x) or not is_finite(origin.y):
		push_warning("StdGrid2D origin must be finite, got %s; replacing invalid axes with 0.0" % origin)
	_origin = Vector2(
		origin.x if is_finite(origin.x) else 0.0,
		origin.y if is_finite(origin.y) else 0.0,
	)
	_wraps = wraps
	return
#endregion Engine Methods


#region Public API
## The board dimensions in cells.
func size() -> Vector2i:
	return _size


## The size of one cell in world units.
func cell_size() -> Vector2:
	return _cell_size


## The world position of the top-left corner of cell [code](0, 0)[/code].
func origin() -> Vector2:
	return _origin


## True when the board wraps around its edges.
func wraps() -> bool:
	return _wraps


## Total number of cells on the board.
func cell_count() -> int:
	return _size.x * _size.y


## True when [param cell] lies inside the board bounds.
func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


## Wraps [param cell] onto the board with [method @GlobalScope.posmod]
## on both axes, so negative and far out-of-range cells land in bounds.
## Works regardless of [method wraps].
func wrap(cell: Vector2i) -> Vector2i:
	return Vector2i(posmod(cell.x, _size.x), posmod(cell.y, _size.y))


## Clamps [param cell] onto the nearest in-bounds cell.
func clamp_cell(cell: Vector2i) -> Vector2i:
	return cell.clamp(Vector2i.ZERO, _size - Vector2i.ONE)


## The world position of the center of [param cell]:
## [code]origin + (cell + 0.5) * cell_size[/code]. Total function, does
## not require the cell to be in bounds.
func cell_to_world(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size


## The cell containing world position [param pos]:
## [code]floor((pos - origin) / cell_size)[/code]. Total function, the
## result may be out of bounds.
func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(((pos - _origin) / _cell_size).floor())


## Applies one orthogonal or diagonal [param dir] to an in-bounds
## [param cell]. Errs when the source is out of bounds, or when
## [param dir] is zero or has an axis outside [code]-1..1[/code].
## On success the ok value is the destination ([Vector2i]).
##
## A wrapping grid wraps an otherwise valid step at the edge. A
## non-wrapping grid errs when the destination is out of bounds. If the
## resolved destination is a portal entrance, the ok value is its exit
## instead. Portal resolution is exactly one hop. Portals cannot rescue
## an out-of-bounds source or destination.
## [codeblock lang=gdscript]
## var rv: StdResult = grid.step(head, Vector2i.RIGHT)
## if rv.is_err(): _die(rv.unwrap_err())
## [/codeblock]
func step(cell: Vector2i, dir: Vector2i) -> StdResult:
	if not contains(cell):
		return StdResult.err("source cell %s is out of bounds" % cell)
	if dir == Vector2i.ZERO or absi(dir.x) > 1 or absi(dir.y) > 1:
		return StdResult.err("direction %s must be one orthogonal or diagonal step" % dir)
	var next: Vector2i = cell + dir
	if _wraps:
		# self-qualified: bare wrap() resolves to @GlobalScope.wrap
		next = self.wrap(next)
	elif not contains(next):
		return StdResult.err("%s" % next)
	if _portals.has(next):
		return StdResult.ok(_portals.get(next))
	return StdResult.ok(next)


## Links portal [param a] to [param b]: a [method step] resolving onto
## [param a] lands on [param b] instead. When [param two_way] is true
## (the default) the reverse link is added too. Errs when either cell
## is out of bounds, the cells are equal, or either cell is already a
## portal endpoint. Endpoints are exclusive even for one-way portals.
## On success the ok value is [code][a, b][/code].
## [codeblock lang=gdscript]
## var _rv: StdResult = grid.add_portal(Vector2i(0, 4), Vector2i(9, 0))
## [/codeblock]
func add_portal(a: Vector2i, b: Vector2i, two_way: bool = true) -> StdResult:
	if not contains(a):
		return StdResult.err("portal cell %s is out of bounds" % a)
	if not contains(b):
		return StdResult.err("portal cell %s is out of bounds" % b)
	if a == b:
		return StdResult.err("portal cannot lead to itself at %s" % a)
	if _portal_endpoints.has(a):
		return StdResult.err("cell %s is already a portal" % a)
	if _portal_endpoints.has(b):
		return StdResult.err("cell %s is already a portal" % b)
	_portals[a] = b
	_portal_endpoints[a] = true
	_portal_endpoints[b] = true
	if two_way:
		_portals[b] = a
	return StdResult.ok([a, b])


## Removes the portal link leaving [param cell], and the reverse link
## when the pair was two-way. Returns the former exit, or
## [code]none[/code] when the cell is not a portal entrance.
func remove_portal(cell: Vector2i) -> StdOption:
	if not _portals.has(cell):
		return StdOption.none()
	var exit_cell: Vector2i = _portals.get(cell)
	_portals.erase(cell)
	if _portals.has(exit_cell) and _portals.get(exit_cell) == cell:
		_portals.erase(exit_cell)
	_portal_endpoints.erase(cell)
	_portal_endpoints.erase(exit_cell)
	return StdOption.some(exit_cell)


## Where the portal at [param cell] leads, or [code]none[/code] when
## the cell is not a portal entrance.
func portal_exit(cell: Vector2i) -> StdOption:
	if not _portals.has(cell):
		return StdOption.none()
	return StdOption.some(_portals.get(cell))


## True when [param cell] is a reserved portal endpoint. For a one-way
## portal this includes its exit, even though [method portal_exit] is
## [code]none[/code] there.
func is_portal(cell: Vector2i) -> bool:
	return _portal_endpoints.has(cell)


## Every reserved portal endpoint, sorted.
func portal_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _portal_endpoints:
		cells.append(cell)
	cells.sort()
	return cells


## Removes every portal.
func clear_portals() -> void:
	_portals.clear()
	_portal_endpoints.clear()
	return


## True when [param cell] is in bounds and touches at least one wall.
## Out-of-bounds cells are not borders.
func is_border(cell: Vector2i) -> bool:
	if not contains(cell):
		return false
	return (
		cell.x == 0 or cell.y == 0
		or cell.x == _size.x - 1 or cell.y == _size.y - 1
	)


## The [enum StdGrid2D.Side] a border cell sits on, or [code]none[/code] for
## interior and out-of-bounds cells. Corners resolve to their x-axis
## wall (LEFT/RIGHT win), matching [method inward_dir].
func side_of(cell: Vector2i) -> StdOption:
	if not contains(cell):
		return StdOption.none()
	if cell.x == 0:
		return StdOption.some(Side.LEFT)
	if cell.x == _size.x - 1:
		return StdOption.some(Side.RIGHT)
	if cell.y == 0:
		return StdOption.some(Side.TOP)
	if cell.y == _size.y - 1:
		return StdOption.some(Side.BOTTOM)
	return StdOption.none()


## The direction pointing into the board from a border cell (top wall
## points DOWN, left wall points RIGHT, ...). Returns
## [constant Vector2i.ZERO] for interior and out-of-bounds cells;
## corners resolve to their x-axis wall first, matching
## [method side_of].
func inward_dir(cell: Vector2i) -> Vector2i:
	var side: StdOption = side_of(cell)
	if side.is_none():
		return Vector2i.ZERO
	match side.unwrap():
		Side.LEFT: return Vector2i.RIGHT
		Side.RIGHT: return Vector2i.LEFT
		Side.TOP: return Vector2i.DOWN
		_: return Vector2i.UP


## Every cell along the given wall, in ascending order. Corner cells
## are skipped unless [param include_corners] is true.
func wall_cells(side: StdGrid2D.Side, include_corners: bool = false) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var first: int = 0 if include_corners else 1
	match side:
		Side.TOP:
			for x in range(first, _size.x - first):
				cells.append(Vector2i(x, 0))
		Side.BOTTOM:
			for x in range(first, _size.x - first):
				cells.append(Vector2i(x, _size.y - 1))
		Side.LEFT:
			for y in range(first, _size.y - first):
				cells.append(Vector2i(0, y))
		Side.RIGHT:
			for y in range(first, _size.y - first):
				cells.append(Vector2i(_size.x - 1, y))
		_:
			pass
	return cells


## The 4-connected (orthogonal) neighbors of [param cell]. Wrapped onto
## the board when the grid wraps, otherwise filtered to in-bounds cells.
## Pure geometry — portals are not resolved; [method step] is the
## portal-aware operation. Returns an empty array when [param cell] is
## out of bounds.
## Wrapped grids may return duplicates when an axis is one or two cells wide.
func neighbors4(cell: Vector2i) -> Array[Vector2i]:
	return _neighbors(cell, _DIRS4)


## The 8-connected (orthogonal + diagonal) neighbors of [param cell].
## Wrapped onto the board when the grid wraps, otherwise filtered to
## in-bounds cells. Returns an empty array when [param cell] is out of
## bounds. Wrapped
## grids may return duplicates when an axis is one or two cells wide.
func neighbors8(cell: Vector2i) -> Array[Vector2i]:
	return _neighbors(cell, _DIRS8)


## Every cell on the board, row-major.
func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in _size.y:
		for x in _size.x:
			cells.append(Vector2i(x, y))
	return cells


## Picks a uniformly random in-bounds cell that is not in
## [param occupied] (a [StdSet] of [Vector2i]; null means nothing is
## occupied). Every portal endpoint is reserved.
## Returns [code]none[/code] when every eligible cell is occupied. The
## required [param rng] must be non-null; passing null asserts.
func random_free_cell(occupied: StdSet, rng: RandomNumberGenerator) -> StdOption:
	assert(rng != null, "StdGrid2D.random_free_cell() requires a RandomNumberGenerator")
	var selected: Vector2i = Vector2i.ZERO
	var candidate_count: int = 0
	for y: int in _size.y:
		for x: int in _size.x:
			var cell: Vector2i = Vector2i(x, y)
			if _portal_endpoints.has(cell) or (occupied != null and occupied.has(cell)):
				continue
			candidate_count += 1
			# Reservoir sampling keeps the result uniform without an O(n) array.
			if rng.randi_range(1, candidate_count) == 1:
				selected = cell
	if candidate_count == 0:
		return StdOption.none()
	return StdOption.some(selected)


## Picks a uniformly random non-corner cell along [param side] that is
## not in [param exclude] (a [StdSet] of [Vector2i]; null means nothing
## is excluded) and is not a portal endpoint. Returns [code]none[/code]
## when the wall has no free cell left. The required [param rng] must be
## non-null; passing null asserts.
func random_wall_cell(
	side: StdGrid2D.Side,
	rng: RandomNumberGenerator,
	exclude: StdSet = null,
) -> StdOption:
	assert(rng != null, "StdGrid2D.random_wall_cell() requires a RandomNumberGenerator")
	var selected: Vector2i = Vector2i.ZERO
	var candidate_count: int = 0
	for cell: Vector2i in wall_cells(side):
		if _portal_endpoints.has(cell) or (exclude != null and exclude.has(cell)):
			continue
		candidate_count += 1
		if rng.randi_range(1, candidate_count) == 1:
			selected = cell
	if candidate_count == 0:
		return StdOption.none()
	return StdOption.some(selected)
#endregion Public API


#region Private Helpers
func _neighbors(cell: Vector2i, dirs: Array[Vector2i]) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if not contains(cell):
		return found
	for dir in dirs:
		var next: Vector2i = cell + dir
		if _wraps:
			# self-qualified: bare wrap() resolves to @GlobalScope.wrap
			found.append(self.wrap(next))
		elif contains(next):
			found.append(next)
	return found
#endregion Private Helpers
