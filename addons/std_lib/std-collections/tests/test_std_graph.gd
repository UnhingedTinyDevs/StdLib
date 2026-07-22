extends StdTest
## Headless tests for StdGraph.


func _test_vertex_collection_operations() -> void:
	var graph: StdGraph = StdGraph.new()
	assert_true(graph.is_empty(), "new graph is empty")
	assert_eq(graph.size(), 0, "new graph has no vertices")
	assert_none(graph.peek("missing"), "missing vertex cannot be peeked")
	assert_none(graph.pop("missing"), "missing vertex cannot be popped")

	graph.push("a")
	graph.push("a")
	graph.push("b")
	assert_eq(graph.size(), 2, "duplicate vertices collapse")
	assert_true(graph.has("a"), "pushed vertex is present")
	assert_eq(graph.peek("a").unwrap(), "a", "peek returns the stored vertex")
	assert_eq(graph.pop("a").unwrap(), "a", "pop returns the stored vertex")
	assert_true(not graph.has("a"), "pop removes the vertex")

	var snapshot: Array = graph.to_array()
	snapshot.clear()
	assert_eq(graph.size(), 1, "array conversion returns a snapshot")
	graph.clear()
	assert_true(graph.is_empty(), "clear removes every vertex")
	return


func _test_undirected_edges_are_shared() -> void:
	var graph: StdGraph = StdGraph.new()
	graph.push("a")
	graph.push("b")

	var inserted: StdResult = graph.push_edge("a", "b", 4)
	assert_ok(inserted, "edge insertion succeeds")
	assert_eq(inserted.unwrap(), true, "new edge reports a change")
	assert_eq(graph.edge_size(), 1, "undirected edge is counted once")
	assert_true(graph.has_edge("a", "b"), "forward edge exists")
	assert_true(graph.has_edge("b", "a"), "reverse edge exists")
	assert_eq(graph.peek_edge("b", "a").unwrap(), 4, "reverse lookup returns the weight")
	assert_true(graph.neighbors("a").has("b"), "first vertex lists the second")
	assert_true(graph.neighbors("b").has("a"), "second vertex lists the first")

	var unchanged: StdResult = graph.push_edge("a", "b", 4)
	assert_eq(unchanged.unwrap(), false, "identical edge reports no change")
	assert_eq(graph.edge_size(), 1, "identical edge does not change the count")

	var updated: StdResult = graph.push_edge("b", "a", 7)
	assert_eq(updated.unwrap(), true, "new weight reports a change")
	assert_eq(graph.peek_edge("a", "b").unwrap(), 7, "weight updates in both directions")
	assert_eq(graph.edge_size(), 1, "weight update does not change the count")
	assert_eq(graph.pop_edge("b", "a").unwrap(), 7, "edge pop returns its weight")
	assert_true(not graph.has_edge("a", "b"), "edge pop removes both directions")
	assert_eq(graph.edge_size(), 0, "edge pop updates the count")
	return


func _test_directed_edges_are_independent() -> void:
	var graph: StdGraph = StdGraph.new(true)
	graph.push(1)
	graph.push(2)
	assert_true(graph.is_directed(), "directed constructor is retained")

	var _forward: StdResult = graph.push_edge(1, 2, 3)
	assert_true(graph.has_edge(1, 2), "forward directed edge exists")
	assert_true(not graph.has_edge(2, 1), "reverse directed edge is absent")
	assert_eq(graph.neighbors(1), [2], "neighbors follows outgoing edges")
	assert_eq(graph.neighbors(2), [], "incoming edge is not a neighbor")

	var _reverse: StdResult = graph.push_edge(2, 1, 5)
	assert_eq(graph.edge_size(), 2, "opposite directed edges count separately")
	assert_eq(graph.pop_edge(1, 2).unwrap(), 3, "directed pop returns its weight")
	assert_true(graph.has_edge(2, 1), "directed pop leaves the reverse edge")
	assert_eq(graph.edge_size(), 1, "directed pop removes one edge")
	return


func _test_push_edge_rejects_invalid_inputs() -> void:
	var graph: StdGraph = StdGraph.new()
	graph.push("a")
	graph.push("b")
	assert_err(graph.push_edge("missing", "b"), "missing source is rejected")
	assert_err(graph.push_edge("a", "missing"), "missing destination is rejected")
	assert_err(graph.push_edge("a", "b", -1), "negative weight is rejected")
	assert_eq(graph.edge_size(), 0, "rejected edges do not change the graph")
	assert_none(graph.peek_edge("missing", "b"), "missing edge lookup is none")
	assert_none(graph.pop_edge("missing", "b"), "missing edge pop is none")
	assert_eq(graph.neighbors("missing"), [], "missing vertex has no neighbors")
	return


func _test_pop_vertex_removes_every_incident_directed_edge() -> void:
	var graph: StdGraph = StdGraph.new(true)
	for vertex: String in ["a", "b", "c"]:
		graph.push(vertex)
		pass
	var _a_to_b: StdResult = graph.push_edge("a", "b")
	var _b_to_a: StdResult = graph.push_edge("b", "a")
	var _c_to_b: StdResult = graph.push_edge("c", "b")
	var _b_loop: StdResult = graph.push_edge("b", "b")
	assert_eq(graph.edge_size(), 4, "fixture contains incoming, outgoing, and self edges")

	assert_eq(graph.pop("b").unwrap(), "b", "vertex pop returns the vertex")
	assert_eq(graph.size(), 2, "vertex pop updates vertex count")
	assert_eq(graph.edge_size(), 0, "vertex pop removes every incident edge")
	assert_eq(graph.neighbors("a"), [], "incoming source no longer points to removed vertex")
	assert_eq(graph.neighbors("c"), [], "second source no longer points to removed vertex")
	return


func _test_self_edge_counts_once_and_clear_resets_edges() -> void:
	var graph: StdGraph = StdGraph.new()
	graph.push("loop")
	assert_eq(graph.push_edge("loop", "loop").unwrap(), true, "self-edge can be added")
	assert_eq(graph.edge_size(), 1, "self-edge counts once")
	assert_eq(graph.neighbors("loop"), ["loop"], "self-edge lists its own vertex")
	assert_eq(graph.pop_edge("loop", "loop").unwrap(), 1, "self-edge pop returns default weight")
	assert_eq(graph.edge_size(), 0, "self-edge pop updates the count")

	var _restored: StdResult = graph.push_edge("loop", "loop", 2)
	graph.clear()
	assert_true(graph.is_empty(), "clear removes vertices")
	assert_eq(graph.edge_size(), 0, "clear resets edge count")
	return
