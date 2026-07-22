class_name StdSorts
extends RefCounted
## A collection of sorting algorithms for the StdLib
##
## All sorts mutate [param array] in place and return [code]StdResult.ok(array)[/code]
## so calls can chain, or [code]StdResult.err(String)[/code] when [param cmp] is not
## a valid [Callable], in which case the array is left untouched. Comparison
## sorts require [param cmp]: [code]Callable(a, b) -> bool[/code] returning true
## if [code]a[/code] sorts before [code]b[/code] (same convention as
## [method Array.sort_custom]).

## Ranges at or below this size are sorted with insertion sort.

const INSERTION_SORT_SIZE: int = 20

#region Public API
## StdSorts [param array] using a stable merge sort.
static func merge_sort(array: Array, cmp: Callable) -> StdResult:
	if not cmp.is_valid():
		return StdResult.err("cmp is not a valid Callable")

	var buffer: Array = array.duplicate()
	_merge_sort_range(array, buffer, 0, array.size(), cmp)

	return StdResult.ok(array)


## StdSorts [param array] using a stable insertion sort.
static func insertion_sort(array: Array, cmp: Callable) -> StdResult:
	if not cmp.is_valid():
		return StdResult.err("cmp is not a valid Callable")

	_insertion_sort_range(array, 0, array.size(), cmp)

	return StdResult.ok(array)

#endregion Public API

#region Helpers
## StdSorts the half-open range [param start] to [param end].
static func _merge_sort_range(
	array: Array,
	buffer: Array,
	start: int,
	end: int,
	cmp: Callable,
) -> void:
	var length := end - start
	if length <= 1:
		return

	if length <= INSERTION_SORT_SIZE:
		_insertion_sort_range(array, start, end, cmp)
		return

	var middle := start + (length >> 1)
	_merge_sort_range(array, buffer, start, middle, cmp)
	_merge_sort_range(array, buffer, middle, end, cmp)
	_merge(array, buffer, start, middle, end, cmp)

	for index in range(start, end):
		array[index] = buffer[index]


## Merges the sorted ranges [start, middle) and [middle, end).
static func _merge(
	array: Array,
	buffer: Array,
	start: int,
	middle: int,
	end: int,
	cmp: Callable,
) -> void:
	var left := start
	var right := middle

	for output in range(start, end):
		if left >= middle:
			buffer[output] = array[right]
			right += 1
		elif right >= end:
			buffer[output] = array[left]
			left += 1
		elif cmp.call(array[right], array[left]):
			buffer[output] = array[right]
			right += 1
		else:
			# Prefer the left value when equal to keep the sort stable.
			buffer[output] = array[left]
			left += 1


## StdSorts the half-open range [param start] to [param end].
static func _insertion_sort_range(
	array: Array,
	start: int,
	end: int,
	cmp: Callable,
) -> void:
	for index in range(start + 1, end):
		var value: Variant = array[index]
		var position := index

		while position > start and cmp.call(value, array[position - 1]):
			array[position] = array[position - 1]
			position -= 1

		array[position] = value

#endregion
