extends StdTest
## Headless tests for StdRedBlackTree.


class OrderedValue extends RefCounted:
	var key: int
	var label: String

	func _init(value_key: int, value_label: String) -> void:
		key = value_key
		label = value_label
		return


func _compare_int(first: Variant, second: Variant) -> int:
	return int(first) - int(second)


func _compare_ordered_value(first: Variant, second: Variant) -> int:
	return (first as OrderedValue).key - (second as OrderedValue).key


func _check_valid(tree: StdRedBlackTree, name: String) -> void:
	assert_ok(_validate(tree), name)
	return


func _validate(tree: StdRedBlackTree) -> StdResult:
	var nil: StdRedBlackTreeNode = tree._nodes.get(StdRedBlackTree.NIL)
	if nil.color != StdRedBlackTreeNode.NodeColor.BLACK:
		return StdResult.err("NIL is not black")
	if nil.left != StdRedBlackTree.NIL or nil.right != StdRedBlackTree.NIL:
		return StdResult.err("NIL children do not point to NIL")
	if tree._size == 0:
		return StdResult.ok(true) if tree._root == StdRedBlackTree.NIL \
				else StdResult.err("empty tree has a root")
	if tree._root == StdRedBlackTree.NIL:
		return StdResult.err("non-empty tree has no root")
	if tree._nodes.get(tree._root).parent != StdRedBlackTree.NIL:
		return StdResult.err("root has a parent")
	if tree._nodes.get(tree._root).color != StdRedBlackTreeNode.NodeColor.BLACK:
		return StdResult.err("root is not black")

	var visited: Dictionary = {}
	var height: StdResult = _black_height(tree, tree._root, StdRedBlackTree.NIL, visited)
	if height.is_err():
		return height
	var occurrences: int = 0
	for value: Variant in visited:
		occurrences += tree._nodes.get(int(value)).count
		pass
	if occurrences != tree._size:
		return StdResult.err("reachable occurrence count does not match size")
	if tree._nodes.size() != visited.size() + tree._free.size() + 1:
		return StdResult.err("array storage count does not match size")
	return StdResult.ok(true)


func _black_height(
	tree: StdRedBlackTree,
	index: int,
	parent: int,
	visited: Dictionary,
) -> StdResult:
	if index == StdRedBlackTree.NIL:
		return StdResult.ok(1)
	if visited.has(index):
		return StdResult.err("tree contains a cycle")
	if tree._nodes.get(index) == null:
		return StdResult.err("tree links to an empty array slot")
	visited[index] = true
	var node: StdRedBlackTreeNode = tree._nodes.get(index)
	if node.count < 1:
		return StdResult.err("reachable node has no occurrences")
	if node.parent != parent:
		return StdResult.err("parent and child links disagree")
	if node.color == StdRedBlackTreeNode.NodeColor.RED:
		if tree._nodes.get(node.left).color == StdRedBlackTreeNode.NodeColor.RED \
				or tree._nodes.get(node.right).color == StdRedBlackTreeNode.NodeColor.RED:
			return StdResult.err("red node has a red child")

	var left: StdResult = _black_height(tree, node.left, index, visited)
	if left.is_err():
		return left
	var right: StdResult = _black_height(tree, node.right, index, visited)
	if right.is_err():
		return right
	if int(left.unwrap()) != int(right.unwrap()):
		return StdResult.err("subtree black heights differ")
	return StdResult.ok(
		int(left.unwrap()) + (1 if node.color == StdRedBlackTreeNode.NodeColor.BLACK else 0)
	)


func _test_empty_push_peek_pop_and_clear() -> void:
	var tree: StdRedBlackTree = StdRedBlackTree.new(_compare_int)
	var interface: IStdTreeCollection = tree
	assert_true(interface == tree, "red-black tree implements the tree interface")
	assert_true(tree.is_empty(), "new tree is empty")
	assert_eq(tree.size(), 0, "new tree has size zero")
	assert_true(tree.peek(4).is_none(), "empty peek is none")
	assert_true(tree.pop(4).is_none(), "empty pop is none")

	tree.push(3)
	tree.push(1)
	tree.push(2)
	assert_eq(tree.peek(1).unwrap(), 1, "peek finds the requested value")
	assert_eq(tree.pop(1).unwrap(), 1, "pop removes the requested value")
	assert_eq(tree.to_array(), [2, 3], "remaining values stay ordered")
	tree.clear()
	assert_true(tree.is_empty(), "clear empties tree")
	_check_valid(tree, "cleared tree remains valid")
	return


