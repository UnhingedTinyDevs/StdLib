# Std Algorithms

[← StdLib](../StdLib.md)

Graph searches and ordering, stable sorting, and the comparison callables you'd
otherwise retype in every file.

Godot's `Array.sort_custom` is fast and unstable — equal elements come out in an
arbitrary order, and it makes no promise about which. That's fine until order
carries meaning: a leaderboard tied on score or a render list sorted by layer.
`StdSorts` gives you a stable merge sort.

`StdGraphAlgorithms` searches a [`StdGraph`](collections/Graph.md) for a path
between two vertices or produces a topological ordering of a directed acyclic
graph.

```gdscript
var rv: StdResult = StdSorts.merge_sort(entries, func(a: Variant, b: Variant) -> bool:
        return a.priority < b.priority)
# entries is now sorted; equal priorities kept their original order
```

## Concepts

### Graph search results

`bfs`, `dfs`, `dijkstra`, and `ids` return `StdResult.ok(path)` when they find the
goal. The path is an `Array` beginning with `start` and ending with `goal`. When
both arguments are the same vertex, the path is `[start]`.

A missing start or goal, a `null` graph, or an unreachable goal returns
`StdResult.err(String)`. Searches do not modify the graph.

Directed graphs are searched through outgoing edges. Undirected graphs can be
searched in either direction. `StdGraph` does not guarantee neighbor order, so
DFS paths and choices between equally short or equally cheap paths are not
guaranteed to be the same across graph implementations.

### Edges versus weights

`bfs`, `dfs`, and `ids` treat every edge as one step and ignore its stored
weight. BFS returns a path containing the fewest edges. IDS also finds a
shallowest path, while DFS returns the first path it discovers.

`dijkstra` uses the nonnegative integer weights stored by `StdGraph` and returns
a path with the lowest total weight. It returns the path itself, not the total
weight.

### The comparison convention

A comparator is `Callable(a, b) -> bool` returning **true when `a` sorts before
`b`** — the same convention as `Array.sort_custom`. Ascending order is `a < b`.

The comparator is required. Use `StdCmp.less_than()` for ordinary ascending
order and `StdCmp.greater_than()` for descending order.

### Stability

A stable sort preserves the relative order of elements the comparator considers
equal. Given `[("b", 1), ("a", 1)]` sorted by the number, a stable sort keeps
`("b", 1)` first because it started first. Both sorts here are stable.

### In place, with validation through `StdResult`

Both sorts validate the comparator before touching the array. An empty, freed,
or otherwise invalid callable returns `StdResult.err(String)` and leaves the array
untouched. A valid comparator sorts the array in place and returns
`StdResult.ok(array)` — the same array, so calls can chain.

## API

### `StdGraphAlgorithms`

Static only. Never `StdGraphAlgorithms.new()`.

#### `bfs`

```gdscript
static func bfs(graph: StdGraph, start: Variant, goal: Variant) -> StdResult
```

Searches in breadth-first order and returns a path with the fewest edges. Edge
weights are ignored.

```gdscript
var result: StdResult = StdGraphAlgorithms.bfs(map, "village", "castle")
if result.is_ok():
	var path: Array = result.unwrap()
```

#### `dfs`

```gdscript
static func dfs(graph: StdGraph, start: Variant, goal: Variant) -> StdResult
```

Searches in depth-first order and returns the first path found. The path is not
guaranteed to contain the fewest edges or have the lowest total weight.

#### `dijkstra`

```gdscript
static func dijkstra(graph: StdGraph, start: Variant, goal: Variant) -> StdResult
```

Returns a path with the lowest total edge weight. Dijkstra works with directed
and undirected graphs. `StdGraph` rejects negative weights, satisfying the
algorithm's weight requirement. Equal-cost paths have no guaranteed tie order.

```gdscript
var result: StdResult = StdGraphAlgorithms.dijkstra(roads, "village", "castle")
```

#### `topological_sort`

```gdscript
static func topological_sort(graph: StdGraph) -> StdResult
```

Returns every vertex in an order where each source appears before the vertices
reached by its outgoing edges. The graph must be directed and acyclic. An
undirected graph or a directed graph containing a cycle returns
`StdResult.err(String)`. An empty directed graph returns `ok([])`.

```gdscript
var tasks: StdGraph = StdGraph.new(true)
tasks.push("prepare")
tasks.push("cook")
tasks.push("eat")
tasks.push_edge("prepare", "cook")
tasks.push_edge("cook", "eat")

var order: StdResult = StdGraphAlgorithms.topological_sort(tasks)
# order.unwrap() == ["prepare", "cook", "eat"]
```

