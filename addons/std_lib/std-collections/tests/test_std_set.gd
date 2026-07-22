extends StdTest
## Headless tests for StdSet.


class KeyedValue extends RefCounted:
	var id: int
	var label: String

	func _init(value_id: int, value_label: String) -> void:
		id = value_id
		label = value_label
		return


func _by_id(value: KeyedValue) -> int:
	return value.id


func _area_name(area: Area2D) -> StringName:
	return area.name


func _node_id(node: Node) -> int:
	return node.get_instance_id()


func _test_empty_push_pop_clear() -> void:
	var set: StdSet = StdSet.new()
	assert_true(set.is_empty(), "new set is empty")
	assert_eq(set.size(), 0, "new set has size zero")
	assert_true(set.pop(1).is_none(), "missing pop is none")
	assert_true(set.peek(1).is_none(), "missing peek is none")

	set.push(1)
	set.push(1)
	set.push(2)
	assert_eq(set.size(), 2, "duplicate values collapse")
	assert_true(set.has(1), "pushed value is present")
	assert_eq(set.peek(1).unwrap(), 1, "peek returns stored value")
	assert_eq(set.pop(1).unwrap(), 1, "pop returns stored value")
	assert_true(not set.has(1), "pop removes stored value")

	set.clear()
	assert_true(set.is_empty(), "clear empties set")
	return


func _test_push_and_pop_signals_only_report_changes() -> void:
	var set: StdSet = StdSet.new()
	var pushed: Array = []
	var popped: Array = []
	set.item_pushed.connect(func(item: Variant) -> void: pushed.push_back(item))
	set.item_popped.connect(func(item: Variant) -> void: popped.push_back(item))

	set.push("value")
	set.push("value")
	var _missing: StdOption = set.pop("missing")
	var _removed: StdOption = set.pop("value")
	assert_eq(pushed, ["value"], "duplicate push emits no signal")
	assert_eq(popped, ["value"], "only successful pop emits a signal")
	return


func _test_builtin_value_sets() -> void:
	var integers: StdSet = StdSet.from_array([1, 1, 2])
	var floats: StdSet = StdSet.from_array([1.5, 1.5, 2.5])
	var strings: StdSet = StdSet.from_array(["one", "one", "two"])
	var vector_2s: StdSet = StdSet.from_array([Vector2.ONE, Vector2.ONE, Vector2.ZERO])
	var vector_3s: StdSet = StdSet.from_array([Vector3.ONE, Vector3.ONE, Vector3.ZERO])

	assert_eq(integers.size(), 2, "integer set deduplicates")
	assert_eq(floats.size(), 2, "float set deduplicates")
	assert_eq(strings.size(), 2, "string set deduplicates")
	assert_eq(vector_2s.size(), 2, "Vector2 set deduplicates")
	assert_eq(vector_3s.size(), 2, "Vector3 set deduplicates")
	return


func _test_default_object_identity() -> void:
	var resources: StdSet = StdSet.new()
	var first_resource: Resource = Resource.new()
	var second_resource: Resource = Resource.new()
	resources.push(first_resource)
	resources.push(first_resource)
	resources.push(second_resource)
	assert_eq(resources.size(), 2, "resources use instance identity")

	var references: StdSet = StdSet.new()
	var first_reference: RefCounted = RefCounted.new()
	var second_reference: RefCounted = RefCounted.new()
	references.push(first_reference)
	references.push(second_reference)
	assert_eq(references.size(), 2, "RefCounted values use instance identity")

	var nodes: StdSet = StdSet.new()
	var first_node: Node = Node.new()
	var second_node: Node = Node.new()
	nodes.push(first_node)
	nodes.push(second_node)
	assert_eq(nodes.size(), 2, "nodes use instance identity")
	nodes.clear()
	first_node.free()
	second_node.free()

	var objects: StdSet = StdSet.new()
	var first_object: Object = Object.new()
	var second_object: Object = Object.new()
	objects.push(first_object)
	objects.push(second_object)
	assert_eq(objects.size(), 2, "plain objects use instance identity")
	objects.clear()
	first_object.free()
	second_object.free()
	return


