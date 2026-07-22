extends StdTest
## Headless tests for StdHeap.


func _test_empty_heap_and_index_bounds() -> void:
	var heap: StdHeap = StdHeap.new()
	assert_true(heap.is_empty(), "new heap is empty")
	assert_eq(heap.size(), 0, "new heap has size zero")
	assert_true(heap.peek().is_none(), "empty peek is none")
	assert_true(heap.pop().is_none(), "empty pop is none")
	assert_err(heap.mutate(func(value: Variant) -> Variant: return value), "empty mutate errors")
	for index: int in [-100, -1, 0, 1, 100]:
		assert_err(heap.parent_node(index), "empty parent index errors")
		assert_err(heap.left_node(index), "empty left index errors")
		assert_err(heap.right_node(index), "empty right index errors")
		pass
	return


func _test_min_max_and_equal_priority_stability() -> void:
	var minimum: StdHeap = StdHeap.new(StdHeap.Order.MIN)
	var maximum: StdHeap = StdHeap.new(StdHeap.Order.MAX)
	for heap: StdHeap in [minimum, maximum]:
		heap.push("middle-first", 5)
		heap.push("low", -2)
		heap.push("middle-second", 5)
		heap.push("high", 12)
		pass
	assert_eq(_drain(minimum), ["low", "middle-first", "middle-second", "high"],
		"min heap returns lowest priority first and is stable")
	assert_eq(_drain(maximum), ["high", "middle-first", "middle-second", "low"],
		"max heap returns highest priority first and is stable")
	return


func _test_parent_and_child_access_rejects_impossible_nodes() -> void:
	var heap: StdHeap = StdHeap.new()
	heap.push("root", 1)
	heap.push("left", 2)
	heap.push("right", 3)
	assert_eq(heap.left_value(0).unwrap(), "left", "left child value")
	assert_eq(heap.right_value(0).unwrap(), "right", "right child value")
	assert_eq(heap.parent_value(1).unwrap(), "root", "left parent value")
	assert_eq(heap.parent_value(2).unwrap(), "root", "right parent value")
	assert_eq(heap.left_priority(0).unwrap(), 2, "left child priority")
	assert_eq(heap.right_priority(0).unwrap(), 3, "right child priority")
	assert_eq(heap.parent_priority(2).unwrap(), 1, "parent priority")
	assert_err(heap.parent_node(0), "root has no parent")
	assert_err(heap.parent_node(7), "missing node cannot have a valid-looking parent")
	assert_err(heap.left_node(-1), "negative node cannot have a valid-looking child")
	assert_err(heap.right_node(-1), "negative node cannot resolve to root")
	assert_err(heap.left_node(2), "leaf has no left child")
	assert_err(heap.right_node(2), "leaf has no right child")
	return


func _test_mutate_map_filter_and_in_place_variants() -> void:
	var heap: StdHeap = StdHeap.new()
	heap.push(3, 30)
	heap.push(1, 10)
	heap.push(2, 20)
	var mutated: StdResult = heap.mutate(func(value: int) -> int: return value * 100)
	assert_ok(mutated, "mutate succeeds")
	assert_eq(heap.peek().unwrap(), 100, "mutate replaces root value")
	assert_err(heap.mutate(Callable()), "mutate rejects invalid callable")

	var mapped: StdHeap = heap.map(func(value: int) -> int: return value + 1).unwrap() as StdHeap
	assert_eq(_drain(mapped), [101, 3, 4], "map preserves priority order")
	assert_eq(heap.size(), 3, "map leaves source unchanged")
	assert_err(heap.map(Callable()), "map rejects invalid callable")
	assert_ok(heap.map_in_place(func(value: int) -> int: return value + 1), "map_in_place succeeds")
	assert_eq(heap.peek().unwrap(), 101, "map_in_place updates the root value")
	assert_err(heap.map_in_place(Callable()), "map_in_place rejects invalid callable")

	var filtered: StdHeap = heap.filter(func(value: int) -> bool: return value != 3).unwrap() as StdHeap
	assert_eq(_drain(filtered), [101, 4], "filter removes rejected values and reheapifies")
	var sizes: Array[int] = []
	heap.size_changed.connect(func(value: int) -> void: sizes.push_back(value))
	assert_ok(heap.filter_in_place(func(value: int) -> bool: return value != 101),
		"filter_in_place succeeds")
	assert_eq(sizes, [2], "filter_in_place emits changed size")
	assert_eq(_drain(heap), [3, 4], "filter_in_place preserves remaining priority order")
	assert_err(StdHeap.new().filter(Callable()), "filter rejects invalid callable")
	assert_err(StdHeap.new().filter_in_place(Callable()), "filter_in_place rejects invalid callable")
	return


