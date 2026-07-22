# StdRedBlackTree

[← StdCollections](../StdCollections.md)

**Inherits:** `StdBinarySearchTree` → `IStdTreeCollection` → `IStdCollection` → `RefCounted`

A self-balancing comparator-ordered binary search tree.

## Description

`StdRedBlackTree` provides O(log n) lookup, insertion, and targeted removal. A comparator defines both ordering
and equality by returning a negative integer, zero, or a positive integer for two values.

Comparator-equal pushes share one physical node and increment an occurrence count. The first inserted value is
the representative returned for every equal occurrence. `size()` counts occurrences; `to_array()` repeats the
representative once per occurrence.

## Example usage

```gdscript
func compare_ints(first: Variant, second: Variant) -> int:
	return int(first) - int(second)

var scores: StdRedBlackTree = StdRedBlackTree.new(compare_ints)
scores.push(30)
scores.push(10)
scores.push(20)
scores.to_array() # [10, 20, 30]
scores.pop(20)    # some(20)
```

## Signals

| Signal | Description |
|---|---|
| `pushed(item: Variant)` | Emitted after each pushed occurrence. |
| `popped(item: Variant)` | Emitted after each successfully removed occurrence. |
| `cleared()` | Emitted after `clear()`. |
| `size_changed(size: int)` | Emitted after push, successful pop, or clear. |

## Enumerations

### enum Side

| Value | Description |
|---|---|
| `LEFT` | The left child side used by balancing operations. |
| `RIGHT` | The right child side used by balancing operations. |

`Side` is public for script documentation completeness, but ordinary callers do not need it.

## Constants

| Constant | Description |
|---|---|
| `RED` | Integer representation of `StdRedBlackTreeNode.NodeColor.RED`. |
| `BLACK` | Integer representation of `StdRedBlackTreeNode.NodeColor.BLACK`. |

## Properties

This class exposes no public properties. Tree nodes, child indices, free slots, and the comparator are private
implementation state inherited from `StdBinarySearchTree`.

## Methods

| Return type | Method |
|---|---|
| `StdRedBlackTree` | `StdRedBlackTree(compare: Callable)` |
| `void` | `push(item: Variant)` |
| `StdOption` | `pop(item: Variant)` |
| `StdOption` | `peek(item: Variant)` |
| `bool` | `has(item: Variant)` |
| `StdResult` | `map(fn: Callable)` |
| `StdResult` | `filter(pred: Callable)` |
| `int` | `size()` |
| `bool` | `is_empty()` |
| `void` | `clear()` |
| `StdRedBlackTree` | `from_array(from: Array, compare: Callable)` static |
| `Array` | `to_array()` |

## Method descriptions

### `StdRedBlackTree(compare: Callable)`

Creates an empty tree. `compare(first, second)` must return less than zero when `first` sorts before `second`,
zero when their keys are equal, and greater than zero when `first` sorts after `second`. The callable must be
valid, and every stored/query value must be compatible with it.

### `push(item: Variant) -> void`

Adds one occurrence in O(log n). Comparator-equal values increment the representative node's count.

### `pop(item: Variant) -> StdOption`

Removes one comparator-equal occurrence and returns the stored representative, or `none` when absent. The node
is deleted only after its last occurrence is removed.

### `peek(item: Variant) -> StdOption`

Returns the stored representative comparator-equal to `item` without removing it, or `none` when absent.

### `has(item: Variant) -> bool`

Returns whether a comparator-equal value exists in O(log n).

### `map(fn: Callable) -> StdResult`

Maps every occurrence and inserts mapped values into a new tree using the same comparator. Mapped values must be
compatible with that comparator. Invalid callables return `err`.

### `filter(pred: Callable) -> StdResult`

Returns accepted occurrences in a new tree with the same comparator. Invalid callables return `err`.

### `size() -> int`, `is_empty() -> bool`

Return the occurrence count and whether the tree has no occurrences. Both are O(1).

### `clear() -> void`

Removes every node and occurrence, resets reusable storage, and retains the comparator.

### `from_array(from: Array, compare: Callable) -> StdRedBlackTree` static

Creates a tree and pushes values in array order. Comparator-equal entries become occurrences of the first
representative.

### `to_array() -> Array`

Returns an independent in-order snapshot in O(n). Representatives are repeated according to occurrence count.

## Implementation notes

Index `0` is a shared black NIL sentinel for every missing child. Real nodes use integer array indices; deleted
slots are reused. `StdBinarySearchTree` supplies traversal and storage, while `StdRedBlackTree` supplies rotations
and insertion/deletion fixups. These details are internal and should not be used as application state.

## Testing

```sh
scripts/run-tests addons/std_lib/std-collections/tests/test_std_red_black_tree.gd
```
