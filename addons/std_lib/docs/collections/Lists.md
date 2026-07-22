# Linked lists

[← StdCollections](../StdCollections.md)

Head-to-tail linked collections with constant-time end operations.

## Description

All three lists inherit size and empty-state behavior from `StdLinkedListBase`:

| Class | Inherits | Best use |
|---|---|---|
| `StdSinglyLinkedList` | `StdLinkedListBase` | O(1) head removal with minimal link storage. |
| `StdDoublyLinkedList` | `IStdDoubleEndedListCollection` | O(1) removal from either end. |
| `StdCircularLinkedList` | `IStdDoubleEndedListCollection` | A rotatable doubly linked ring. |

Arrays and traversal always begin at the current head. None of the classes expose their internal link nodes as
public properties.

## Example usage

```gdscript
var turns: StdCircularLinkedList = StdCircularLinkedList.from_array(["red", "blue", "green"])
turns.head() # some("red")
turns.rotate_left()
turns.head() # some("blue")
```

## Signals

| Signal | Description |
|---|---|
| `head_pushed(item: Variant)` | Emitted after insertion at the head. |
| `tail_pushed(item: Variant)` | Emitted after insertion at the tail. |
| `head_popped(item: Variant)` | Emitted after successful head removal. |
| `tail_popped(item: Variant)` | Emitted after successful tail removal; doubly linked classes only. |
| `cleared()` | Emitted after `clear()`. |
| `size_changed(size: int)` | Emitted after insertion, removal, or clear. |

## Enumerations

The list classes define no enumerations.

## Properties

The list classes expose no public properties.

## StdSinglyLinkedList methods

| Return type | Method |
|---|---|
| `StdOption` | `head()` |
| `StdOption` | `tail()` |
| `void` | `push_head(item: Variant)` |
| `void` | `push_tail(item: Variant)` |
| `StdOption` | `pop_head()` |
| `bool` | `has(item: Variant)` |
| `StdResult` | `map(fn: Callable)` |
| `StdResult` | `filter(pred: Callable)` |
| `int` | `size()` |
| `bool` | `is_empty()` |
| `void` | `clear()` |
| `StdSinglyLinkedList` | `from_array(from: Array)` static |
| `Array` | `to_array()` |

`StdSinglyLinkedList` intentionally has no `pop_tail()`: tail removal would require an O(n) predecessor walk.

## StdDoublyLinkedList methods

`StdDoublyLinkedList` provides every singly linked method above, with `from_array()` returning a
`StdDoublyLinkedList`, plus:

| Return type | Method |
|---|---|
| `StdOption` | `pop_tail()` |

## StdCircularLinkedList methods

`StdCircularLinkedList` provides every doubly linked public method, with `from_array()` returning a
`StdCircularLinkedList`, plus:

| Return type | Method |
|---|---|
| `void` | `rotate_left(steps: int = 1)` |
| `void` | `rotate_right(steps: int = 1)` |

## Method descriptions

### `head() -> StdOption`, `tail() -> StdOption`

Return the value at the requested end without removing it, or `none` when empty. Both are O(1).

### `push_head(item: Variant) -> void`, `push_tail(item: Variant) -> void`

Insert at the requested end in O(1).

### `pop_head() -> StdOption`

Removes and returns the head in O(1), or `none` when empty. Removing the last value resets both logical ends.

### `pop_tail() -> StdOption`

On doubly linked and circular lists, removes and returns the tail in O(1), or `none` when empty.

### `has(item: Variant) -> bool`

Returns whether an equal value exists in O(n). Circular traversal is bounded to exactly `size()` nodes.

### `map(fn: Callable) -> StdResult`

Returns a new list of the same concrete type with values mapped in head-to-tail order. Invalid callables return
`err`; the source is unchanged.

### `filter(pred: Callable) -> StdResult`

Returns a new list of the same concrete type containing accepted values in head-to-tail order. Invalid callables
return `err`; the source is unchanged.

### `size() -> int`, `is_empty() -> bool`

Return the number of linked values and whether that count is zero. Both are O(1).

### `clear() -> void`

Breaks all links, empties the list, and leaves it reusable. This is O(n).

### `from_array(from: Array)` static

Creates the concrete list in array order, where `from[0]` becomes the head.

### `to_array() -> Array`

Returns an independent head-to-tail snapshot. Circular lists walk the ring exactly once.

### `rotate_left(steps: int = 1) -> void`

Circular list only. Advances the head by `steps`, wrapping by size. Negative steps rotate right. Empty lists are
unchanged.

### `rotate_right(steps: int = 1) -> void`

Circular list only. Moves the head backward by `steps`. Negative steps rotate left.

## Testing

```sh
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-collections/tests/test_std_singly_linked_list.gd
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-collections/tests/test_std_doubly_linked_list.gd
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-collections/tests/test_std_circular_linked_list.gd
```
