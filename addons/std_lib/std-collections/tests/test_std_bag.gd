extends StdTest
## Headless tests for StdBag.


func _seeded(seed_value: int = 17) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_empty_bag() -> void:
	var bag: StdBag = StdBag.new(_seeded())
	assert_true(bag.is_empty(), "new Bag is empty")
	assert_eq(bag.size(), 0, "empty Bag has no unique values")
	assert_eq(bag.items(), 0, "empty Bag has no occurrences")
	assert_true(bag.peek().is_none(), "empty peek is none")
	assert_true(bag.pop().is_none(), "empty pop is none")
	assert_err(bag.mutate(func(value: Variant) -> Variant: return value), "empty mutate errors")
	return


func _test_push_counts_and_peek() -> void:
	var bag: StdBag = StdBag.new(_seeded())
	bag.push("apple")
	bag.push("apple")
	bag.push("orange")

	assert_eq(bag.size(), 2, "size counts unique values")
	assert_eq(bag.items(), 3, "items counts every occurrence")
	assert_eq(bag.count("apple"), 2, "count reports duplicate occurrences")
	assert_eq(bag.count("missing"), 0, "count reports zero for missing values")
	assert_eq(bag.peek().unwrap(), ["apple", "apple", "orange"], "peek expands all occurrences")
	assert_eq(bag.items(), 3, "peek does not change the Bag")
	return


func _test_push_n_bounds_and_targeted_removal() -> void:
	var bag: StdBag = StdBag.new(_seeded())
	bag.push_n("apple", 4)
	bag.push_n("ignored", 0)
	bag.push_n("ignored", -10)
	assert_eq(bag.count("apple"), 4, "push_n adds the requested occurrences")
	assert_eq(bag.items(), 4, "non-positive push_n does not change item count")
	assert_eq(bag.pop_item("apple").unwrap(), "apple", "pop_item removes a matching occurrence")
	assert_eq(bag.count("apple"), 3, "pop_item decrements the count")
	assert_true(bag.pop_item("missing").is_none(), "pop_item missing value is none")
	assert_eq(bag.pop_all("apple"), 3, "pop_all reports every removed occurrence")
	assert_eq(bag.pop_all("apple"), 0, "pop_all missing value reports zero")
	assert_true(bag.is_empty(), "targeted removal can empty the bag")
	return


func _test_pop_and_draw_remove_one_occurrence() -> void:
	var bag: StdBag = StdBag.from_array(["apple", "apple", "orange"], _seeded())
	var popped: Variant = bag.pop().unwrap()
	assert_eq(bag.items(), 2, "pop removes one occurrence")
	assert_eq(bag.count(popped), 1 if popped == "apple" else 0, "pop decrements its selected value")
	assert_true(bag.pop().is_some(), "second pop succeeds")
	assert_eq(bag.items(), 1, "second pop removes one occurrence")
	return


func _test_mutate_replaces_one_occurrence() -> void:
	var bag: StdBag = StdBag.from_array([1, 1, 2], _seeded())
	var result: StdResult = bag.mutate(func(value: int) -> int: return value + 10)
	assert_ok(result, "mutate succeeds")
	var replacement: int = result.unwrap()
	assert_true(replacement == 11 or replacement == 12, "mutate returns the replacement")
	assert_eq(bag.count(replacement), 1, "mutate adds one new occurrence")
	assert_eq(bag.items(), 3, "mutate preserves total occurrences")
	return


func _test_map_and_filter_preserve_occurrences() -> void:
	var bag: StdBag = StdBag.from_array([1, 1, 2, 3], _seeded())
	var mapped: StdBag = bag.map(func(value: int) -> int: return value % 2).unwrap() as StdBag
	assert_eq(mapped.count(1), 3, "map combines equal results")
	assert_eq(mapped.count(0), 1, "map keeps the even result")
	assert_eq(bag.count(1), 2, "map leaves duplicate source values unchanged")
	assert_eq(bag.count(2), 1, "map leaves unique source values unchanged")
	assert_eq(bag.count(3), 1, "map leaves every source value unchanged")

	var filtered: StdBag = bag.filter(func(value: int) -> bool: return value < 3).unwrap() as StdBag
	assert_eq(filtered.count(1), 2, "filter keeps duplicate accepted occurrences")
	assert_eq(filtered.count(2), 1, "filter keeps unique accepted occurrences")
	assert_eq(filtered.count(3), 0, "filter removes rejected occurrences")
	assert_eq(filtered.items(), 3, "filter preserves duplicate counts")
	assert_err(bag.map(Callable()), "map rejects an invalid mapper")
	assert_err(bag.filter(Callable()), "filter rejects an invalid predicate")
	return


func _test_deterministic_stress_matches_counts() -> void:
	var rng: RandomNumberGenerator = _seeded(0xB46)
	var bag: StdBag = StdBag.new(_seeded(0xB46))
	var reference: Dictionary = {}
	var total: int = 0
	for step: int in range(2500):
		var value: int = rng.randi_range(-20, 20)
		if rng.randi_range(0, 2) == 0 and total > 0:
			var removed: int = bag.pop().unwrap()
			reference[removed] = int(reference.get(removed, 0)) - 1
			if reference[removed] == 0:
				reference.erase(removed)
			total -= 1
		else:
			bag.push(value)
			reference[value] = int(reference.get(value, 0)) + 1
			total += 1
		assert_eq(bag.items(), total, "stress total matches reference")
		assert_eq(bag.size(), reference.size(), "stress unique size matches reference")
		for key: Variant in reference:
			assert_eq(bag.count(key), reference[key], "stress occurrence count matches reference")
			pass
		pass
	return


func _test_clear_and_dictionary_snapshot() -> void:
	var bag: StdBag = StdBag.from_array([1, 1, 2], _seeded())
	var snapshot: Array = bag.to_array()
	snapshot.clear()
	assert_eq(bag.count(1), 2, "array snapshot cannot mutate the Bag")

	bag.clear()
	assert_true(bag.is_empty(), "clear empties the Bag")
	assert_eq(bag.size(), 0, "clear removes unique values")
	assert_eq(bag.items(), 0, "clear removes every occurrence")
	return
