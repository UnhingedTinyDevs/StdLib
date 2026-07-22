# StdGraph

[← StdCollections](../StdCollections.md)

**Inherits:** `RefCounted`

A weighted directed or undirected graph with unique vertices.

## Description

`StdGraph` stores unique vertices and nonnegative integer edge weights. Vertices use Godot `Dictionary` key
equality and must remain valid, stable keys while they belong to the graph.

Graphs are undirected by default. An undirected edge is available in both vertex orders but counts as one logical
edge. Directed graphs store each direction independently. Self-edges are supported in either mode and count once.

Removing a vertex also removes every incoming and outgoing edge connected to it.

## Example usage

```gdscript
var map: StdGraph = StdGraph.new()
map.push("village")
map.push("forest")
map.push("castle")

map.push_edge("village", "forest", 3)
map.push_edge("forest", "castle", 7)

map.peek_edge("forest", "village") # some(3)
map.neighbors("forest")             # ["village", "castle"], in unspecified order
map.edge_size()                     # 2
```

## Signals

This class defines no signals.

## Enumerations

This class defines no enumerations.

## Properties

This class exposes no public properties. Vertex order and neighbor order are not guaranteed.

## Methods

| Return type | Method |
|---|---|
| `StdGraph` | `StdGraph(directed: bool = false)` |
| `void` | `push(vertex: Variant)` |
| `StdOption` | `pop(vertex: Variant)` |
| `StdOption` | `peek(vertex: Variant)` |
| `bool` | `has(vertex: Variant)` |
| `int` | `size()` |
| `bool` | `is_empty()` |
| `void` | `clear()` |
| `Array` | `to_array()` |
| `StdResult` | `push_edge(from_vertex: Variant, to_vertex: Variant, weight: int = 1)` |
| `StdOption` | `pop_edge(from_vertex: Variant, to_vertex: Variant)` |
| `StdOption` | `peek_edge(from_vertex: Variant, to_vertex: Variant)` |
| `bool` | `has_edge(from_vertex: Variant, to_vertex: Variant)` |
| `int` | `edge_size()` |
| `Array` | `neighbors(vertex: Variant)` |
| `bool` | `is_directed()` |

## Method descriptions

### `StdGraph(directed: bool = false)`

Creates an empty graph. The default is undirected; pass `true` to create a directed graph.

### `push(vertex: Variant) -> void`

Adds `vertex` when it is absent. Pushing an existing vertex does nothing.

### `pop(vertex: Variant) -> StdOption`

Removes and returns the stored vertex, or `none` when absent. Every incoming, outgoing, and self-edge connected
to the vertex is also removed.

### `peek(vertex: Variant) -> StdOption`

Returns the stored vertex equal to `vertex` without removing it, or `none` when absent.

### `has(vertex: Variant) -> bool`

Returns whether the graph contains `vertex`. Average complexity is O(1).

### `size() -> int`, `is_empty() -> bool`

Return the vertex count and whether the graph contains no vertices.

### `clear() -> void`

Removes every vertex and edge while retaining whether the graph is directed.

### `to_array() -> Array`

Returns an independent snapshot of the stored vertices. Order is not guaranteed.

### `push_edge(from_vertex: Variant, to_vertex: Variant, weight: int = 1) -> StdResult`

Adds an edge or replaces an existing edge's weight. Both vertices must already be present, and `weight` must be
nonnegative. Self-edges are allowed.

Returns `ok(true)` when an edge is added or its weight changes, `ok(false)` when the same edge already has the
same weight, and `err` for a missing vertex or negative weight. In an undirected graph, the weight is updated for
both vertex orders while the logical edge count remains one.

### `pop_edge(from_vertex: Variant, to_vertex: Variant) -> StdOption`

Removes an edge and returns its weight, or `none` when absent. In an undirected graph, either vertex order removes
both adjacency entries.

### `peek_edge(from_vertex: Variant, to_vertex: Variant) -> StdOption`

Returns an edge's weight without removing it, or `none` when absent. For directed graphs, vertex order specifies
the edge direction.

### `has_edge(from_vertex: Variant, to_vertex: Variant) -> bool`

Returns whether the edge exists. For directed graphs, this tests only the specified direction.

### `edge_size() -> int`

Returns the logical edge count. Opposite directed edges count separately; an undirected edge and a self-edge each
count once.

### `neighbors(vertex: Variant) -> Array`

Returns an independent snapshot of vertices reachable by one outgoing edge. In an undirected graph, these are all
adjacent vertices. A missing or isolated vertex returns an empty array. Order is not guaranteed.

### `is_directed() -> bool`

Returns whether edges have a direction.

## Implementation notes

Vertices and adjacency lists are backed by dictionaries, giving average O(1) vertex and edge lookup. Undirected
edges use mirrored adjacency entries internally, but `edge_size()` counts the pair as one logical edge.

## Testing

```sh
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-collections/tests/test_std_graph.gd
```
