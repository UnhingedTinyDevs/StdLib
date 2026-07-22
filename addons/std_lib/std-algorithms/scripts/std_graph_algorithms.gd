class_name StdGraphAlgorithms
extends RefCounted
## Search and ordering algorithms for [StdGraph].
##
## Searches return [code]StdResult.ok(path)[/code], where [code]path[/code] is an
## [Array] from [param start] through [param goal]. Invalid endpoints and an
## unreachable goal return [code]StdResult.err(String)[/code].


#region Public API
## Searches from [param start] to [param goal] in breadth-first order.
##
## Returns a path with the fewest edges. Edge weights are ignored.
static func bfs(graph: StdGraph, start: Variant, goal: Variant) -> StdResult:
	var validation: StdResult = _validate_search(graph, start, goal)
	if validation.is_err():
		return validation
	if start == goal:
		return StdResult.ok([start])

	var frontier: Array = [start]
	var head: int = 0
	var visited: Dictionary = {start: true}
	var previous: Dictionary = {}
	while head < frontier.size():
		var current: Variant = frontier[head]
		head += 1
		for neighbor: Variant in graph.neighbors(current):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			previous[neighbor] = current
			if neighbor == goal:
				return StdResult.ok(_reconstruct_path(previous, start, goal))
			frontier.push_back(neighbor)
			pass
		pass
	return StdResult.err("goal is unreachable from start")


## Searches from [param start] to [param goal] in depth-first order.
##
## Returns the first path found. The returned path is not guaranteed to have
## the fewest edges or the lowest weight.
static func dfs(graph: StdGraph, start: Variant, goal: Variant) -> StdResult:
	var validation: StdResult = _validate_search(graph, start, goal)
	if validation.is_err():
		return validation

	var path: Array = []
	var on_path: Dictionary = {}
	if _depth_limited_search(graph, start, goal, graph.size() - 1, path, on_path):
		return StdResult.ok(path)
	return StdResult.err("goal is unreachable from start")


## Finds the lowest-weight path from [param start] to [param goal] using
## Dijkstra's algorithm.
##
## Returns the path as an [Array]. [StdGraph] guarantees nonnegative integer
## edge weights, which are required by this algorithm.
static func dijkstra(graph: StdGraph, start: Variant, goal: Variant) -> StdResult:
	var validation: StdResult = _validate_search(graph, start, goal)
	if validation.is_err():
		return validation
	if start == goal:
		return StdResult.ok([start])

	var distances: Dictionary = {start: 0}
	var previous: Dictionary = {}
	var frontier: StdHeap = StdHeap.new(StdHeap.Order.MIN)
	frontier.push({"vertex": start, "distance": 0}, 0)
	while not frontier.is_empty():
		var entry: Dictionary = frontier.pop().unwrap()
		var current: Variant = entry.vertex
		var distance: int = entry.distance
		if distance != distances[current]:
			continue
		if current == goal:
			return StdResult.ok(_reconstruct_path(previous, start, goal))

		for neighbor: Variant in graph.neighbors(current):
			var weight: int = graph.peek_edge(current, neighbor).unwrap()
			var candidate: int = distance + weight
			if distances.has(neighbor) and candidate >= distances[neighbor]:
				continue
			distances[neighbor] = candidate
			previous[neighbor] = current
			frontier.push({"vertex": neighbor, "distance": candidate}, candidate)
			pass
		pass
	return StdResult.err("goal is unreachable from start")


## Returns a topological ordering of every vertex in [param graph].
##
## The graph must be directed and acyclic. Undirected graphs and directed
## graphs containing a cycle return [code]StdResult.err(String)[/code].
static func topological_sort(graph: StdGraph) -> StdResult:
	if graph == null:
		return StdResult.err("graph is null")
	if not graph.is_directed():
		return StdResult.err("topological sort requires a directed graph")

	var vertices: Array = graph.to_array()
	var in_degree: Dictionary = {}
	for vertex: Variant in vertices:
		in_degree[vertex] = 0
		pass
	for vertex: Variant in vertices:
		for neighbor: Variant in graph.neighbors(vertex):
			in_degree[neighbor] += 1
			pass
		pass

	var frontier: Array = []
	var head: int = 0
	for vertex: Variant in vertices:
		if in_degree[vertex] == 0:
			frontier.push_back(vertex)
			pass
		pass

	var ordering: Array = []
	while head < frontier.size():
		var current: Variant = frontier[head]
		head += 1
		ordering.push_back(current)
		for neighbor: Variant in graph.neighbors(current):
			in_degree[neighbor] -= 1
			if in_degree[neighbor] == 0:
				frontier.push_back(neighbor)
				pass
			pass
		pass
	if ordering.size() != graph.size():
		return StdResult.err("graph contains a cycle")
	return StdResult.ok(ordering)


## Searches from [param start] to [param goal] using iterative deepening search.
##
## Repeats a depth-limited depth-first search with increasing limits and
## returns the first path found at the shallowest depth.
static func ids(graph: StdGraph, start: Variant, goal: Variant) -> StdResult:
	var validation: StdResult = _validate_search(graph, start, goal)
	if validation.is_err():
		return validation

	for depth: int in range(graph.size()):
		var path: Array = []
		var on_path: Dictionary = {}
		if _depth_limited_search(graph, start, goal, depth, path, on_path):
			return StdResult.ok(path)
		pass
	return StdResult.err("goal is unreachable from start")
#endregion Public API


#region Private Helpers
## Validates the graph and endpoints shared by [method bfs], [method dfs],
## [method dijkstra], and [method ids] before a search allocates working state.
static func _validate_search(graph: StdGraph, start: Variant, goal: Variant) -> StdResult:
	if graph == null:
		return StdResult.err("graph is null")
	if not graph.has(start):
		return StdResult.err("start vertex is missing")
	if not graph.has(goal):
		return StdResult.err("goal vertex is missing")
	return StdResult.ok(true)


## Rebuilds the start-to-goal path recorded by breadth-first and Dijkstra
## searches, which store only each discovered vertex's predecessor.
static func _reconstruct_path(
	previous: Dictionary,
	start: Variant,
	goal: Variant,
) -> Array:
	var path: Array = [goal]
	var current: Variant = goal
	while current != start:
		current = previous[current]
		path.push_back(current)
		pass
	path.reverse()
	return path


## Performs the bounded depth-first step needed once by [method dfs] and at
## each increasing depth used by [method ids]. [param on_path] prevents cycles
## without excluding a vertex from a later branch reached at a shallower depth.
static func _depth_limited_search(
	graph: StdGraph,
	current: Variant,
	goal: Variant,
	remaining_depth: int,
	path: Array,
	on_path: Dictionary,
) -> bool:
	path.push_back(current)
	on_path[current] = true
	if current == goal:
		return true

	if remaining_depth > 0:
		for neighbor: Variant in graph.neighbors(current):
			if on_path.has(neighbor):
				continue
			if _depth_limited_search(
				graph,
				neighbor,
				goal,
				remaining_depth - 1,
				path,
				on_path,
			):
				return true
			pass

	on_path.erase(current)
	path.pop_back()
	return false
#endregion Private Helpers