func _test_identifier_defines_uniqueness_and_keeps_first_value() -> void:
	var set: StdSet = StdSet.new(_by_id)
	var first: KeyedValue = KeyedValue.new(7, "first")
	var duplicate: KeyedValue = KeyedValue.new(7, "second")
	set.push(first)
	set.push(duplicate)

	assert_eq(set.size(), 1, "identifier defines uniqueness")
	assert_true(set.has(duplicate), "equivalent object is present")
	assert_eq(set.pop(duplicate).unwrap(), first, "pop returns first stored object")
	return


func _test_area_identifier() -> void:
	var set: StdSet = StdSet.new(_area_name)
	var first: Area2D = Area2D.new()
	var duplicate: Area2D = Area2D.new()
	first.name = &"hurtbox"
	duplicate.name = &"hurtbox"
	set.push(first)
	set.push(duplicate)

	assert_eq(set.size(), 1, "Area2D identifier deduplicates matching areas")
	assert_eq(set.pop(duplicate).unwrap(), first, "Area2D pop returns stored area")
	first.free()
	duplicate.free()
	return


func _test_map_uses_default_keys() -> void:
	var set: StdSet = StdSet.from_array(
		[KeyedValue.new(1, "same"), KeyedValue.new(2, "same")],
		_by_id,
	)
	var mapped_result: StdResult = set.map(func(value: KeyedValue) -> String: return value.label)
	assert_ok(mapped_result, "map succeeds")
	var mapped: StdSet = mapped_result.unwrap() as StdSet
	assert_eq(mapped.size(), 1, "mapped values use default keys and deduplicate")
	assert_eq(set.size(), 2, "map leaves source unchanged")
	assert_err(set.map(Callable()), "invalid mapper errors")
	return


func _test_filter_preserves_identifier() -> void:
	var set: StdSet = StdSet.from_array(
		[KeyedValue.new(1, "a"), KeyedValue.new(2, "b")],
		_by_id,
	)
	var filtered_result: StdResult = set.filter(func(value: KeyedValue) -> bool: return value.id == 2)
	assert_ok(filtered_result, "filter succeeds")
	var filtered: StdSet = filtered_result.unwrap() as StdSet
	filtered.push(KeyedValue.new(2, "duplicate"))
	assert_eq(filtered.size(), 1, "filtered set keeps identifier")
	assert_eq(set.size(), 2, "filter leaves source unchanged")
	assert_err(set.filter(Callable()), "invalid predicate errors")
	return


func _test_set_operations() -> void:
	var a: StdSet = StdSet.from_array([1, 2, 3])
	var b: StdSet = StdSet.from_array([2, 3, 4])
	var union_set: StdSet = a.union(b).unwrap() as StdSet
	var intersection_set: StdSet = a.intersection(b).unwrap() as StdSet
	var difference_set: StdSet = a.difference(b).unwrap() as StdSet
	var symmetric_set: StdSet = a.symmetric_difference(b).unwrap() as StdSet

	assert_true(union_set.equals(StdSet.from_array([1, 2, 3, 4])), "union")
	assert_true(intersection_set.equals(StdSet.from_array([2, 3])), "intersection")
	assert_true(difference_set.equals(StdSet.from_array([1])), "difference")
	assert_true(symmetric_set.equals(StdSet.from_array([1, 4])), "symmetric difference")
	assert_true(a.equals(StdSet.from_array([1, 2, 3])), "operations leave receiver unchanged")
	assert_true(b.equals(StdSet.from_array([2, 3, 4])), "operations leave operand unchanged")
	return


