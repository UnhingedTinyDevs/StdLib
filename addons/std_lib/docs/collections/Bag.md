# StdBag

[← StdCollections](../StdCollections.md)

**Inherits:** `IStdPushCollection` → `IStdPop` → `IStdCollection` → `RefCounted`

An unordered multiset with occurrence-weighted random removal.

## Description

Unlike `StdSet`, a Bag retains duplicates. `pop()` chooses one occurrence using the supplied
`RandomNumberGenerator`, so an item stored three times is three times as likely to be selected as an item stored
once. The selected occurrence is removed.

`size()` is the number of unique values. `items()` is the total occurrence count. Snapshot order is not
semantic and must not be used to predict random draws.

## Example usage

```gdscript
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
rng.seed = 42
var loot: StdBag = StdBag.from_array(["coin", "coin", "potion"], rng)
loot.count("coin") # 2
loot.pop()         # one weighted random occurrence
```

## Signals

| Signal | Description |
|---|---|
| `pushed(item: Variant)` | Emitted once per added occurrence. |
| `popped(item: Variant)` | Emitted once per removed occurrence. |
| `mutated(new: Variant, old: Variant)` | Emitted when `mutate()` replaces one occurrence. |
| `cleared()` | Emitted after `clear()`. |
| `size_changed(size: int)` | Emitted when the unique-value count changes. |

## Enumerations

This class defines no enumerations.

## Properties

This class exposes no public properties. The generator is supplied during construction and retained privately.

## Methods

| Return type | Method |
|---|---|
| `StdBag` | `StdBag(rng: RandomNumberGenerator)` |
| `void` | `push(item: Variant)` |
| `void` | `push_n(item: Variant, n: int = 1)` |
| `StdOption` | `pop()` |
| `StdOption` | `pop_item(item: Variant)` |
| `int` | `pop_all(item: Variant)` |
| `StdOption` | `peek()` |
| `StdResult` | `mutate(mutator: Callable)` |
| `bool` | `has(item: Variant)` |
| `int` | `count(item: Variant)` |
| `int` | `size()` |
| `int` | `items()` |
| `bool` | `is_empty()` |
| `void` | `clear()` |
| `StdResult` | `map(fn: Callable)` |
| `StdResult` | `filter(pred: Callable)` |
| `StdBag` | `from_array(from: Array, rng: RandomNumberGenerator)` static |
| `Array` | `to_array()` |

## Method descriptions

### `StdBag(rng: RandomNumberGenerator)`

Creates an empty Bag. `rng` is required and controls every random selection.

### `push(item: Variant) -> void`

Adds one occurrence in average O(1).

### `push_n(item: Variant, n: int = 1) -> void`

Adds `n` occurrences. Non-positive values are a no-op.

### `pop() -> StdOption`

Removes one occurrence selected with count weighting, or returns `none` when empty. Selection is O(k), where
`k` is the unique-value count.

### `pop_item(item: Variant) -> StdOption`

Removes and returns one equal occurrence, or `none` when absent.

### `pop_all(item: Variant) -> int`

Removes all equal occurrences and returns the number removed. Missing values return `0`.

### `peek() -> StdOption`

Returns an expanded snapshot containing each occurrence, or `none` when empty. It does not select the next
random value.

### `mutate(mutator: Callable) -> StdResult`

Selects one weighted random occurrence, removes it, and adds `mutator.call(old_value)`. Total occurrences remain
constant. Returns `err` when empty or when the callable is invalid.

### `has(item: Variant) -> bool`, `count(item: Variant) -> int`

Report whether at least one equal occurrence exists and how many exist. Missing counts are `0`.

### `size() -> int`, `items() -> int`, `is_empty() -> bool`

Return unique values, total occurrences, and whether there are no occurrences.

### `clear() -> void`

Removes every occurrence.

### `map(fn: Callable) -> StdResult`, `filter(pred: Callable) -> StdResult`

Return independent Bags and call the function once per occurrence. Mapped equal values combine under one count.
Derived Bags copy the source generator state, so future draws are independent. Invalid callables return `err`.

### `from_array(from: Array, rng: RandomNumberGenerator) -> StdBag` static

Creates a Bag containing one occurrence per array entry.

### `to_array() -> Array`

Returns an independent expanded snapshot. Its order is not semantic.

## Testing

```sh
scripts/run-tests addons/std_lib/std-collections/tests/test_std_bag.gd
```
