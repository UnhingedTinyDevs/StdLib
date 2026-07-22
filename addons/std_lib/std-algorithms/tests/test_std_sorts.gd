extends StdTest
## Headless tests for StdSorts.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-algorithms


class Comparator:
	extends Node

	func less_than(a: Variant, b: Variant) -> bool:
		return a < b


func _sorts() -> Dictionary:
	return {
		"merge_sort": StdSorts.merge_sort,
		"insertion_sort": StdSorts.insertion_sort,
	}


func _test_happy_paths() -> void:
	var asc: Callable = StdCmp.less_than()
	var desc: Callable = func(a: Variant, b: Variant) -> bool: return a > b
	for name: String in _sorts():
		var sort: Callable = _sorts()[name]
		var arr: Array = [3, 1, 2]
		sort.call(arr, asc)
		assert_eq(arr, [1, 2, 3], "%s: ints" % name)
		arr = [5, 4, 3, 2, 1]
		sort.call(arr, asc)
		assert_eq(arr, [1, 2, 3, 4, 5], "%s: reverse" % name)
		arr = [2, 1, 2, 1]
		sort.call(arr, asc)
		assert_eq(arr, [1, 1, 2, 2], "%s: duplicates" % name)
		arr = ["b", "a", "c"]
		sort.call(arr, asc)
		assert_eq(arr, ["a", "b", "c"], "%s: strings" % name)
		arr = [0.5, -3.25, 2.0, -0.75]
		sort.call(arr, asc)
		assert_eq(arr, [-3.25, -0.75, 0.5, 2.0], "%s: floats with negatives" % name)
		arr = [1, 3, 2]
		sort.call(arr, desc)
		assert_eq(arr, [3, 2, 1], "%s: custom cmp descending" % name)
		var original: Array = [9, 8]
		var alias: Array = original
		var res: StdResult = sort.call(original, asc)
		assert_eq(alias, [8, 9], "%s: sorts in place" % name)
		assert_ok(res, "%s: returns ok" % name)
		assert_true(res.is_ok() and res.unwrap() == original, "%s: ok wraps the same array" % name)
		pass
	return


func _test_edge_cases() -> void:
	var asc: Callable = StdCmp.less_than()
	for name: String in _sorts():
		var sort: Callable = _sorts()[name]
		var arr: Array = []
		sort.call(arr, asc)
		assert_eq(arr, [], "%s: empty" % name)
		arr = [7]
		sort.call(arr, asc)
		assert_eq(arr, [7], "%s: single" % name)
		arr = [1, 2, 3]
		sort.call(arr, asc)
		assert_eq(arr, [1, 2, 3], "%s: already sorted" % name)
		arr = [5, 5, 5]
		sort.call(arr, asc)
		assert_eq(arr, [5, 5, 5], "%s: all equal" % name)
		pass
	return


func _test_stability() -> void:
	var by_k: Callable = func(a: Dictionary, b: Dictionary) -> bool: return a.k < b.k
	for name: String in _sorts():
		var sort: Callable = _sorts()[name]
		var arr: Array = [
			{"k": 2, "id": 0}, {"k": 1, "id": 1}, {"k": 2, "id": 2}, {"k": 1, "id": 3},
		]
		sort.call(arr, by_k)
		var ids: Array = arr.map(func(d: Dictionary) -> int: return d.id)
		assert_eq(ids, [1, 3, 0, 2], "%s: stable on equal keys" % name)
		pass
	return


func _test_merge_path_stability() -> void:
	var by_k: Callable = func(a: Dictionary, b: Dictionary) -> bool: return a.k < b.k
	var arr: Array = []
	for id: int in range(24):
		arr.append({"k": id % 4, "id": id})
		pass

	var res: StdResult = StdSorts.merge_sort(arr, by_k)
	var ids: Array = arr.map(func(d: Dictionary) -> int: return d.id)
	var expected: Array = [
		0, 4, 8, 12, 16, 20,
		1, 5, 9, 13, 17, 21,
		2, 6, 10, 14, 18, 22,
		3, 7, 11, 15, 19, 23,
	]
	assert_ok(res, "merge_sort: merge path returns ok")
	assert_eq(ids, expected, "merge_sort: merge path is sorted and stable")
	return


func _test_invalid_comparator() -> void:
	var comparator: Comparator = Comparator.new()
	var freed: Callable = Callable(comparator, "less_than")
	comparator.free()

	for name: String in _sorts():
		var sort: Callable = _sorts()[name]
		var arr: Array = [2, 1, 3]
		var res: StdResult = sort.call(arr, Callable())
		assert_err(res, "%s: empty cmp errs" % name)
		assert_eq(res.unwrap_err(), "cmp is not a valid Callable", "%s: empty cmp error" % name)
		assert_eq(arr, [2, 1, 3], "%s: empty cmp leaves array untouched" % name)
		arr = [2, 1, 3]
		res = sort.call(arr, freed)
		assert_err(res, "%s: freed cmp errs" % name)
		assert_eq(arr, [2, 1, 3], "%s: freed cmp leaves array untouched" % name)
		pass
	return
