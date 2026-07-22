extends StdTest
## Headless tests for StdQueue.



func _test_empty_queue() -> void:
	var queue: StdQueue = StdQueue.new()
	assert_true(queue.is_empty(), "new queue is empty")
	assert_eq(queue.size(), 0, "new queue has size zero")
	assert_true(queue.pop().is_none(), "empty pop is none")
	assert_true(queue.peek().is_none(), "empty peek is none")
	assert_true(not queue.has(1), "empty queue has nothing")
	assert_err(queue.mutate(func(value: Variant) -> Variant: return value), "empty mutate errors")
	return


func _test_mutate_front_and_invalid_callable() -> void:
	var queue: StdQueue = StdQueue.from_array([2, 3])
	var result: StdResult = queue.mutate(func(value: int) -> int: return value * 5)
	assert_ok(result, "valid mutator succeeds")
	assert_eq(result.unwrap(), 10, "mutate returns the replacement")
	assert_eq(queue.to_array(), [10, 3], "mutate replaces only the front")
	assert_err(queue.mutate(Callable()), "invalid mutator errors")
	assert_eq(queue.to_array(), [10, 3], "invalid mutate leaves queue unchanged")
	return


func _test_fifo_order() -> void:
	var queue: StdQueue = StdQueue.new()
	queue.push("a")
	queue.push("b")
	queue.push("c")
	assert_eq(queue.peek().unwrap(), "a", "peek reads the front")
	assert_eq(queue.pop().unwrap(), "a", "first pushed leaves first")
	assert_eq(queue.pop().unwrap(), "b", "second pushed leaves second")
	queue.push("d")
	assert_eq(queue.to_array(), ["c", "d"], "snapshot is front to back")
	return


func _test_clear_and_reuse() -> void:
	var queue: StdQueue = StdQueue.from_array([1, 2, 3])
	var _removed: StdOption = queue.pop()
	queue.clear()
	assert_true(queue.is_empty(), "clear removes consumed and live slots")
	queue.push(9)
	assert_eq(queue.pop().unwrap(), 9, "queue is reusable after clear")
	return


func _test_compaction_preserves_order() -> void:
	var values: Array = []
	for i: int in 140:
		values.push_back(i)
		pass
	var queue: StdQueue = StdQueue.from_array(values)
	for i: int in 100:
		assert_eq(queue.pop().unwrap(), i, "compaction pop %d" % i)
		pass
	assert_eq(queue.to_array(), values.slice(100), "compaction keeps remaining order")
	return


func _test_drain_does_not_emit_clear_or_duplicate_size() -> void:
	var queue: StdQueue = StdQueue.from_array([1])
	var clears: Array[bool] = []
	var sizes: Array[int] = []
	queue.cleared.connect(func() -> void: clears.push_back(true))
	queue.size_changed.connect(func(value: int) -> void: sizes.push_back(value))
	var _removed: StdOption = queue.pop()
	assert_eq(clears.size(), 0, "popping the last value does not emit cleared")
	assert_eq(sizes, [0], "popping the last value emits one size change")
	return


func _test_has_filter_and_copy() -> void:
	var queue: StdQueue = StdQueue.from_array([1, 2, 3, 4])
	assert_true(queue.has(3), "has finds queued value")
	assert_true(not queue.has(8), "has misses absent value")
	var evens: StdQueue = queue.filter(
		func(value: int) -> bool: return value % 2 == 0
	).unwrap()
	assert_eq(evens.to_array(), [2, 4], "filter preserves FIFO order")
	assert_eq(queue.to_array(), [1, 2, 3, 4], "filter leaves source unchanged")
	var copy: StdQueue = StdQueue.from_array(queue.to_array())
	var _copy_pop: StdOption = copy.pop()
	assert_eq(queue.size(), 4, "queue conversion makes an independent copy")
	assert_err(queue.filter(Callable()), "filter rejects invalid predicate")
	assert_err(queue.map(Callable()), "map rejects invalid mapper")
	return


func _test_deterministic_stress_matches_array_model() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x0E0E
	var queue: StdQueue = StdQueue.new()
	var reference: Array[int] = []
	for step: int in range(5000):
		if reference.is_empty() or rng.randi_range(0, 1) == 0:
			var value: int = rng.randi_range(-1000, 1000)
			queue.push(value)
			reference.push_back(value)
		else:
			assert_eq(queue.pop().unwrap(), reference.pop_front(), "stress pop matches model")
		assert_eq(queue.size(), reference.size(), "stress size matches model")
		assert_eq(queue.to_array(), reference, "stress order matches model")
		pass
	return


func _test_cross_conversions_use_next_out_order() -> void:
	var queue: StdQueue = StdQueue.from_array([1, 2, 3])
	assert_eq(StdStack.from_array(queue.to_array()).to_array(), [1, 2, 3],
		"queue front becomes stack top")
	assert_eq(StdSinglyLinkedList.from_array(queue.to_array()).to_array(), [1, 2, 3],
		"queue front becomes list head")
	assert_eq(StdDoublyLinkedList.from_array(queue.to_array()).to_array(), [1, 2, 3],
		"doubly conversion keeps order")
	assert_eq(StdCircularLinkedList.from_array(queue.to_array()).to_array(), [1, 2, 3],
		"ring conversion keeps order")
	assert_eq(StdBag.from_array(queue.to_array(), _seeded()).to_array(), [1, 2, 3],
		"bag conversion keeps values")
	assert_true(StdSet.from_array(queue.to_array()).equals(StdSet.from_array([1, 2, 3])),
		"set conversion keeps unique values")
	return


func _seeded() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	return rng
