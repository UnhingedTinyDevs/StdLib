# StdHeap

[← StdCollections](../StdCollections.md)

**Inherits:** `IStdPriorityCollection` → `IStdPop` → `IStdCollection` → `RefCounted`

A stable binary min-heap or max-heap for values with integer priorities.

## Description

`StdHeap` returns the lowest or highest integer priority first according to [`Order`](#enum-order). Values with
the same priority leave in insertion order. Changing a root value with `mutate()` does not change its priority.

Heap indices describe the current internal array layout. They are useful for inspection, but are not stable
handles: any `push()` or `pop()` can move nodes.

## Example usage

```gdscript
var work: StdHeap = StdHeap.new(StdHeap.Order.MIN)
work.push("background", 100)
work.push("input", 1)
work.push("physics", 10)

work.peek() # some("input")
work.pop()  # some("input")
```

## Signals

| Signal | Description |
|---|---|
| `pushed(item: Variant, priority: int)` | Emitted after a value is inserted. |
| `popped(item: Variant)` | Emitted after the root value is removed. |
| `mutated(new: Variant, old: Variant)` | Emitted after `mutate()` replaces the root value. |
| `cleared()` | Emitted after `clear()`. |
| `size_changed(size: int)` | Emitted after push, pop, or clear. |

## Enumerations

### enum Order

| Value | Description |
|---|---|
| `MIN` | Lower priorities leave first. |
| `MAX` | Higher priorities leave first. |

## Properties

This class exposes no public properties. Values, priorities, and stable-tie sequence numbers are stored in
private `StdHeapNode` records.

## Methods

| Return type | Method |
|---|---|
| `StdHeap` | `StdHeap(order: Order = Order.MIN)` |
| `void` | `push(value: Variant, priority: int)` |
| `StdOption` | `pop()` |
| `StdOption` | `peek()` |
| `StdResult` | `mutate(mutator: Callable)` |
| `bool` | `has(item: Variant)` |
| `int` | `size()` |
| `bool` | `is_empty()` |
| `void` | `clear()` |
| `StdResult` | `map(fn: Callable)` |
| `StdResult` | `map_in_place(fn: Callable)` |
| `StdResult` | `filter(pred: Callable)` |
| `StdResult` | `filter_in_place(pred: Callable)` |
| `StdResult` | `parent_node(index: int)` |
| `StdResult` | `left_node(index: int)` |
| `StdResult` | `right_node(index: int)` |
| `StdResult` | `parent_priority(index: int)` |
| `StdResult` | `left_priority(index: int)` |
| `StdResult` | `right_priority(index: int)` |
| `StdResult` | `parent_value(index: int)` |
| `StdResult` | `left_value(index: int)` |
| `StdResult` | `right_value(index: int)` |

## Method descriptions

### `StdHeap(order: Order = Order.MIN)`

Creates an empty heap with the requested ordering policy.

### `push(value: Variant, priority: int) -> void`

Inserts `value` in O(log n). Equal-priority values retain insertion order.

### `pop() -> StdOption`

Removes and returns the root in O(log n), or `none` when empty.

### `peek() -> StdOption`

Returns the root without removing it in O(1), or `none` when empty.

### `mutate(mutator: Callable) -> StdResult`

Replaces the root value with `mutator.call(old_value)` while preserving its priority and tie order. Returns
`err` when empty or when the callable is invalid.

### `has(item: Variant) -> bool`

Returns whether an equal value exists. This scans values in O(n); priorities are ignored.

### `size() -> int`, `is_empty() -> bool`

Return the number of values and whether that number is zero. Both are O(1).

### `clear() -> void`

Removes all values and resets equal-priority insertion sequencing.

### `map(fn: Callable) -> StdResult`

Returns a new heap whose values are mapped through `fn`. Priorities, order policy, and tie order are preserved.
Returns `err` for an invalid callable.

### `map_in_place(fn: Callable) -> StdResult`

Maps values in this heap without changing priorities. Returns this heap in `ok`, or `err` for an invalid
callable. On a non-empty heap, `mutated` reports the root's mapped value and its previous value.

### `filter(pred: Callable) -> StdResult`

Returns a reheapified copy containing accepted values. Priorities and relative tie order are preserved. Returns
`err` for an invalid callable.

### `filter_in_place(pred: Callable) -> StdResult`

Removes rejected values from this heap and restores heap order. Returns this heap in `ok`, or `err` for an
invalid callable.

### `parent_node(index: int) -> StdResult`

Returns the parent `StdHeapNode`, or `err` if `index` is outside the heap or identifies the root.

### `left_node(index: int) -> StdResult`, `right_node(index: int) -> StdResult`

Return the requested child node, or `err` if the source index or child index is outside the heap.

### `parent_priority(index: int) -> StdResult`, `left_priority(index: int) -> StdResult`,
### `right_priority(index: int) -> StdResult`

Return the requested relative node's integer priority, forwarding the same bounds errors as the node methods.

### `parent_value(index: int) -> StdResult`, `left_value(index: int) -> StdResult`,
### `right_value(index: int) -> StdResult`

Return the requested relative node's value, forwarding the same bounds errors as the node methods.

## Testing

```sh
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-collections/tests/test_std_heap.gd
```