When multiple vertices are currently valid, their relative order is not
guaranteed.

#### `ids`

```gdscript
static func ids(graph: StdGraph, start: Variant, goal: Variant) -> StdResult
```

Uses iterative deepening search: repeated depth-first searches with increasing
depth limits. It returns a path at the shallowest reachable depth while using
depth-first working memory. Edge weights are ignored.

### `StdSorts`

Static only. Never `StdSorts.new()`.

#### `INSERTION_SORT_SIZE`

```gdscript
const INSERTION_SORT_SIZE: int = 20
```

Ranges at or below this size are sorted with insertion sort instead of recursing
further — the standard hybrid, since insertion sort wins on small runs.
`merge_sort` applies this internally; you don't have to think about it.

#### `merge_sort`

```gdscript
static func merge_sort(array: Array, cmp: Callable) -> StdResult
```

Sorts `array` in place with a stable merge sort. Returns `StdResult.ok(array)` on
success or `StdResult.err(String)` if `cmp` is invalid. O(n log n) time, O(n) extra
space. Falls back to insertion sort for ranges of `INSERTION_SORT_SIZE` or fewer.

```gdscript
var scores: Array = [5, 1, 4]
var _rv: StdResult = StdSorts.merge_sort(scores, StdCmp.less_than())     # [1, 4, 5]
var _rv2: StdResult = StdSorts.merge_sort(scores, StdCmp.greater_than())  # [5, 4, 1]
```

#### `insertion_sort`

```gdscript
static func insertion_sort(array: Array, cmp: Callable) -> StdResult
```

Sorts `array` in place with a stable insertion sort and returns
`StdResult.ok(array)`, or `StdResult.err(String)` if `cmp` is invalid. O(n²) in
general, O(n) on already-sorted input.

Worth calling directly only for small arrays, or ones you know are nearly sorted
already — a list that shifts by one element per frame, say. Otherwise use
`merge_sort`, which uses insertion sort for small ranges anyway.

### `StdCmp`

Static only. Ready-made comparison callables, so you don't retype the lambdas.

```gdscript
static func less_than() -> Callable      # a < b   — ascending
static func greater_than() -> Callable   # a > b   — descending
static func equal_to() -> Callable       # a == b
```

```gdscript
var _rv: StdResult = StdSorts.merge_sort(scores, StdCmp.greater_than())
```

`equal_to()` is not a sort comparator — `merge_sort` with it does nothing useful,
since "sorts before" is never true. It's there for the places that want an
equality predicate as a value (`filter`, `is_ok_and`, and friends).

## Gotchas

### Only Dijkstra uses edge weights

Use `dijkstra` when weights represent movement cost, distance, time, or another
quantity that determines the best path. BFS and IDS minimize the number of
edges; DFS only returns its first discovered path.

### A valid topological order may not be unique

Independent vertices can appear in any relative order. Treat every returned
ordering that respects all directed edges as valid rather than relying on one
specific arrangement.

### The comparator is required and must still be alive

An empty `Callable()`, or one whose object has been freed, returns an error
before the array is changed:

```gdscript
var cmp: Callable = enemy.compare_by_threat
enemy.free()
var rv: StdResult = StdSorts.merge_sort(units, cmp)   # Err; units is untouched
```

Prefer a lambda or static method over a comparator bound to a node that can die.
Use `StdCmp.less_than()` when you previously relied on the implicit ascending
fallback.

### Comparator runtime errors cannot become `StdResult.err`

A callable can be valid but still fail when invoked: it might use `<` on an
unordered value, expect the wrong element type, or return something other than a
boolean. GDScript cannot catch those runtime errors, so `StdResult.err` only covers
callable validity. The comparator must handle every value in the array and define
a consistent ordering.

### Merge sort still needs a buffer

`merge_sort` mutates the caller's array directly but allocates one O(n) merge
buffer. `insertion_sort` does not allocate a working array, which is another
reason it can be attractive for small or nearly sorted inputs.

## Testing

```
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd \
    --path . -- addons/std_lib/std-algorithms/tests
```

See [StdTests](StdTests.md) for the runner.

## See also

- [StdReturns](StdReturns.md) — the `StdResult` these return.
- [StdGraph](collections/Graph.md) — the weighted graph used by `StdGraphAlgorithms`.
- [StdCollections](StdCollections.md) — the rest of the collection types.
