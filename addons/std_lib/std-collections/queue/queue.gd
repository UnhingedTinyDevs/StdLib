class_name StdQueue
extends IStdPushCollection
## An amortized O(1) first-in, first-out collection.
##
## [method push] adds a value at the back. [method pop] and [method peek]
## read from the front. [Array] conversions use front-to-back order.
## [codeblock lang=gdscript]
##     var queue: StdQueue = StdQueue.from_array(["first", "second"])
##     queue.pop() # some("first")
## [/codeblock]


var _items: Array = []
var _head: int = 0


#region Public API
## Adds [param value] at the back of the queue.
func push(value: Variant) -> void:
	_items.push_back(value)
	pushed.emit(value)
	size_changed.emit(self.size())
	return


## Removes and returns the value at the front, or [code]none[/code]
## when the queue is empty.
func pop() -> StdOption:
	if is_empty(): return StdOption.none()
	var value: Variant = _items.get(_head)
	_items[_head] = null
	_head += 1
	_compact_if_needed()
	popped.emit(value)
	size_changed.emit(self.size())
	return StdOption.some(value)


## Returns the value at the front without removing it, or
## [code]none[/code] when the queue is empty.
func peek() -> StdOption:
	if is_empty(): return StdOption.none()
	return StdOption.some(_items.get(_head))


## Returns [code]true[/code] if the queue contains [param value].
func has(value: Variant) -> bool:
	for i: int in range(_head, _items.size()):
		if _items[i] == value:
			return true
		pass
	return false


## Replaces the front value with the value returned by [param mutator].
## Returns the replacement value, or an error when the queue is empty or
## [param mutator] is invalid.
func mutate(mutator: Callable) -> StdResult:
	if is_empty():
		return StdResult.err("queue is empty")
	if not mutator.is_valid():
		return StdResult.err("mutator is not valid")
	# 1. get the current head
	var old: Variant = _items.get(_head)
	# 2. mutatue the head
	var new: Variant = mutator.call(old)
	# 3. swap in the new value
	_items.set(_head, new)
	# 4. emit signal
	mutated.emit(new, old)
	return StdResult.ok(new)


## Returns a new queue containing values accepted by [param predicate].
## Front-to-back order is preserved.
func filter(predicate: Callable) -> StdResult:
	if not predicate.is_valid(): return StdResult.err("predicate is not valid")
	var new: StdQueue = StdQueue.from_array(to_array().filter(predicate))
	return StdResult.ok(new)


## Returns a new queue containing each value transformed by [param mapper].
## Front-to-back order is preserved.
func map(mapper: Callable) -> StdResult:
	if not mapper.is_valid(): return StdResult.err("mapper is invalid")
	var new: StdQueue = StdQueue.from_array(to_array().map(mapper))
	return StdResult.ok(new)


## Returns the number of queued values.
func size() -> int:
	return _items.size() - _head


## Returns [code]true[/code] if the queue contains no values.
func is_empty() -> bool:
	return size() == 0


## Removes every queued value and leaves the queue reusable.
func clear() -> void:
	_items.clear()
	_head = 0
	cleared.emit()
	size_changed.emit(self.size())
	return
#endregion Public API


#region Type Conversions
## Creates a queue whose front is the first element of [param from].
static func from_array(from: Array) -> StdQueue:
	var queue: StdQueue = StdQueue.new()
	queue._items = from.duplicate()
	return queue


## Returns a front-to-back snapshot of the queue.
func to_array() -> Array:
	return _items.slice(_head)
#endregion Type Conversions


#region Private Helpers
# Discards consumed slots occasionally so pop remains amortized O(1).
func _compact_if_needed() -> void:
	if _head == _items.size():
		_items.clear()
		_head = 0
		return
	if _head >= 64 and _head * 2 >= _items.size():
		_items = _items.slice(_head)
		_head = 0
	return
#endregion Private Helpers
