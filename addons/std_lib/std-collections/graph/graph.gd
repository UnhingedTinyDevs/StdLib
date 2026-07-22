class_name StdGraph
extends RefCounted
## A weighted graph collection.
##
## Vertices are unique values that must be valid, stable [Dictionary] keys.
## Edges have nonnegative integer weights. A graph may be directed or
## undirected; undirected graphs count an edge once even though it joins two
## vertices.


var _vertices: Dictionary = {}
var _adjacency: Dictionary = {}
var _directed: bool
var _edge_count: int = 0


## Creates an empty graph. When [param directed] is [code]false[/code], edges
## are undirected. The default is an undirected graph.
func _init(directed: bool = false) -> void:
	_directed = directed
	return


#region Vertex API
## Adds [param vertex] when it is not already present. Pushing an existing
## vertex does nothing.
func push(vertex: Variant) -> void:
	if _vertices.has(vertex):
		return
	_vertices[vertex] = vertex
	_adjacency[vertex] = {}
	return


## Removes [param vertex] and every edge connected to it. Returns the stored
## vertex, or [code]none[/code] when the graph does not contain it.
func pop(vertex: Variant) -> StdOption:
	if not _vertices.has(vertex):
		return StdOption.none()

	var stored: Variant = _vertices[vertex]
	_remove_incident_edges(vertex)
	_adjacency.erase(vertex)
	_vertices.erase(vertex)
	return StdOption.some(stored)


## Returns the stored vertex equal to [param vertex], or [code]none[/code] when
## the graph does not contain it.
func peek(vertex: Variant) -> StdOption:
	if not _vertices.has(vertex):
		return StdOption.none()
	return StdOption.some(_vertices[vertex])


## Returns [code]true[/code] when the graph contains [param vertex].
func has(vertex: Variant) -> bool:
	return _vertices.has(vertex)


## Returns the number of vertices in the graph.
func size() -> int:
	return _vertices.size()


## Returns [code]true[/code] when the graph contains no vertices.
func is_empty() -> bool:
	return _vertices.is_empty()


## Removes every vertex and edge from the graph.
func clear() -> void:
	_vertices.clear()
	_adjacency.clear()
	_edge_count = 0
	return


## Returns the stored vertices as an [Array]. Vertex order is not guaranteed.
func to_array() -> Array:
	return _vertices.values()
#endregion Vertex API


#region Edge API
## Adds an edge from [param from_vertex] to [param to_vertex] with [param weight],
## or replaces the weight of an existing edge. Self-edges are allowed.
##
## Returns [code]ok(true)[/code] when an edge is added or its weight changes,
## [code]ok(false)[/code] when the same edge already has the same weight, and an
## error when either vertex is missing or [param weight] is negative.
func push_edge(
	from_vertex: Variant,
	to_vertex: Variant,
	weight: int = 1,
) -> StdResult:
	if not has(from_vertex):
		return StdResult.err("from vertex is missing")
	if not has(to_vertex):
		return StdResult.err("to vertex is missing")
	if weight < 0:
		return StdResult.err("edge weight cannot be negative")

	var exists: bool = has_edge(from_vertex, to_vertex)
	var changed: bool = _set_edge(from_vertex, to_vertex, weight)
	if not _directed and from_vertex != to_vertex:
		changed = _set_edge(to_vertex, from_vertex, weight) or changed
	if not exists:
		_edge_count += 1
	return StdResult.ok(changed)


## Removes the edge from [param from_vertex] to [param to_vertex]. In an
## undirected graph, the order of the two vertices does not matter. Returns the
## removed weight, or [code]none[/code] when the edge does not exist.
func pop_edge(from_vertex: Variant, to_vertex: Variant) -> StdOption:
	var removed: StdOption = _erase_edge(from_vertex, to_vertex)
	if removed.is_none():
		return removed
	if not _directed and from_vertex != to_vertex:
		var _mirror: StdOption = _erase_edge(to_vertex, from_vertex)
	_edge_count -= 1
	return removed


## Returns the weight of the edge from [param from_vertex] to [param to_vertex],
## or [code]none[/code] when the edge does not exist. In an undirected graph,
## the order of the two vertices does not matter.
func peek_edge(from_vertex: Variant, to_vertex: Variant) -> StdOption:
	if not _adjacency.has(from_vertex):
		return StdOption.none()
	var edges: Dictionary = _adjacency[from_vertex]
	if not edges.has(to_vertex):
		return StdOption.none()
	return StdOption.some(edges[to_vertex])


## Returns [code]true[/code] when an edge exists from [param from_vertex] to
## [param to_vertex]. In an undirected graph, either vertex order matches.
func has_edge(from_vertex: Variant, to_vertex: Variant) -> bool:
	if not _adjacency.has(from_vertex):
		return false
	var edges: Dictionary = _adjacency[from_vertex]
	return edges.has(to_vertex)


## Returns the number of logical edges in the graph. Each undirected edge is
## counted once, including a self-edge.
func edge_size() -> int:
	return _edge_count


## Returns the vertices reachable by one outgoing edge from [param vertex]. For
## an undirected graph, this returns every adjacent vertex. Returns an empty
## [Array] when [param vertex] is missing or has no neighbors. Order is not
## guaranteed.
func neighbors(vertex: Variant) -> Array:
	if not _adjacency.has(vertex):
		return []
	var edges: Dictionary = _adjacency[vertex]
	var adjacent: Array = []
	for neighbor: Variant in edges:
		adjacent.push_back(_vertices[neighbor])
		pass
	return adjacent
#endregion Edge API


#region Graph API
## Returns [code]true[/code] when edges have a direction.
func is_directed() -> bool:
	return _directed
#endregion Graph API


#region Private Helpers
## Stores one adjacency entry from [param from_vertex] to [param to_vertex].
## Returns [code]true[/code] when the entry is added or its weight changes, and
## [code]false[/code] when the stored weight already equals [param weight]. This
## helper does not mirror an undirected edge or update the logical edge count.
func _set_edge(
	from_vertex: Variant,
	to_vertex: Variant,
	weight: int,
) -> bool:
	var edges: Dictionary = _adjacency[from_vertex]
	if edges.has(to_vertex) and edges[to_vertex] == weight:
		return false
	edges[to_vertex] = weight
	return true


## Removes one adjacency entry from [param from_vertex] to [param to_vertex].
## Returns the removed weight, or [code]none[/code] when no entry exists. This
## helper does not remove the mirrored entry of an undirected edge or update the
## logical edge count.
func _erase_edge(from_vertex: Variant, to_vertex: Variant) -> StdOption:
	if not _adjacency.has(from_vertex):
		return StdOption.none()
	var edges: Dictionary = _adjacency[from_vertex]
	if not edges.has(to_vertex):
		return StdOption.none()
	var weight: int = edges[to_vertex]
	edges.erase(to_vertex)
	return StdOption.some(weight)


## Removes every incoming and outgoing adjacency entry for [param vertex] and
## updates the logical edge count. Undirected mirrored entries and self-edges
## are counted correctly.
func _remove_incident_edges(vertex: Variant) -> void:
	var outgoing: Array = (_adjacency[vertex] as Dictionary).keys()
	for to_vertex: Variant in outgoing:
		var _removed_outgoing: StdOption = pop_edge(vertex, to_vertex)
		pass

	if not _directed:
		return
	for from_vertex: Variant in _adjacency:
		if from_vertex == vertex:
			continue
		var edges: Dictionary = _adjacency[from_vertex]
		if edges.has(vertex):
			var _removed_incoming: StdOption = pop_edge(from_vertex, vertex)
		pass
	return
#endregion Private Helpers
