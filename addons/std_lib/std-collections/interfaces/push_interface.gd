@abstract
class_name IStdPushCollection
extends IStdPop
## Abstract base for collections that accept values without priorities.
##
## Use [IStdPriorityCollection] when insertion also requires a priority.

## Emitted after [param item] is added to the collection.
signal pushed(item: Variant)

## Adds [param item] to the collection.
@abstract func push(item: Variant) -> void
