@abstract
class_name IStdListCollection
extends IStdCollection
## Abstract base for linked lists with head and tail access.

## Emitted after [param item] is added at the head.
signal head_pushed(item: Variant)
## Emitted after [param item] is added at the tail.
signal tail_pushed(item: Variant)
## Emitted after [param item] is removed from the head.
signal head_popped(item: Variant)


## Returns the head value without removing it, or [code]none[/code] when empty.
@abstract func head() -> StdOption
## Returns the tail value without removing it, or [code]none[/code] when empty.
@abstract func tail() -> StdOption
## Removes and returns the head value, or [code]none[/code] when empty.
@abstract func pop_head() -> StdOption
## Adds [param item] at the tail.
@abstract func push_tail(item: Variant) -> void
## Adds [param item] at the head.
@abstract func push_head(item: Variant) -> void
## Returns a head-to-tail snapshot of the list.
@abstract func to_array() -> Array
