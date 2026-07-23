# Std Grid

[← StdLib](../../../README.md)

## Description

Pure board math for tile and grid games: convert between cell and world
coordinates, query bounds and neighbors, step across the board with optional edge
wrapping, link portals, and pick random free cells. `StdGrid2D` holds no nodes and
renders nothing, so its board logic runs headless. The companion
`StdGridRenderer` is an optional `Node2D` for seeing a grid in a scene.

Every grid game re-derives the same arithmetic: which pixel is cell `(3, 4)`, what
cell did the mouse land in, does `(23, 0)` stepping right fall off the edge or wrap
to `(0, 0)`. Getting the `floor` and the `+0.5` centering right, consistently,
across a whole codebase, is more fiddly than it looks. This is that math, written
once and tested.

```gdscript
var grid: StdGrid2D = StdGrid2D.new(Vector2i(24, 24), Vector2(32, 32))
var world: Vector2 = grid.cell_to_world(Vector2i(3, 4))
var rv: StdResult = grid.step(Vector2i(23, 0), Vector2i.RIGHT)
if rv.is_err():
	_die("fell off the board")
```

| Type | Role |
|---|---|
| `StdGrid2D` | Globally named `RefCounted` board geometry, portals, and placement queries. |
| `StdGridRenderer` | Globally named `Node2D` checkerboard and highlight renderer. |

The module adds no autoload. It depends on [StdReturns](StdReturns.md) for
`StdResult`/`StdOption` and [StdCollections](StdCollections.md) for the `StdSet`
occupancy parameters. `StdRandom` is optional; any non-null
`RandomNumberGenerator` can drive random placement.

## Concepts

### Cells, world, origin

A cell is a `Vector2i` grid coordinate; a world position is a `Vector2` in pixels.
The grid maps between them from three numbers fixed at construction: its size in
cells, its cell size in world units, and its **origin** — the world position of
the top-left corner of cell `(0, 0)`.

`cell_to_world` returns the **center** of a cell (`origin + (cell + 0.5) *
cell_size`), which is what you want for placing a sprite. `world_to_cell` floors,
so it's the inverse for "which cell is this pixel in".

Both perform their arithmetic without requiring an in-bounds cell. For finite
world coordinates, `world_to_cell` may return an out-of-bounds result. Check
`contains()` when the caller requires a board cell.

### Wrapping

A grid is wrapping or not, set at construction. When it wraps, `step` and the
neighbor queries carry a cell off one edge and back onto the opposite one; when it
doesn't, stepping off the board errs. `wrap()` itself works regardless — it's the
raw `posmod` on both axes, there when you want to wrap by hand.

Wrapping preserves one result per requested direction. On a one- or two-cell
axis, different directions can resolve to the same cell, so neighbor arrays may
contain duplicates.

### Portals

A portal links one cell to another: a `step` that resolves **onto** a portal
entrance lands on its exit instead. Portals are cell-based, not holes in the wall
— they never rescue an out-of-bounds step, and the teleport is exactly one hop.

Both cells are reserved endpoints. In a two-way portal they are both entrances;
in a one-way portal only `a` has an outgoing link, but `b` remains reserved.
Exclusive endpoints prevent accidental portal chains and keep random placement
off entrances and exits.

## API

### `StdGrid2D`

#### `Side`

```gdscript
enum Side { TOP, BOTTOM, LEFT, RIGHT }
```

Used by the border and wall queries.

#### `_init`

```gdscript
func _init(
	grid_size: Vector2i,
	cell_size: Vector2,
	origin: Vector2 = Vector2.ZERO,
	wraps: bool = false,
) -> void
```

Builds the grid. `grid_size` is clamped to at least 1×1, non-positive or
non-finite `cell_size` axes are individually replaced with `1.0`, and non-finite
`origin` axes are individually replaced with `0.0`. Each kind of correction
emits a warning, and valid axes are preserved.

Size, cell size, origin, and wrapping are fixed after construction. Portal
links are the mutable part of a grid.

```gdscript
var grid: StdGrid2D = StdGrid2D.new(Vector2i(10, 8), Vector2(16, 16))
var toroid: StdGrid2D = StdGrid2D.new(
	Vector2i(10, 8),
	Vector2(16, 16),
	Vector2.ZERO,
	true,
)
```

#### Board properties

```gdscript
func size() -> Vector2i          # dimensions in cells
func cell_size() -> Vector2      # one cell in world units
func origin() -> Vector2         # world pos of cell (0,0)'s top-left corner
func wraps() -> bool
func cell_count() -> int         # size.x * size.y
```

#### `contains` / `wrap` / `clamp_cell`

```gdscript
func contains(cell: Vector2i) -> bool
func wrap(cell: Vector2i) -> Vector2i
func clamp_cell(cell: Vector2i) -> Vector2i
```

`contains` is the bounds test. `wrap` maps any cell onto the board with `posmod`
(works whether or not the grid wraps). `clamp_cell` pins an out-of-bounds cell to
the nearest edge cell instead of wrapping.

