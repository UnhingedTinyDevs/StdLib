# StdStack

[← StdCollections](../StdCollections.md)

**Inherits:** `IStdPushCollection` → `IStdPop` → `IStdCollection` → `RefCounted`

A last-in, first-out collection.

## Description

`push()` adds to the top; `peek()` and `pop()` read the top. Array conversions use pop order, so index `0` is
the top. Push, pop, peek, size, and empty checks are O(1).

## Example usage

```gdscript
var undo: StdStack = StdStack.new()
undo.push("move")
undo.push("rotate")
undo.pop() # some("rotate")
```

## Signals

| Signal | Description |
|---|---|
| `pushed(item: Variant)` | Emitted after `push()`. |
| `popped(item: Variant)` | Emitted after a successful `pop()`. |
| `mutated(new: Variant, old: Variant)` | Emitted after `mutate()`. |
| `cleared()` | Emitted after `clear()`. |
| `size_changed(size: int)` | Emitted after push, pop, or clear. |

## Enumerations

This class defines no enumerations.

## Properties

This class exposes no public properties.

## Methods

| Return type | Method |
|---|---|
| `void` | `push(value: Variant)` |
| `StdOption` | `pop()` |
| `StdOption` | `peek()` |
| `StdResult` | `mutate(mutator: Callable)` |
| `bool` | `has(value: Variant)` |
| `StdResult` | `map(fn: Callable)` |
| `StdResult` | `filter(pred: Callable)` |
| `int` | `size()` |
| `bool` | `is_empty()` |
| `void` | `clear()` |
| `StdStack` | `from_array(from: Array)` static |
| `Array` | `to_array()` |

## Method descriptions

### `push(value: Variant) -> void`

Adds `value` to the top in O(1).

### `pop() -> StdOption`

Removes and returns the top in O(1), or `none` when empty.

### `peek() -> StdOption`

Returns the top without removing it in O(1), or `none` when empty.

### `mutate(mutator: Callable) -> StdResult`

Replaces the top with `mutator.call(old_value)`. Returns the replacement in `ok`, or `err` when empty or the
callable is invalid.

### `has(value: Variant) -> bool`

Returns whether an equal value exists in O(n).

### `map(fn: Callable) -> StdResult`, `filter(pred: Callable) -> StdResult`

Return a new stack in the same pop order. Invalid callables return `err`; the source is unchanged.

### `size() -> int`, `is_empty() -> bool`

Return the number of values and whether the stack is empty.

### `clear() -> void`

Removes every value and leaves the stack reusable.

### `from_array(from: Array) -> StdStack` static

Creates a stack whose top is `from[0]`. The input array is copied.

### `to_array() -> Array`

Returns an independent top-to-bottom snapshot.

## Testing

```sh
scripts/run-tests addons/std_lib/std-collections/tests/test_std_stack.gd
```
