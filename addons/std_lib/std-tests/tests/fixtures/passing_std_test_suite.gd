extends StdTest
## Passing fixture that exercises the complete StdTest authoring API.


signal measured(label: String, amount: int)

var events: Array[String] = []
var shared_node_id: int = 0
var test_node_id: int = 0

var _shared_node: Node


#region Lifecycle Hooks
func _before_all() -> void:
	events.append("before_all")
	_shared_node = add_to_tree(Node.new())
	shared_node_id = _shared_node.get_instance_id()
	assert_true(_shared_node.is_inside_tree(), "before_all node enters the tree")
	return


func _before_each() -> void:
	events.append("before_each")
	return


func _after_each() -> void:
	events.append("after_each")
	return


func _after_all() -> void:
	events.append("after_all")
	assert_true(_shared_node.is_inside_tree(), "before_all node survives every test")
	return
#endregion Lifecycle Hooks


#region Tests
func _test_assertions_and_signals() -> void:
	assert_true(true, "true")
	assert_false(false, "false")
	assert_eq([1, 2], [1, 2], "equal")
	assert_ne(1, 2, "not equal")
	assert_lt(1, 2, "less than")
	assert_lte(2, 2, "less than or equal")
	assert_gt(2, 1, "greater than")
	assert_gte(2, 2, "greater than or equal")
	assert_approx_eq(0.1 + 0.2, 0.3, 0.000001, "approximately equal")
	assert_null(null, "null")
	assert_not_null(self, "not null")
	assert_some(StdOption.some(1), "some")
	assert_none(StdOption.none(), "none")
	assert_ok(StdResult.ok(1), "ok")
	assert_err(StdResult.err("failure"), "err")
	assert_empty([], "empty")
	assert_not_empty([1], "not empty")
	assert_has([1, 2], 2, "has")
	assert_not_has([1, 2], 3, "does not have")

	var monitor: StdTestSignalMonitor = monitor_signal(measured)
	measured.emit("health", 42)
	assert_emitted(monitor, "signal emitted")
	assert_emitted_count(monitor, 1, "signal emitted once")
	assert_emitted_with(monitor, ["health", 42], "signal arguments retained")
	return


func _test_tree_and_frame_helpers() -> void:
	var node: Node = add_to_tree(Node.new())
	test_node_id = node.get_instance_id()
	assert_true(node.is_inside_tree(), "test node enters tree")
	await process_wait()
	await physics_wait()
	remove_from_tree(node)
	assert_false(node.is_inside_tree(), "remove_from_tree detaches node")
	return
#endregion Tests
