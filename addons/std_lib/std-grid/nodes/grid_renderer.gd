class_name StdGridRenderer
extends Node2D
## Draws a [StdGrid2D] as a checkerboard with optional cell highlights.
##
## The quickest way to see a grid: assign one with [method set_grid]
## and it draws the checker at the grid's origin and cell size, plus any
## highlighted cells over it. The grid origin is interpreted in this
## node's local coordinate space, so keep the renderer at an identity
## transform when the grid origin is already a world-space coordinate.
## Use it directly for debugging and prototyping, or extend it and draw
## entities after [code]super._draw()[/code].
## [codeblock lang=gdscript]
## var renderer: StdGridRenderer = StdGridRenderer.new()
## add_child(renderer)
## var _rv: StdResult = renderer.set_grid(grid)
## renderer.highlight(path_cell, Color.YELLOW)
## [/codeblock]

## Checker color for cells where [code](x + y)[/code] is even.
## Assigning it queues a redraw.
@export var color_a: Color = Color(0.13, 0.17, 0.13):
	set(value):
		color_a = value
		queue_redraw()
		return
## Checker color for cells where [code](x + y)[/code] is odd.
## Assigning it queues a redraw.
@export var color_b: Color = Color(0.15, 0.20, 0.15):
	set(value):
		color_b = value
		queue_redraw()
		return

var _grid: StdGrid2D
var _highlights: Dictionary[Vector2i, Color] = {}


#region Engine Methods
func _draw() -> void:
	if _grid == null:
		return
	var cell_size: Vector2 = _grid.cell_size()
	var origin: Vector2 = _grid.origin()
	var grid_size: Vector2i = _grid.size()
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var color: Color = color_a if (x + y) % 2 == 0 else color_b
			draw_rect(Rect2(origin + Vector2(x, y) * cell_size, cell_size), color)
	for cell in _highlights:
		draw_rect(Rect2(origin + Vector2(cell) * cell_size, cell_size),
				_highlights.get(cell))
	return
#endregion Engine Methods


#region Public API
## Assigns the grid to draw and queues a redraw. Errs when
## [param grid] is null. On success the ok value is the grid.
func set_grid(grid: StdGrid2D) -> StdResult:
	if grid == null:
		return StdResult.err("grid is null")
	_grid = grid
	queue_redraw()
	return StdResult.ok(grid)


## The assigned grid, or [code]none[/code].
func grid() -> StdOption:
	if _grid == null:
		return StdOption.none()
	return StdOption.some(_grid)


## Fills [param cell] with [param color] on top of the checker and queues
## a redraw. A repeated cell replaces its previous color. Bounds are not
## validated or clipped, so an out-of-bounds cell is still stored and drawn.
func highlight(cell: Vector2i, color: Color) -> void:
	_highlights[cell] = color
	queue_redraw()
	return


## A sorted snapshot of the highlighted cell coordinates.
func highlights() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _highlights:
		cells.append(cell)
	cells.sort()
	return cells


## Removes every highlight and queues a redraw.
func clear_highlights() -> void:
	_highlights.clear()
	queue_redraw()
	return
#endregion Public API
