# StdObjectPool

[← StdCollections](../StdCollections.md)

**Inherits:** `RefCounted`

A fixed-capacity owner of reusable `Node` instances.

## Description

`StdObjectPool` creates Nodes through a factory and cycles them between active and available states. Acquiring an
available Node avoids repeated allocation. Releasing a Node detaches it from its parent, optionally resets it,
and makes it available again.

The pool is a lifecycle manager, not a value collection. It deliberately has no map, filter, or array conversion
methods.

## Example usage

```gdscript
var bullets: StdObjectPool = StdObjectPool.new(
	func() -> Node: return bullet_scene.instantiate(),
	32,
	8,
	func(bullet: Node) -> void: bullet.hide(),
)

var acquired: StdResult = bullets.acquire()
if acquired.is_ok():
	add_child(acquired.unwrap())
```

## Signals

| Signal | Description |
|---|---|
| `object_requested(obj: Node)` | Emitted after a successful acquire. |
| `object_released(obj: Node)` | Emitted after a successful release. |
| `pool_exhausted()` | Emitted when acquire fails because capacity is exhausted. |

## Enumerations

This class defines no enumerations.

## Properties

This class exposes no public properties.

## Methods

| Return type | Method |
|---|---|
| `StdObjectPool` | `StdObjectPool(factory: Callable, max_size: int, prefill: int = 0, reset: Callable = Callable())` |
| `StdResult` | `acquire()` |
| `StdResult` | `release(node: Variant)` |
| `bool` | `has(node: Variant)` |
| `int` | `active_count()` |
| `int` | `available_count()` |
| `int` | `size()` |
| `int` | `capacity()` |
| `bool` | `is_empty()` |
| `bool` | `is_exhausted()` |
| `StdResult` | `clear()` |
| `void` | `destroy()` |
| `int` | `prune_invalid()` |

## Method descriptions

### `StdObjectPool(factory, max_size, prefill = 0, reset = Callable())`

Creates a pool whose zero-argument `factory` must return a live `Node`. Negative capacity and prefill values are
clamped to zero. Prefill above capacity is clamped with a warning. The optional `reset` receives a Node during
release before it becomes available.

### `acquire() -> StdResult`

Returns an available or newly created Node in `ok`. Returns `err` when exhausted or when the factory is invalid,
returns a non-Node, or returns a freed Node.

### `release(node: Variant) -> StdResult`

Returns an active Node to the pool. The reset callable runs first, then the Node is detached from its parent.
Returns `err` for null, freed, non-Node, foreign, or already-released values.

### `has(node: Variant) -> bool`

Returns whether the pool currently owns the live Node in either state. Invalid values return `false`.

### `active_count() -> int`, `available_count() -> int`

Return checked-out and ready-to-acquire counts after pruning externally freed Nodes.

### `size() -> int`, `capacity() -> int`

`size()` is active plus available Nodes. `capacity()` is the fixed ownership ceiling.

### `is_empty() -> bool`

Returns whether the pool owns no live Nodes. A pool with no available Nodes may still be non-empty because its
Nodes are active.

### `is_exhausted() -> bool`

Returns whether the next acquire would fail because no Node is available and size has reached capacity.

### `clear() -> StdResult`

Frees every available Node and returns the count in `ok`. If any Nodes are active, returns `err` without changing
the pool.

### `destroy() -> void`

Destructively frees every active and available Node. Caller-held references become invalid.

### `prune_invalid() -> int`

Removes Nodes freed externally from the active and available bookkeeping and returns the number removed.

## Pool destruction

When the pool itself is released, available Nodes are freed. Active Nodes remain alive and are released from the
pool's ownership with a warning; the caller becomes solely responsible for them.

## Testing

```sh
scripts/run-tests addons/std_lib/std-collections/tests/test_std_object_pool.gd
```