#### `cell_to_world` / `world_to_cell`

```gdscript
func cell_to_world(cell: Vector2i) -> Vector2      # center of the cell
func world_to_cell(pos: Vector2) -> Vector2i       # floor((pos - origin) / cell_size)
```

Total functions — the result of `world_to_cell` may be out of bounds; check with
`contains`.

```gdscript
sprite.position = grid.cell_to_world(cell)
var clicked: Vector2i = grid.world_to_cell(get_global_mouse_position())
if grid.contains(clicked):
	select(clicked)
```

#### `step`

```gdscript
func step(cell: Vector2i, dir: Vector2i) -> StdResult
```

Moves from an in-bounds `cell` by exactly one orthogonal or diagonal `dir`.
`Vector2i.ZERO` and directions with either axis outside `-1..1` err. An
out-of-bounds source also errs. On success the ok value is the resolved
destination.

- **Wrapping grid**: a valid step wraps around the edge.
- **Non-wrapping grid**: errs when the step leaves the board — the error string is
  the out-of-bounds cell.
- **Portals**: when the resolved cell is a portal entrance, the ok value is its
  exit instead. Exactly one hop; portals never rescue invalid movement.

```gdscript
var rv: StdResult = grid.step(head, dir)
if rv.is_err():
	_game_over()
else:
	head = rv.unwrap()
```

#### Portals

```gdscript
func add_portal(a: Vector2i, b: Vector2i, two_way: bool = true) -> StdResult
func remove_portal(cell: Vector2i) -> StdOption
func portal_exit(cell: Vector2i) -> StdOption
func is_portal(cell: Vector2i) -> bool
func portal_cells() -> Array[Vector2i]
func clear_portals() -> void
```

`add_portal` links `a` to `b`, and by default adds the reverse link too. It errs
when either cell is out of bounds, the two cells are equal, or either cell is
already a portal endpoint. Rejection is atomic. On success the ok value is
`[a, b]`.

`remove_portal` takes an entrance, removes it (and the reverse link when the pair
was two-way), and returns the former exit; `none` when the cell wasn't an
entrance. It releases both endpoints. `portal_exit` reads the outgoing link
without removing it, so it returns `none` at a one-way exit. `is_portal` checks
whether a cell is any reserved endpoint, and `portal_cells` returns every
endpoint sorted. One-way exits cannot be reused until their portal is removed.

```gdscript
var _rv: StdResult = grid.add_portal(Vector2i(0, 4), Vector2i(9, 0)).warn("board")
```

#### Borders and walls

```gdscript
func is_border(cell: Vector2i) -> bool
func side_of(cell: Vector2i) -> StdOption
func inward_dir(cell: Vector2i) -> Vector2i
func wall_cells(side: StdGrid2D.Side, include_corners: bool = false) -> Array[Vector2i]
```

`is_border` — the cell is in bounds and touches at least one wall. `side_of` — the
`Side` a border cell sits on, `none` for interior and out-of-bounds cells.
`inward_dir` — the direction pointing into the board from a border cell (top wall
→ `DOWN`), `Vector2i.ZERO` for interior/out-of-bounds. `wall_cells` — every cell
along a wall, corners skipped unless `include_corners`.

**Corners resolve to their x-axis wall**: a corner cell reports `LEFT`/`RIGHT`,
not `TOP`/`BOTTOM`, and `side_of` and `inward_dir` agree on this.

#### Neighbors and enumeration

```gdscript
func neighbors4(cell: Vector2i) -> Array[Vector2i]     # orthogonal
func neighbors8(cell: Vector2i) -> Array[Vector2i]     # orthogonal + diagonal
func all_cells() -> Array[Vector2i]                    # row-major
```

Neighbors are wrapped onto the board when the grid wraps, otherwise filtered to
in-bounds cells — so a corner cell has two `neighbors4` on a non-wrapping board,
four entries on a wrapping one. An out-of-bounds starting cell returns an empty
array. On narrow wrapping grids, multiple directions can produce duplicate cells.

Neighbor queries are pure geometry: portals are not resolved. `step` is the
portal-aware move.

#### `random_free_cell` / `random_wall_cell`

```gdscript
func random_free_cell(occupied: StdSet, rng: RandomNumberGenerator) -> StdOption
func random_wall_cell(
	side: StdGrid2D.Side,
	rng: RandomNumberGenerator,
	exclude: StdSet = null,
) -> StdOption
```

Pick a uniformly random cell that isn't taken. `random_free_cell` avoids the
[`StdSet`](collections/Set.md) of `occupied` cells (`null` means nothing is
occupied); `random_wall_cell` picks a non-corner cell on one wall, avoiding
`exclude`. Both skip every portal endpoint and return `none` when no eligible
cell is left.

The RNG is required and must be non-null; passing null asserts. This keeps
ownership and determinism explicit. Use a dedicated named stream when placement
should not shift other systems.

