extends StdTest
## Headless tests for StdCircularLinkedList.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-collections



func _test_empty_ring() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	var collection: IStdDoubleEndedListCollection = ring
	assert_true(collection == ring, "ring implements the double-ended list interface")
	assert_true(ring.is_empty(), "new ring is empty")
	assert_eq(ring.size(), 0, "new ring has size 0")
	assert_true(ring.head().is_none(), "head on empty is none")
	assert_true(ring.tail().is_none(), "tail on empty is none")
	assert_true(ring.pop_head().is_none(), "pop_head on empty is none")
	assert_true(ring.pop_tail().is_none(), "pop_tail on empty is none")
	assert_true(not ring.has(1), "has on empty is false")
	ring.rotate_left()
	assert_true(ring.is_empty(), "rotate on empty is a no-op")
	return


func _test_push_pop_ordering() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	ring.push_tail(1)
	ring.push_tail(2)
	ring.push_tail(3)
	assert_eq(ring.head().unwrap(), 1, "head is first pushed")
	assert_eq(ring.tail().unwrap(), 3, "tail is last pushed")
	assert_eq(ring.pop_head().unwrap(), 1, "pop_head returns in insert order")
	assert_eq(ring.pop_head().unwrap(), 2, "pop_head returns in insert order")
	assert_eq(ring.pop_head().unwrap(), 3, "pop_head returns in insert order")
	assert_true(ring.is_empty(), "empty after popping all")
	ring.push_head(1)
	ring.push_head(2)
	assert_eq(ring.head().unwrap(), 2, "push_head makes new head")
	assert_eq(ring.tail().unwrap(), 1, "old head becomes tail")
	assert_eq(ring.pop_tail().unwrap(), 1, "pop_tail removes old head")
	assert_eq(ring.pop_tail().unwrap(), 2, "pop_tail empties the ring")
	return


func _test_single_element_self_ring() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	ring.push_head("only")
	assert_eq(ring.head().unwrap(), "only", "head of single element")
	assert_eq(ring.tail().unwrap(), "only", "tail wraps to the same node")
	ring.rotate_left()
	assert_eq(ring.head().unwrap(), "only", "rotating a single node keeps head")
	assert_eq(ring.pop_head().unwrap(), "only", "pop_head single element")
	assert_true(ring.head().is_none(), "head none after emptying")
	assert_eq(ring.size(), 0, "size 0 after emptying")
	return


func _test_rotation() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	ring.push_tail("a")
	ring.push_tail("b")
	ring.push_tail("c")
	ring.rotate_left()
	assert_eq(ring.head().unwrap(), "b", "rotate_left advances the head")
	assert_eq(ring.tail().unwrap(), "a", "old head wraps to the tail")
	ring.rotate_right()
	assert_eq(ring.head().unwrap(), "a", "rotate_right undoes rotate_left")
	ring.rotate_left(3)
	assert_eq(ring.head().unwrap(), "a", "rotating by size is identity")
	ring.rotate_left(4)
	assert_eq(ring.head().unwrap(), "b", "rotation wraps past size")
	ring.rotate_left(-1)
	assert_eq(ring.head().unwrap(), "a", "negative steps rotate backward")
	assert_eq(ring.size(), 3, "rotation does not change size")
	return


func _test_pop_after_rotation() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	ring.push_tail(1)
	ring.push_tail(2)
	ring.push_tail(3)
	ring.rotate_left()
	assert_eq(ring.pop_head().unwrap(), 2, "pop_head after rotation")
	assert_eq(ring.pop_tail().unwrap(), 1, "pop_tail after rotation")
	assert_eq(ring.head().unwrap(), 3, "remaining node is head")
	assert_eq(ring.tail().unwrap(), 3, "remaining node is also tail")
	return


func _test_has() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	ring.push_tail("a")
	ring.push_tail("b")
	assert_true(ring.has("a"), "has finds head data")
	assert_true(ring.has("b"), "has finds tail data")
	assert_true(not ring.has("c"), "has misses absent data and terminates")
	return


