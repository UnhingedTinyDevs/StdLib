@abstract
class_name IStdCollection
extends RefCounted
## Abstract base for value collections.
##
## Defines shared inspection, transformation, and lifecycle operations. Concrete
## collections decide how values are ordered and whether duplicates are retained.

## Emitted after all values are removed from the collection.
signal cleared
## Emitted when the value returned by [method size] changes.
signal size_changed(size: int)


## Returns [code]true[/code] if the collection contains [param item].
@abstract func has(item: Variant) -> bool
## Removes all values from the collection.
@abstract func clear() -> void
## Returns [code]true[/code] if the collection contains no values.
@abstract func is_empty() -> bool
## Returns the collection's documented size measure.
@abstract func size() -> int
## Returns a new collection containing values produced by [param fn].
@abstract func map(fn: Callable) -> StdResult
## Returns a new collection containing values accepted by [param pred].
@abstract func filter(pred: Callable) -> StdResult