func _test_signals_and_clear_reuse() -> void:
	var heap: StdHeap = StdHeap.new()
	var pushed_values: Array = []
	var popped_values: Array = []
	var mutations: Array = []
	var sizes: Array[int] = []
	var clears: Array[bool] = []
	heap.pushed.connect(func(value: Variant, priority: int) -> void:
		pushed_values.push_back([value, priority]))
	heap.popped.connect(func(value: Variant) -> void: popped_values.push_back(value))
	heap.mutated.connect(func(new: Variant, old: Variant) -> void: mutations.push_back([new, old]))
	heap.size_changed.connect(func(value: int) -> void: sizes.push_back(value))
	heap.cleared.connect(func() -> void: clears.push_back(true))
	heap.push("a", 2)
	heap.push("b", 1)
	var _mutated: StdResult = heap.mutate(func(value: String) -> String: return value.to_upper())
	var _popped: StdOption = heap.pop()
	heap.clear()
	assert_eq(pushed_values, [["a", 2], ["b", 1]], "push signal includes value and priority")
	assert_eq(popped_values, ["B"], "pop signal reports removed value")
	assert_eq(mutations, [["B", "b"]], "mutate signal reports new and old values")
	assert_eq(sizes, [1, 2, 1, 0], "size signal follows pushes, pop, and clear")
	assert_eq(clears, [true], "clear signal emits once")
	heap.push("first", 5)
	heap.push("second", 5)
	assert_eq(_drain(heap), ["first", "second"], "clear resets stable insertion sequence")
	return


func _test_deterministic_stress_matches_reference_model() -> void:
	for order: StdHeap.Order in [StdHeap.Order.MIN, StdHeap.Order.MAX]:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 0x4EA9 + int(order)
		var heap: StdHeap = StdHeap.new(order)
		var reference: Array = []
		var sequence: int = 0
		for step: int in range(3000):
			if reference.is_empty() or rng.randi_range(0, 2) != 0:
				var priority: int = rng.randi_range(-50, 50)
				heap.push(sequence, priority)
				reference.push_back([priority, sequence, sequence])
				sequence += 1
			else:
				var best_index: int = _best_index(reference, order)
				var expected: Array = reference.pop_at(best_index)
				assert_eq(heap.pop().unwrap(), expected[2], "stress pop matches model")
			assert_eq(heap.size(), reference.size(), "stress size matches model")
			if reference.is_empty():
				assert_true(heap.peek().is_none(), "stress empty peek is none")
			else:
				var best: Array = reference[_best_index(reference, order)]
				assert_eq(heap.peek().unwrap(), best[2], "stress root matches model")
			pass
		while not reference.is_empty():
			var best_index: int = _best_index(reference, order)
			var expected: Array = reference.pop_at(best_index)
			assert_eq(heap.pop().unwrap(), expected[2], "stress drain matches model")
			pass
		assert_true(heap.is_empty(), "stress drain empties heap")
		pass
	return


func _best_index(reference: Array, order: StdHeap.Order) -> int:
	var best_index: int = 0
	for index: int in range(1, reference.size()):
		var candidate: Array = reference[index]
		var best: Array = reference[best_index]
		var better_priority: bool = candidate[0] < best[0] if order == StdHeap.Order.MIN \
			else candidate[0] > best[0]
		if better_priority or (candidate[0] == best[0] and candidate[1] < best[1]):
			best_index = index
		pass
	return best_index


func _drain(heap: StdHeap) -> Array:
	var values: Array = []
	while not heap.is_empty():
		values.push_back(heap.pop().unwrap())
		pass
	return values
