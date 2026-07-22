# StdCollections

[← StdLib](../StdLib.md)

Reusable stacks, queues, heaps, sets, graphs, bags, trees, linked lists, and object pools for GDScript.

## Description

StdCollections provides `RefCounted` data structures with explicit empty and error handling. Methods that may
have no value return [`StdOption`](StdReturns.md); operations that can fail return `StdResult`. No collection uses
`null` to mean “not found.”

Choose a structure by the ordering guarantee your code needs:

| Structure | Ordering | Typical operation |
|---|---|---:|
| [`StdStack`](collections/Stack.md) | Last in, first out | O(1) push/pop |
| [`StdQueue`](collections/Queue.md) | First in, first out | Amortized O(1) push/pop |
| [`StdHeap`](collections/Heap.md) | Integer priority; stable ties | O(log n) push/pop |
| [`StdSet`](collections/Set.md) | Unique, unordered values | Average O(1) membership |
| [`StdGraph`](collections/Graph.md) | Directed or undirected weighted edges | Average O(1) adjacency lookup |
| [`StdRedBlackTree`](collections/RedBlackTree.md) | Comparator order | O(log n) lookup/update |
| [Linked lists](collections/Lists.md) | Head-to-tail | O(1) end operations |
| [`StdBag`](collections/Bag.md) | Unordered, random removal | O(1) count; O(k) random selection |
| [`StdObjectPool`](collections/ObjectPool.md) | Reusable `Node` ownership | O(1) acquire/release |

## Example usage

```gdscript
var jobs: StdQueue = StdQueue.from_array(["load", "spawn", "start"])
var next_job: StdOption = jobs.pop()
if next_job.is_some():
	run_job(next_job.unwrap())

var urgent: StdHeap = StdHeap.new(StdHeap.Order.MIN)
urgent.push("autosave", 20)
urgent.push("disconnect", 1)
urgent.pop() # some("disconnect")
```

## Shared behavior

Value collections expose `size()`, `is_empty()`, `has()`, `clear()`, `map()`, and `filter()`. Transformations
return new collections and leave their source unchanged unless the method name ends in `_in_place`.

Array snapshots are independent from their source. Their order is part of the API for ordered structures:

- Queue and list index `0` is the front or head.
- Stack index `0` is the top and therefore the next value popped.
- Red-black tree snapshots follow the comparator.
- Set and Bag snapshots have no semantic order.
- Heap intentionally has no value-only array conversion because priorities would be lost.

`StdBag.size()` counts unique values; `StdBag.items()` counts occurrences. Every other value collection's
`size()` counts stored occurrences.

## Signals

Signals are defined by the collection interfaces and documented on each concrete type. Mutation signals emit
only for successful operations. `size_changed` reports the value returned by that collection's `size()`.

## Testing

Run the complete module suite:

```sh
scripts/run-tests -m std-collections
```

The suite includes deterministic model-based stress tests, boundary checks, empty-state behavior, signal
contracts, ordering, duplicate handling, tree invariants, and object-pool ownership.
