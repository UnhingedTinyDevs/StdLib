# StdSet

[← StdCollections](../StdCollections.md)

**Inherits:** `IStdCollection` → `RefCounted`

An unordered collection of unique values with optional caller-defined identity keys.

## Description

By default, values use Godot `Dictionary` key equality. An identifier callable can instead map each value to a
stable membership key. The first value inserted for a key is retained; later equivalent pushes do nothing.

Set arithmetic uses the receiver's identifier to normalize both sets. Values in the operand must therefore be
compatible with the receiver's identifier. Results retain the receiver's identifier.

## Example usage

```gdscript
var visited: StdSet = StdSet.new()
visited.push(Vector2i(4, 2))
visited.push(Vector2i(4, 2))
visited.size() # 1

var actors: StdSet = StdSet.new(func(actor: Actor) -> int: return actor.id)
actors.push(player)
```

## Signals

| Signal | Description |
|---|---|
| `item_pushed(item: Variant)` | Emitted after a new key is inserted. |
| `item_popped(item: Variant)` | Emitted after a successful `pop()`. |
| `cleared()` | Emitted after `clear()`. |
| `size_changed(size: int)` | Emitted when membership changes or stale objects are pruned. |

## Enumerations

This class defines no enumerations.

## Properties

This class exposes no public properties. Stored membership keys must remain stable while their values are in the
Set.

## Methods

| Return type | Method |
|---|---|
| `StdSet` | `StdSet(identifier: Callable = Callable())` |
| `void` | `push(item: Variant)` |
| `StdOption` | `pop(item: Variant)` |
| `StdOption` | `peek(item: Variant)` |
| `bool` | `has(item: Variant)` |
| `void` | `clear()` |
| `int` | `size()` |
| `bool` | `is_empty()` |
| `StdResult` | `map(fn: Callable)` |
| `StdResult` | `filter(pred: Callable)` |
| `StdResult` | `union(other: StdSet)` |
| `StdResult` | `intersection(other: StdSet)` |
| `StdResult` | `difference(other: StdSet)` |
| `StdResult` | `symmetric_difference(other: StdSet)` |
| `bool` | `subset(other: StdSet)` |
| `bool` | `superset(other: StdSet)` |
| `bool` | `disjoint(other: StdSet)` |
| `bool` | `equals(other: StdSet)` |
| `StdSet` | `from_array(from: Array, identifier: Callable = Callable())` static |
| `Array` | `to_array()` |
| `Array` | `values()` |
| `int` | `prune_invalid()` |

## Method descriptions

### `StdSet(identifier: Callable = Callable())`

Creates an empty Set. A valid identifier receives each value and returns its membership key. Without one, the
value itself is the key.

### `push(item: Variant) -> void`

Adds `item` only if its key is absent. The first value for a key is retained.

### `pop(item: Variant) -> StdOption`

Removes and returns the originally stored value for `item`'s key, or `none` when absent.

### `peek(item: Variant) -> StdOption`

Returns the originally stored value for `item`'s key without removing it, or `none` when absent.

### `has(item: Variant) -> bool`

Returns whether `item`'s key is present. Average complexity is O(1) when the identifier is O(1).

### `clear() -> void`, `size() -> int`, `is_empty() -> bool`

Remove all membership, return the unique-value count, and test whether that count is zero.

### `map(fn: Callable) -> StdResult`

Maps values into a new Set using default value keys. Equal mapped results collapse. Invalid callables return
`err`.

### `filter(pred: Callable) -> StdResult`

Returns accepted values in a new Set that retains this Set's identifier. Invalid callables return `err`.

### `union(other: StdSet) -> StdResult`

Returns values present in either Set. When both contain the same receiver-normalized key, this Set's value wins.
`null` returns `err`.

### `intersection(other: StdSet) -> StdResult`

Returns this Set's values whose receiver-normalized keys also occur in `other`. `null` returns `err`.

### `difference(other: StdSet) -> StdResult`

Returns this Set's values whose receiver-normalized keys do not occur in `other`. `null` returns `err`.

### `symmetric_difference(other: StdSet) -> StdResult`

Returns values whose receiver-normalized keys occur in exactly one Set. `null` returns `err`.

### `subset(other: StdSet) -> bool`, `superset(other: StdSet) -> bool`

Compare containment after normalizing `other` with this Set's identifier. `null` returns `false`.

### `disjoint(other: StdSet) -> bool`, `equals(other: StdSet) -> bool`

Test for no shared keys or exactly equal keys under this Set's identifier. `null` returns `false`.

### `from_array(from: Array, identifier: Callable = Callable()) -> StdSet` static

Creates a Set from the array, keeping the first value for each key.

### `to_array() -> Array`, `values() -> Array`

Return independent snapshots of stored values. Order is not semantic.

### `prune_invalid() -> int`

Removes stored Object values or Object keys that were freed externally and returns the number removed. This is
an explicit O(n) cleanup; ordinary membership calls remain average O(1).

## Testing

```sh
scripts/run-tests addons/std_lib/std-collections/tests/test_std_set.gd
```
