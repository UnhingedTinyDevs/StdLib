extends StdTest
## Headless tests for StdGraphAlgorithms.


func _test_bfs_returns_fewest_edge_path() -> void:
	var graph: StdGraph = StdGraph.new(true)
	for vertex: String in ["start", "long_a", "long_b", "short", "goal"]:
		graph.push(vertex)
		pass
	var _edge_1: StdResult = graph.push_edge("start", "long_a")
	var _edge_2: StdResult = graph.push_edge("long_a", "long_b")
	var _edge_3: StdResult = graph.push_edge("long_b", "goal")
	var _edge_4: StdResult = graph.push_edge("start", "short")
	var _edge_5: StdResult = graph.push_edge("short", "goal")

	var result: StdResult = StdGraphAlgorithms.bfs(graph, "start", "goal")
	assert_ok(result, "bfs finds the goal")
	assert_eq(result.unwrap(), ["start", "short", "goal"], "bfs returns the fewest-edge path")
	return


func _test_dfs_returns_a_depth_first_path() -> void:
	var graph: StdGraph = StdGraph.new(true)
	for vertex: String in ["start", "a", "b", "goal"]:
		graph.push(vertex)
		pass
	var _edge_1: StdResult = graph.push_edge("start", "a")
	var _edge_2: StdResult = graph.push_edge("a", "b")
	var _edge_3: StdResult = graph.push_edge("b", "goal")

	var result: StdResult = StdGraphAlgorithms.dfs(graph, "start", "goal")
	assert_ok(result, "dfs finds the goal")
	assert_eq(result.unwrap(), ["start", "a", "b", "goal"], "dfs returns its discovered path")
	return


func _test_dijkstra_returns_lowest_weight_path() -> void:
	var graph: StdGraph = StdGraph.new(true)
	for vertex: String in ["start", "a", "b", "goal"]:
		graph.push(vertex)
		pass
	var _direct: StdResult = graph.push_edge("start", "goal", 10)
	var _edge_1: StdResult = graph.push_edge("start", "a", 2)
	var _edge_2: StdResult = graph.push_edge("a", "b", 2)
	var _edge_3: StdResult = graph.push_edge("b", "goal", 2)

	var result: StdResult = StdGraphAlgorithms.dijkstra(graph, "start", "goal")
	assert_ok(result, "dijkstra finds the goal")
	assert_eq(result.unwrap(), ["start", "a", "b", "goal"], "dijkstra returns the cheapest path")
	return


func _test_topological_sort_orders_dependencies() -> void:
	var graph: StdGraph = StdGraph.new(true)
	for vertex: String in ["prepare", "cook", "eat"]:
		graph.push(vertex)
		pass
	var _prepare_cook: StdResult = graph.push_edge("prepare", "cook")
	var _cook_eat: StdResult = graph.push_edge("cook", "eat")

	var result: StdResult = StdGraphAlgorithms.topological_sort(graph)
	assert_ok(result, "directed acyclic graph can be ordered")
	assert_eq(result.unwrap(), ["prepare", "cook", "eat"], "dependencies precede their consumers")

	var cyclic: StdGraph = StdGraph.new(true)
	cyclic.push("a")
	cyclic.push("b")
	var _a_b: StdResult = cyclic.push_edge("a", "b")
	var _b_a: StdResult = cyclic.push_edge("b", "a")
	assert_err(StdGraphAlgorithms.topological_sort(cyclic), "a directed cycle is rejected")
	assert_err(StdGraphAlgorithms.topological_sort(StdGraph.new()), "an undirected graph is rejected")
	return


func _test_ids_returns_a_shallowest_path() -> void:
	var graph: StdGraph = StdGraph.new(true)
	for vertex: String in ["start", "deep_a", "deep_b", "shallow", "goal"]:
		graph.push(vertex)
		pass
	var _deep_1: StdResult = graph.push_edge("start", "deep_a")
	var _deep_2: StdResult = graph.push_edge("deep_a", "deep_b")
	var _deep_3: StdResult = graph.push_edge("deep_b", "goal")
	var _shallow_1: StdResult = graph.push_edge("start", "shallow")
	var _shallow_2: StdResult = graph.push_edge("shallow", "goal")

	var result: StdResult = StdGraphAlgorithms.ids(graph, "start", "goal")
	assert_ok(result, "ids finds the goal")
	assert_eq(result.unwrap(), ["start", "shallow", "goal"], "ids returns a shallowest path")
	return


func _test_searches_reject_missing_and_unreachable_goals() -> void:
	var graph: StdGraph = StdGraph.new(true)
	graph.push("start")
	graph.push("goal")

	assert_err(StdGraphAlgorithms.bfs(graph, "start", "missing"), "bfs rejects a missing goal")
	assert_err(StdGraphAlgorithms.dfs(graph, "start", "goal"), "dfs rejects an unreachable goal")
	assert_err(StdGraphAlgorithms.dijkstra(graph, "start", "goal"), "dijkstra rejects an unreachable goal")
	assert_err(StdGraphAlgorithms.ids(graph, "start", "goal"), "ids rejects an unreachable goal")
	return
