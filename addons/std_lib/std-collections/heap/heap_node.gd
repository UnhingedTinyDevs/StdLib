class_name StdHeapNode
extends RefCounted
## Stores one value and its ordering metadata inside a [StdHeap].


## The value stored in the heap.
var value: Variant
## The priority used to order the value.
var priority: int
## The insertion sequence used to order values with equal priorities.
var sequence: int

## Creates a node containing [param value] with [param priority].
## [param inserted_at] records the insertion sequence.
func _init(value: Variant, priority: int, inserted_at: int) -> void:
	self.value = value
	self.priority = priority
	self.sequence = inserted_at
