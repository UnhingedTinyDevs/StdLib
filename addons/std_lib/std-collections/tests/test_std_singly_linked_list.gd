extends StdTest
## Headless tests for StdSinglyLinkedList.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-collections



func _test_empty_list() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	var base: StdLinkedListBase = list
	assert_true(base == list, "singly linked list inherits the shared base")
	assert_true(list.is_empty(), "new list is empty")
	assert_eq(list.size(), 0, "new list has size 0")
	assert_true(list.head().is_none(), "head on empty is none")
	assert_true(list.tail().is_none(), "tail on empty is none")
	assert_true(list.pop_head().is_none(), "pop_head on empty is none")
	assert_true(not list.has(1), "has on empty is false")
	return


func _test_push_tail_ordering() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	list.push_tail(1)
	list.push_tail(2)
	list.push_tail(3)
	assert_eq(list.size(), 3, "size after three push_tail")
	assert_eq(list.head().unwrap(), 1, "head is first pushed")
	assert_eq(list.tail().unwrap(), 3, "tail is last pushed")
	assert_eq(list.pop_head().unwrap(), 1, "pop_head returns in insert order")
	assert_eq(list.pop_head().unwrap(), 2, "pop_head returns in insert order")
	assert_eq(list.pop_head().unwrap(), 3, "pop_head returns in insert order")
	assert_true(list.is_empty(), "empty after popping all")
	return


func _test_push_head_ordering() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	list.push_head(1)
	list.push_head(2)
	list.push_head(3)
	assert_eq(list.head().unwrap(), 3, "head is last pushed")
	assert_eq(list.tail().unwrap(), 1, "tail is first pushed")
	assert_eq(list.pop_head().unwrap(), 3, "pop_head returns newest head")
	assert_eq(list.pop_head().unwrap(), 2, "pop_head follows links")
	assert_eq(list.pop_head().unwrap(), 1, "pop_head empties list")
	assert_true(list.is_empty(), "empty after popping all")
	return


func _test_single_element() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	list.push_head("only")
	assert_eq(list.head().unwrap(), "only", "head of single element")
	assert_eq(list.tail().unwrap(), "only", "tail of single element")
	assert_eq(list.pop_head().unwrap(), "only", "pop_head single element")
	assert_true(list.head().is_none(), "head none after emptying")
	assert_true(list.tail().is_none(), "tail none after emptying")
	assert_eq(list.size(), 0, "size 0 after emptying")
	return


func _test_has() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	list.push_tail("a")
	list.push_tail("b")
	assert_true(list.has("a"), "has finds head data")
	assert_true(list.has("b"), "has finds tail data")
	assert_true(not list.has("c"), "has misses absent data")
	return


func _test_clear() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	list.push_tail(1)
	list.push_tail(2)
	list.clear()
	assert_true(list.is_empty(), "empty after clear")
	assert_true(list.head().is_none(), "head none after clear")
	assert_true(list.tail().is_none(), "tail none after clear")
	list.push_tail(9)
	assert_eq(list.head().unwrap(), 9, "list reusable after clear")
	assert_eq(list.size(), 1, "size tracks after clear")
	return


func _test_conversions() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.from_array([1, 2, 3])
	assert_eq(list.to_array(), [1, 2, 3], "array round trip keeps order")
	assert_eq(list.tail().unwrap(), 3, "from_array sets the tail")
	return


func _test_filter() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.from_array([1, 2, 3, 4])
	var evens: StdSinglyLinkedList = list.filter(func(v: Variant) -> bool: return v % 2 == 0).unwrap()
	assert_eq(evens.to_array(), [2, 4], "filter keeps matching values head to tail")
	assert_eq(list.size(), 4, "filter does not mutate the source")
	var empty: StdSinglyLinkedList = StdSinglyLinkedList.new().filter(
		func(v: Variant) -> bool: return true
	).unwrap()
	assert_true(empty.is_empty(), "filter on empty list is empty")
	assert_err(list.filter(Callable()), "filter rejects an invalid predicate")
	return


func _test_map() -> void:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.from_array([1, 2, 3])
	var doubled: StdSinglyLinkedList = list.map(func(v: Variant) -> int: return v * 2).unwrap()
	assert_eq(doubled.to_array(), [2, 4, 6], "map keeps list order")
	assert_eq(list.to_array(), [1, 2, 3], "map does not mutate the source")
	assert_err(list.map(Callable()), "map rejects an invalid mapper")
	return


func _test_deterministic_stress_matches_array_model() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x51A6
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	var reference: Array[int] = []
	for step: int in range(3000):
		var operation: int = rng.randi_range(0, 2)
		var value: int = rng.randi_range(-1000, 1000)
		if operation == 0:
			list.push_head(value)
			reference.push_front(value)
		elif operation == 1:
			list.push_tail(value)
			reference.push_back(value)
		elif reference.is_empty():
			assert_true(list.pop_head().is_none(), "stress empty pop is none")
		else:
			assert_eq(list.pop_head().unwrap(), reference.pop_front(), "stress pop matches model")
		assert_eq(list.size(), reference.size(), "stress size matches model")
		assert_eq(list.to_array(), reference, "stress order matches model")
		assert_eq(list.head().is_none(), reference.is_empty(), "stress head emptiness matches model")
		assert_eq(list.tail().is_none(), reference.is_empty(), "stress tail emptiness matches model")
		pass
	return
