@abstract
class_name IStdPriorityCollection
extends IStdPop
## Abstract base for collections that order values by priority.
##
## Lower or higher priority values are returned first according to the concrete
## collection's ordering policy.


## Emitted after [param item] is added with [param priority].
signal pushed(item: Variant, priority: int)
## Adds [param item] with [param priority].
@abstract func push(item: Variant, priority: int) -> void