```gdscript
var spawn: StdOption = grid.random_free_cell(occupied, StdRandom.stream(&"spawns"))
if spawn.is_some():
	place_food(spawn.unwrap())
```

### `StdGridRenderer`

A `Node2D` that draws a `StdGrid2D` as a checkerboard with optional highlights — the
quickest way to *see* a grid, for debugging and prototyping. Extend it and draw
your entities after `super._draw()` to build on it.

The renderer treats `grid.origin()` as a **local** drawing coordinate. Keep the
renderer at an identity transform when the grid origin already represents world
coordinates; moving or scaling the renderer applies an additional `Node2D`
transform.

```gdscript
@export var color_a: Color = Color(0.13, 0.17, 0.13)   # cells where (x+y) is even
@export var color_b: Color = Color(0.15, 0.20, 0.15)   # cells where (x+y) is odd

func set_grid(grid: StdGrid2D) -> StdResult            # errs on null; ok value is the grid
func grid() -> StdOption
func highlight(cell: Vector2i, color: Color) -> void  # fill one cell over the checker
func highlights() -> Array[Vector2i]                  # sorted snapshot
func clear_highlights() -> void
```

`set_grid()`, `highlight()`, and `clear_highlights()` queue a redraw for you. A
repeated `highlight()` on the same cell replaces its color. Highlight cells are
not bounds-checked or clipped: an out-of-bounds coordinate is retained and
drawn. Assigning another grid also retains existing highlights. Changing
`color_a` or `color_b` also queues a redraw.

```gdscript
var renderer: StdGridRenderer = StdGridRenderer.new()
add_child(renderer)
var _rv: StdResult = renderer.set_grid(grid).warn("render")
for cell: Vector2i in path:
	renderer.highlight(cell, Color.YELLOW)
```

## Gotchas

### `world_to_cell` can return an off-board cell

It's a total function — it floors and hands back whatever cell the math produces,
including negative and out-of-range ones. A click in the margin around the board
returns a cell that isn't on it. Always `contains()`-check the result before you
use it as an index.

### Neighbor queries ignore portals; `step` honors them

`neighbors4`/`neighbors8` are pure adjacency and won't route through a portal.
`step` is the only portal-aware movement. A pathfinder that should use portals
must add those edges explicitly.

### `step` is adjacent movement, not arbitrary translation

`step` requires an in-bounds source and one nonzero direction whose axes are
within `-1..1`. Cardinal and diagonal moves are valid; long jumps and zero moves
err. Use coordinate addition followed by `contains`, `wrap`, or `clamp_cell`
when you intentionally need an arbitrary translation.

Neighbor queries also require an in-bounds source; invalid sources return an
empty array.

### Wrapped neighbors are directional entries, not a set

On a 1×1 wrapping grid, `neighbors4(Vector2i.ZERO)` returns the origin four
times—once for each direction. Two directions can also converge on grids only
two cells wide or high. Convert the array to a set when callers need unique
cells rather than directional adjacency.

### Corners belong to the vertical walls

`side_of(Vector2i(0, 0))` is `LEFT`, not `TOP`. `wall_cells(Side.TOP)` excludes
both top corners by default. If you're stitching the four walls together and
including corners on each, you'll process each corner twice — pass
`include_corners` on only two of the four sides.

### A shared placement stream still couples its callers

Both methods require an RNG. Calls using the same stream advance one sequence, so
adding a food placement can shift later enemy placement if both use `&"spawns"`.
Use more specific stable names when those decisions must evolve independently.

### Portal endpoints are never "free"

`random_free_cell` and `random_wall_cell` treat portal cells as occupied, because
placing on either endpoint usually creates ambiguous gameplay. This includes
one-way exits. Remove the portal before making either endpoint eligible.

### Renderer transforms and highlights are independent of the grid

The renderer draws the grid origin in local space, so a non-identity renderer
transform moves or scales the result again. Highlights are coordinate overlays:
they are not clipped to the current grid and survive `set_grid()`. Call
`clear_highlights()` when replacing a grid should reset them.

Changing `color_a` or `color_b` queues a redraw automatically.

## Testing

```bash
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- addons/std_lib/std-grid
```

The suite covers constructor normalization and diagnostics, fractional coordinate
round-trips, strict movement bounds, wrapping, neighbor multiplicity,
one-/two-way portal mutation, wall and corner rules, deterministic placement,
fatal RNG contracts, renderer state, and a headless draw smoke test. Fixed-seed
stress tests compare geometry and thousands of portal mutations against
independent reference models.

See [StdTests](StdTests.md) for the runner.

## See also

- [StdReturns](StdReturns.md) — the `StdResult`/`StdOption` returned throughout.
- [StdRandom](StdRandom.md) — named `stream()` generators for reproducible cell
  picks.
- [StdCollections](StdCollections.md) — the [`StdSet`](collections/Set.md) the
  random-cell queries take for occupancy.
