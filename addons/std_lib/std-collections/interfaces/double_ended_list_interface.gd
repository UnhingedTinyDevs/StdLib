@abstract
class_name IStdDoubleEndedListCollection
extends StdLinkedListBase
## Abstract base for linked lists that support removal from both ends.

## Emitted after [param item] is removed from the tail.
signal tail_popped(item: Variant)


## Removes and returns the tail value, or [code]none[/code] when empty.
@abstract func pop_tail() -> StdOption