func _test_comparator_controls_snapshot_order() -> void:
	var ascending: StdRedBlackTree = StdRedBlackTree.from_array(
		[4, 1, 3, 2, 5],
		_compare_int,
	)
	var descending: StdRedBlackTree = StdRedBlackTree.from_array(
		[4, 1, 3, 2, 5],
		func(first: Variant, second: Variant) -> int: return int(second) - int(first),
	)
	assert_eq(ascending.to_array(), [1, 2, 3, 4, 5], "ascending comparator orders snapshot")
	assert_eq(descending.to_array(), [5, 4, 3, 2, 1], "descending comparator orders snapshot")
	assert_eq(descending.peek(5).unwrap(), 5, "targeted peek is independent of snapshot direction")
	assert_eq(descending.pop(5).unwrap(), 5, "targeted pop is independent of snapshot direction")
	_check_valid(ascending, "ascending tree invariants")
	_check_valid(descending, "descending tree invariants")
	return


func _test_duplicates_are_stable() -> void:
	var first: OrderedValue = OrderedValue.new(5, "first")
	var second: OrderedValue = OrderedValue.new(5, "second")
	var third: OrderedValue = OrderedValue.new(5, "third")
	var lower: OrderedValue = OrderedValue.new(1, "lower")
	var tree: StdRedBlackTree = StdRedBlackTree.new(_compare_ordered_value)
	tree.push(first)
	tree.push(lower)
	tree.push(second)
	tree.push(third)

	assert_eq(tree.size(), 4, "duplicates count toward size")
	assert_eq(tree._nodes.size(), 3, "duplicates share one physical node")
	var query: OrderedValue = OrderedValue.new(5, "query")
	var duplicate_index: int = tree._find(query)
	assert_eq(tree._nodes.get(duplicate_index).count, 3, "duplicate node counts all occurrences")
	assert_eq(tree.peek(query).unwrap(), first, "peek returns the first stored representative")
	assert_eq(tree.pop(query).unwrap(), first, "first pop decrements the shared node")
	assert_eq(tree.peek(query).unwrap(), first, "representative remains while occurrences remain")
	assert_eq(tree.pop(query).unwrap(), first, "second pop decrements the shared node")
	assert_eq(tree.pop(query).unwrap(), first, "final pop removes the shared node")
	assert_true(not tree.has(query), "duplicate node is absent after its final occurrence")
	assert_eq(tree.pop(lower).unwrap(), lower, "other comparator keys remain independent")
	_check_valid(tree, "tree remains valid after duplicate pops")
	return


func _test_targeted_lookup_and_removal() -> void:
	var first: OrderedValue = OrderedValue.new(2, "stored")
	var duplicate: OrderedValue = OrderedValue.new(2, "duplicate")
	var query: OrderedValue = OrderedValue.new(2, "query")
	var tree: StdRedBlackTree = StdRedBlackTree.new(_compare_ordered_value)
	tree.push(OrderedValue.new(1, "one"))
	tree.push(first)
	tree.push(duplicate)
	tree.push(OrderedValue.new(3, "three"))

	assert_true(tree.has(query), "has uses comparator equality")
	assert_eq(tree.peek(query).unwrap(), first, "peek returns stored instance")
	assert_eq(tree.pop(query).unwrap(), first, "pop removes one comparator-equal occurrence")
	assert_eq(tree.peek(query).unwrap(), first, "stored representative remains")
	assert_eq(tree.pop(query).unwrap(), first, "final pop removes comparator key")
	assert_true(tree.pop(OrderedValue.new(9, "missing")).is_none(), "missing item pop is none")
	_check_valid(tree, "targeted removal preserves invariants")
	return


