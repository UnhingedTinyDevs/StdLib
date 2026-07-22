@abstract
class_name IStdPop
extends IStdCollection
## Abstract base for collections with a next value.
##
## The collection determines which value is next. That value can be inspected,
## removed, or replaced without requiring a key or index from the caller.


## Emitted after [param item] is removed from the collection.
signal popped(item: Variant)
## Emitted after the next value changes from [param old] to [param new].
signal mutated(new: Variant, old: Variant)

## Removes and returns the next value, or [code]none[/code] when empty.
@abstract func pop() -> StdOption
## Returns the next value without removing it, or [code]none[/code] when empty.
@abstract func peek() -> StdOption
## Replaces the next value with the result of [param mutator].
@abstract func mutate(mutator: Callable) -> StdResult
