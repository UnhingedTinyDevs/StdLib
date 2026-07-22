class_name StdTestContext
extends RefCounted
## Runtime services and automatically cleaned resources for an [StdTest] suite.


var tree: SceneTree
var logger: StdTestLogger
var print_results: bool
var diagnostics_available: bool

var _nodes: Array[Node] = []
var _monitors: Array[StdTestSignalMonitor] = []
var _case_node_start: int = 0
var _case_monitor_start: int = 0


#region Engine Methods
func _init(
		test_tree: SceneTree,
		test_logger: StdTestLogger,
		should_print_results: bool = true,
		can_evaluate_diagnostics: bool = true,
) -> void:
	tree = test_tree
	logger = test_logger
	print_results = should_print_results
	diagnostics_available = can_evaluate_diagnostics
	return
#endregion Engine Methods


#region Public API
## Marks the beginning of resources owned by one test function.
func begin_case() -> void:
	_case_node_start = _nodes.size()
	_case_monitor_start = _monitors.size()
	return


## Registers a node for automatic cleanup.
func track_node(node: Node) -> void:
	if not _nodes.has(node):
		_nodes.append(node)
	return


## Registers a signal monitor for automatic disconnection.
func track_monitor(monitor: StdTestSignalMonitor) -> void:
	if not _monitors.has(monitor):
		_monitors.append(monitor)
	return


## Cleans resources created since [method begin_case].
func cleanup_case() -> void:
	_cleanup_monitors(_case_monitor_start)
	_cleanup_nodes(_case_node_start)
	return


## Cleans every remaining suite-owned resource.
func cleanup_all() -> void:
	_cleanup_monitors(0)
	_cleanup_nodes(0)
	return
#endregion Public API


#region Private Helpers
func _cleanup_monitors(start: int) -> void:
	for index: int in range(_monitors.size() - 1, start - 1, -1):
		_monitors[index].stop()
		_monitors.remove_at(index)
		pass
	return


func _cleanup_nodes(start: int) -> void:
	for index: int in range(_nodes.size() - 1, start - 1, -1):
		var node: Node = _nodes[index]
		_nodes.remove_at(index)
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		node.free()
		pass
	return
#endregion Private Helpers