func _test_map_filter_and_array_conversion() -> void:
	var source: StdRedBlackTree = StdRedBlackTree.from_array([4, 1, 4, 2], _compare_int)
	var map_result: StdResult = source.map(func(value: Variant) -> int: return int(value) * 10)
	var filter_result: StdResult = source.filter(func(value: Variant) -> bool: return int(value) % 2 == 0)
	assert_ok(map_result, "map succeeds")
	assert_ok(filter_result, "filter succeeds")
	var mapped: StdRedBlackTree = map_result.unwrap() as StdRedBlackTree
	var filtered: StdRedBlackTree = filter_result.unwrap() as StdRedBlackTree
	assert_eq(mapped.to_array(), [10, 20, 40, 40], "map preserves duplicate occurrences")
	assert_eq(filtered.to_array(), [2, 4, 4], "filter preserves duplicate occurrences")
	assert_eq(source.to_array(), [1, 2, 4, 4], "snapshot repeats shared-node occurrences")
	assert_err(source.map(Callable()), "invalid mapper errors")
	assert_err(source.filter(Callable()), "invalid predicate errors")
	_check_valid(mapped, "mapped tree invariants")
	_check_valid(filtered, "filtered tree invariants")
	return


func _test_signals_report_public_changes() -> void:
	var tree: StdRedBlackTree = StdRedBlackTree.new(_compare_int)
	var pushed_values: Array = []
	var popped_values: Array = []
	var sizes: Array[int] = []
	var clear_events: Array[bool] = []
	tree.pushed.connect(func(value: Variant) -> void: pushed_values.push_back(value))
	tree.popped.connect(func(value: Variant) -> void: popped_values.push_back(value))
	tree.size_changed.connect(func(value: int) -> void: sizes.push_back(value))
	tree.cleared.connect(func() -> void: clear_events.push_back(true))

	tree.push(2)
	tree.push(1)
	var _first: StdOption = tree.pop(2)
	var _second: StdOption = tree.pop(1)
	tree.clear()
	assert_eq(pushed_values, [2, 1], "push emits its item")
	assert_eq(popped_values, [2, 1], "pop emits the removed item")
	assert_eq(sizes, [1, 2, 1, 0, 0], "size signal follows public changes")
	assert_eq(clear_events, [true], "clear emits inherited signal")
	return


func _test_insertion_and_deletion_shapes_preserve_invariants() -> void:
	var patterns: Array = [
		[1, 2, 3, 4, 5, 6, 7, 8, 9],
		[9, 8, 7, 6, 5, 4, 3, 2, 1],
		[5, 2, 8, 1, 4, 7, 9, 3, 6],
	]
	for pattern: Array in patterns:
		var tree: StdRedBlackTree = StdRedBlackTree.new(_compare_int)
		for value: int in pattern:
			tree.push(value)
			_check_valid(tree, "insertion repair preserves invariants")
			pass
		for value: int in [5, 1, 9, 4, 6, 2, 8, 3, 7]:
			var _removed: StdOption = tree.pop(value)
			_check_valid(tree, "deletion repair preserves invariants")
			pass
		assert_true(tree.is_empty(), "deletion pattern empties tree")
		pass
	return


func _test_removed_slots_are_reused() -> void:
	var tree: StdRedBlackTree = StdRedBlackTree.new(_compare_int)
	for value: int in range(32):
		tree.push(value)
		pass
	var allocated_slots: int = tree._nodes.size()
	for value: int in range(16):
		var _removed: StdOption = tree.pop(value)
		pass
	for value: int in range(32, 48):
		tree.push(value)
		pass
	assert_eq(tree._nodes.size(), allocated_slots, "push reuses removed array slots")
	_check_valid(tree, "reused slots preserve invariants")
	return


func _test_deterministic_randomized_operations_match_sorted_array() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x5EED
	var tree: StdRedBlackTree = StdRedBlackTree.new(_compare_int)
	var reference: Array[int] = []

	for step: int in range(3000):
		var operation: int = rng.randi_range(0, 2)
		var value: int = rng.randi_range(-25, 25)
		if operation == 0 or reference.is_empty():
			tree.push(value)
			reference.push_back(value)
			reference.sort()
		elif operation == 1:
			var expected: int = reference.pop_front()
			assert_eq(tree.pop(expected).unwrap(), expected, "random existing-item pop matches reference")
		else:
			var expected_index: int = reference.find(value)
			var removed: StdOption = tree.pop(value)
			if expected_index == -1:
				assert_true(removed.is_none(), "random missing item pop is none")
			else:
				var expected: int = reference.pop_at(expected_index)
				assert_eq(removed.unwrap(), expected, "random targeted pop matches reference")
				pass
			pass

		assert_eq(tree.to_array(), reference, "random tree ordering matches reference")
		_check_valid(tree, "random operation preserves invariants")
		pass
	return