func _test_clear() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	ring.push_tail(1)
	ring.push_tail(2)
	ring.clear()
	assert_true(ring.is_empty(), "empty after clear")
	assert_true(ring.head().is_none(), "head none after clear")
	assert_true(ring.tail().is_none(), "tail none after clear")
	ring.push_tail(9)
	assert_eq(ring.head().unwrap(), 9, "ring reusable after clear")
	assert_eq(ring.tail().unwrap(), 9, "single node ring after clear")
	return


func _test_conversions() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.from_array([1, 2, 3])
	assert_eq(ring.to_array(), [1, 2, 3], "to_array walks the ring exactly once")
	assert_eq(ring.tail().unwrap(), 3, "from_array closes the ring")
	ring.rotate_left()
	assert_eq(ring.to_array(), [2, 3, 1], "to_array starts at the current head")
	var queue: StdQueue = StdQueue.from_array(["a"])
	assert_eq(StdCircularLinkedList.from_array(queue.to_array()).to_array(), ["a"],
		"queue single node ring")
	var singly: StdSinglyLinkedList = StdSinglyLinkedList.from_array([4, 5])
	assert_eq(StdCircularLinkedList.from_array(singly.to_array()).to_array(), [4, 5], "cross-list")
	var set: StdSet = StdSet.from_array([1, 2])
	var set_ring: StdCircularLinkedList = StdCircularLinkedList.from_array(set.to_array())
	assert_true(StdSet.from_array(set_ring.to_array()).equals(set), "set round trip")
	assert_eq(StdQueue.from_array(ring.to_array()).to_array(), [2, 3, 1],
		"queue keeps rotated order")
	return


func _test_filter() -> void:
	var ring: StdCircularLinkedList = StdCircularLinkedList.from_array([1, 2, 3, 4])
	var evens: StdCircularLinkedList = ring.filter(
		func(v: Variant) -> bool: return v % 2 == 0
	).unwrap()
	assert_eq(evens.to_array(), [2, 4], "filter keeps matching values head to tail")
	assert_eq(ring.size(), 4, "filter does not mutate the source")
	var empty: StdCircularLinkedList = StdCircularLinkedList.new().filter(
		func(v: Variant) -> bool: return true
	).unwrap()
	assert_true(empty.is_empty(), "filter on empty ring is empty")
	assert_err(ring.filter(Callable()), "filter rejects an invalid predicate")
	var doubled: StdCircularLinkedList = ring.map(
		func(v: Variant) -> int: return v * 2
	).unwrap()
	assert_eq(doubled.to_array(), [2, 4, 6, 8], "map keeps ring order")
	assert_err(ring.map(Callable()), "map rejects an invalid mapper")
	return


func _test_deterministic_stress_matches_array_model() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xC1AC
	var ring: StdCircularLinkedList = StdCircularLinkedList.new()
	var reference: Array[int] = []
	for step: int in range(3000):
		var operation: int = rng.randi_range(0, 5)
		var value: int = rng.randi_range(-1000, 1000)
		if operation == 0:
			ring.push_head(value)
			reference.push_front(value)
		elif operation == 1:
			ring.push_tail(value)
			reference.push_back(value)
		elif reference.is_empty():
			assert_true(ring.pop_head().is_none(), "stress empty pop is none")
		elif operation == 2:
			assert_eq(ring.pop_head().unwrap(), reference.pop_front(), "stress head pop matches model")
		elif operation == 3:
			assert_eq(ring.pop_tail().unwrap(), reference.pop_back(), "stress tail pop matches model")
		elif operation == 4:
			var steps: int = rng.randi_range(-50, 50)
			ring.rotate_left(steps)
			_rotate_model(reference, steps)
		else:
			var steps: int = rng.randi_range(-50, 50)
			ring.rotate_right(steps)
			_rotate_model(reference, -steps)
		assert_eq(ring.size(), reference.size(), "stress size matches model")
		assert_eq(ring.to_array(), reference, "stress order matches model")
		assert_eq(ring.head().is_none(), reference.is_empty(), "stress head emptiness matches model")
		assert_eq(ring.tail().is_none(), reference.is_empty(), "stress tail emptiness matches model")
		pass
	return


func _rotate_model(reference: Array[int], steps: int) -> void:
	if reference.is_empty():
		return
	for step: int in posmod(steps, reference.size()):
		reference.push_back(reference.pop_front())
		pass
	return
