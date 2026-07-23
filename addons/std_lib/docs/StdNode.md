# Std Node

[← StdLib](../../../README.md)

Small helpers for typed node-tree queries, clearing a node's children, and
checking whether a node is still usable.

```gdscript
var cameras: Array[Node] = StdNode.children_of(self, Camera2D)
var player: StdOption = StdNode.ancestor_of(self, Player)
var _cleared: StdResult = StdNode.queue_free_children(container)
```

`StdNode` is a static utility class and should not be instantiated.

## Type matching

The query methods accept a native class or a `Script` and use
`is_instance_of`, so subclasses match too:

```gdscript
var bodies: Array[Node] = StdNode.children_of(self, CharacterBody2D)
var states: Array[Node] = StdNode.children_of(self, preload("res://state.gd"))
```

Queries inspect non-internal children, matching `Node.get_children()`'s default
behavior. Invalid or dead starting nodes return an empty array or `none`.

## API

### `children_of`

```gdscript
static func children_of(parent: Node, type: Variant) -> Array[Node]
```

Returns every direct, non-internal child matching `type`. The array is empty
when the parent is not alive or no child matches.

### `first_child_of`

```gdscript
static func first_child_of(parent: Node, type: Variant) -> StdOption
```

Returns the first direct, non-internal child matching `type`, or `none`.

### `descendants_of`

```gdscript
static func descendants_of(parent: Node, type: Variant) -> Array[Node]
```

Returns every matching, non-internal descendant. The starting parent is never
included, and result order is not guaranteed.

### `ancestor_of`

```gdscript
static func ancestor_of(node: Node, type: Variant) -> StdOption
```

Walks upward and returns the nearest matching ancestor, or `none`. The starting
node is never returned.

### `queue_free_children`

```gdscript
static func queue_free_children(parent: Node) -> StdResult
```

Calls `queue_free()` on every non-internal child. Returns `err` when the parent
is null, freed, or already queued for deletion.

### `is_alive`

```gdscript
static func is_alive(node: Variant) -> bool
```

Returns `true` when `node` is a valid `Node` that is not queued for deletion.
Unlike `is_instance_valid`, it rejects a node during the interval between
`queue_free()` and the end of the frame.

## Native deferred mutations

Godot already exposes typed deferred calls, so StdNode does not wrap them:

```gdscript
parent.add_child.call_deferred(child)
parent.remove_child.call_deferred(child)
child.reparent.call_deferred(new_parent)
```

## Testing

```text
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- addons/std_lib/std-node
```

## See also

- [StdReturns](StdReturns.md) — `StdResult` and `StdOption`.
- [StdSignals](StdSignals.md) — guarded signal connection helpers.
