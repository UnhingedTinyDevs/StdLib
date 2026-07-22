# StdQueue

[← StdCollections](../StdCollections.md)

**Inherits:** `IStdPushCollection` → `IStdPop` → `IStdCollection` → `RefCounted`

An amortized O(1) first-in, first-out queue.

## Description

`push()` adds at the back; `peek()` and `pop()` read the front. Consumed backing slots are compacted
periodically, avoiding the O(n) cost of shifting the array on every pop. Array conversions are front-to-back.

## Example usage

```gdscript
var jobs: StdQueue = StdQueue.new()
jobs.push("walk")
jobs.push("talk")
jobs.pop() # some("walk")
```

## Signals

| Signal | Description |
|---|---|
| `pushed(item: Variant)` | Emitted after `push()`. |
| `popped(item: Variant)` | Emitted after a successful `pop()`. |
| `mutated(new: Variant, old: Variant)` | Emitted after `mutate()`. |
| `cleared()` | Emitted only when `clear()` is called. |
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
| `StdResult` | `map(mapper: Callable)` |
| `StdResult` | `filter(predicate: Callable)` |
| `int` | `size()` |
| `bool` | `is_empty()` |
| `void` | `clear()` |
| `StdQueue` | `from_array(from: Array)` static |
| `Array` | `to_array()` |

## Method descriptions

### `push(value: Variant) -> void`

Adds `value` at the back in amortized O(1).

### `pop() -> StdOption`

Removes and returns the front in amortized O(1), or `none` when empty.

### `peek() -> StdOption`

Returns the front without removing it in O(1), or `none` when empty.

### `mutate(mutator: Callable) -> StdResult`

Replaces the front with `mutator.call(old_value)`. Returns `err` when empty or when the callable is invalid.

### `has(value: Variant) -> bool`

Returns whether an equal live value exists in O(n). Consumed backing slots are ignored.

### `map(mapper: Callable) -> StdResult`, `filter(predicate: Callable) -> StdResult`

Return a new queue in the same front-to-back order. Invalid callables return `err`; the source is unchanged.

### `size() -> int`, `is_empty() -> bool`

Return the live value count and whether it is zero. Consumed backing slots are not counted.

### `clear() -> void`

Removes live and consumed slots and resets the queue for reuse.

### `from_array(from: Array) -> StdQueue` static

Creates a queue whose front is `from[0]`. The input array is copied.

### `to_array() -> Array`

Returns an independent front-to-back snapshot containing only live values.

## Testing

```sh
scripts/run-tests addons/std_lib/std-collections/tests/test_std_queue.gd
```