func _test_set_operations_preserve_identifier() -> void:
	var a: StdSet = StdSet.from_array([KeyedValue.new(1, "first")], _by_id)
	var b: StdSet = StdSet.from_array(
		[KeyedValue.new(1, "duplicate"), KeyedValue.new(2, "second")],
		_by_id,
	)
	var combined: StdSet = a.union(b).unwrap() as StdSet
	combined.push(KeyedValue.new(2, "another duplicate"))
	assert_eq(combined.size(), 2, "set operation result keeps identifier")
	return


func _test_set_operations_normalize_operand_with_receiver_identifier() -> void:
	var receiver_value: KeyedValue = KeyedValue.new(1, "receiver")
	var operand_value: KeyedValue = KeyedValue.new(1, "operand")
	var receiver: StdSet = StdSet.from_array([receiver_value], _by_id)
	var operand: StdSet = StdSet.new(func(value: KeyedValue) -> String: return value.label)
	operand.push(operand_value)
	var intersection: StdSet = receiver.intersection(operand).unwrap() as StdSet
	assert_eq(intersection.size(), 1, "intersection uses receiver identity for operand")
	assert_eq(intersection.peek(operand_value).unwrap(), receiver_value,
		"intersection retains receiver value")
	assert_true(receiver.equals(operand), "equals normalizes operand with receiver identity")
	assert_true(receiver.subset(operand), "subset normalizes operand with receiver identity")
	assert_true(receiver.superset(operand), "superset normalizes operand with receiver identity")
	assert_true(not receiver.disjoint(operand), "disjoint normalizes operand with receiver identity")
	return


func _test_set_relationships() -> void:
	var set: StdSet = StdSet.from_array([1, 2, 3])
	assert_true(StdSet.from_array([1, 2]).subset(set), "subset")
	assert_true(set.superset(StdSet.from_array([1, 2])), "superset")
	assert_true(set.disjoint(StdSet.from_array([8, 9])), "disjoint")
	assert_true(not set.disjoint(StdSet.from_array([3, 9])), "shared value is not disjoint")
	assert_true(set.equals(StdSet.from_array([3, 2, 1])), "equals ignores insertion order")
	assert_true(StdSet.new().subset(set), "empty set is a subset")
	return


func _test_array_conversion_and_snapshot() -> void:
	var set: StdSet = StdSet.from_array([3, 1, 3, 2])
	assert_eq(set.size(), 3, "from_array deduplicates")
	var snapshot: Array = set.to_array()
	snapshot.clear()
	assert_eq(set.size(), 3, "array snapshot cannot mutate set")
	assert_eq(set.values().size(), 3, "values returns every stored value")
	return


func _test_prune_invalid_reclaims_freed_objects() -> void:
	var set: StdSet = StdSet.new(_node_id)
	var live: Node = Node.new()
	var dead: Node = Node.new()
	set.push(live)
	set.push(dead)
	dead.free()
	assert_eq(set.prune_invalid(), 1, "prune removes externally freed object")
	assert_eq(set.size(), 1, "prune updates size")
	assert_true(set.has(live), "prune retains live object")
	assert_eq(set.prune_invalid(), 0, "prune reports zero when nothing is stale")
	set.clear()
	live.free()

	var identity_set: StdSet = StdSet.new()
	var identity_node: Node = Node.new()
	identity_set.push(identity_node)
	identity_node.free()
	assert_eq(identity_set.prune_invalid(), 1, "prune removes a freed Object used as its own key")
	assert_true(identity_set.is_empty(), "default-key set is empty after pruning freed Object")
	return


func _test_deterministic_stress_matches_dictionary_model() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x5E7
	var set: StdSet = StdSet.new()
	var reference: Dictionary = {}
	for step: int in range(5000):
		var value: int = rng.randi_range(-100, 100)
		if rng.randi_range(0, 1) == 0:
			set.push(value)
			reference[value] = true
		else:
			var removed: StdOption = set.pop(value)
			assert_eq(removed.is_some(), reference.erase(value), "stress pop presence matches model")
		assert_eq(set.size(), reference.size(), "stress size matches model")
		for key: Variant in reference:
			assert_true(set.has(key), "stress set contains every model key")
			pass
		pass
	return
