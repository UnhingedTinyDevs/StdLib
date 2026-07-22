extends StdTest
## Headless tests for StdStack.



func _test_empty_stack() -> void:
	var stack: StdStack = StdStack.new()
	assert_true(stack.is_empty(), "new stack is empty")
	assert_true(stack.pop().is_none(), "empty pop is none")
	assert_true(stack.peek().is_none(), "empty peek is none")
	assert_err(stack.mutate(func(value: Variant) -> Variant: return value), "empty mutate errs")
	return


func _test_lifo_and_top_first_array() -> void:
	var stack: StdStack = StdStack.new()
	stack.push(1)
	stack.push(2)
	stack.push(3)
	assert_eq(stack.to_array(), [3, 2, 1], "array is top to bottom")
	assert_eq(stack.pop().unwrap(), 3, "last pushed leaves first")
	assert_eq(StdStack.from_array([9, 8, 7]).peek().unwrap(), 9, "first array value becomes top")
	return


func _test_update_top_assigns_return_value() -> void:
	var stack: StdStack = StdStack.from_array([2, 1])
	var updated: StdResult = stack.mutate(func(value: int) -> int: return value * 5)
	assert_ok(updated, "primitive update succeeds")
	assert_eq(updated.unwrap(), 10, "result contains replacement")
	assert_eq(stack.peek().unwrap(), 10, "primitive replacement is stored")
	var dict_stack: StdStack = StdStack.from_array([{"count": 1}])
	var _rv: StdResult = dict_stack.mutate(func(value: Dictionary) -> Dictionary:
		value["count"] += 1
		return value)
	assert_eq(dict_stack.peek().unwrap().get("count"), 2, "reference transform is stored")
	assert_err(stack.mutate(Callable()), "invalid mutator errors")
	assert_eq(stack.peek().unwrap(), 10, "invalid mutator leaves top unchanged")
	return


func _test_clear_filter_and_copy() -> void:
	var stack: StdStack = StdStack.from_array([4, 3, 2, 1])
	var evens: StdStack = stack.filter(
		func(value: int) -> bool: return value % 2 == 0
	).unwrap()
	assert_eq(evens.to_array(), [4, 2], "filter preserves pop order")
	assert_eq(stack.size(), 4, "filter leaves source unchanged")
	stack.clear()
	assert_true(stack.is_empty(), "clear empties stack")
	stack.push(9)
	assert_eq(stack.pop().unwrap(), 9, "stack is reusable")
	assert_err(StdStack.new().filter(Callable()), "filter rejects invalid predicate")
	assert_err(StdStack.new().map(Callable()), "map rejects invalid mapper")
	return


func _test_deterministic_stress_matches_array_model() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x57AC
	var stack: StdStack = StdStack.new()
	var reference: Array[int] = []
	for step: int in range(5000):
		if reference.is_empty() or rng.randi_range(0, 1) == 0:
			var value: int = rng.randi_range(-1000, 1000)
			stack.push(value)
			reference.push_front(value)
		else:
			assert_eq(stack.pop().unwrap(), reference.pop_front(), "stress pop matches model")
		assert_eq(stack.size(), reference.size(), "stress size matches model")
		assert_eq(stack.to_array(), reference, "stress order matches model")
		pass
	return


func _test_cross_conversions_preserve_next_out() -> void:
	var stack: StdStack = StdStack.from_array([1, 2, 3])
	var queue: StdQueue = StdQueue.from_array(stack.to_array())
	assert_eq(queue.to_array(), [1, 2, 3], "stack top becomes queue front")
	var doubly: StdDoublyLinkedList = StdDoublyLinkedList.from_array(stack.to_array())
	assert_eq(doubly.to_array(), [1, 2, 3], "stack top becomes list head")
	var circular: StdCircularLinkedList = StdCircularLinkedList.from_array(stack.to_array())
	assert_eq(StdStack.from_array(circular.to_array()).to_array(), [1, 2, 3], "list round trip")
	assert_true(StdSet.from_array(stack.to_array()).equals(StdSet.from_array([1, 2, 3])),
		"set conversion keeps unique values")
	return
