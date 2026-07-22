@abstract
class_name IStdTreeCollection
extends IStdCollection
## Abstract base for comparator-ordered tree collections.
##
## Values that compare as equal may be stored as repeated occurrences.


## Emitted after [param item] is added to the tree.
signal pushed(item: Variant)
## Emitted after [param item] is removed from the tree.
signal popped(item: Variant)


## Adds one occurrence of [param item].
@abstract func push(item: Variant) -> void
## Removes one occurrence comparator-equal to [param item].
@abstract func pop(item: Variant) -> StdOption
## Returns the stored value comparator-equal to [param item].
@abstract func peek(item: Variant) -> StdOption
