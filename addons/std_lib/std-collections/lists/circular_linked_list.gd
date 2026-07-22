class_name StdCircularLinkedList
extends IStdDoubleEndedListCollection
## A circular doubly linked list.
##
## Nodes form a ring, so every push and pop is O(1) and the head can
## be rotated with [method rotate_left] and [method rotate_right].
## Snapshot iteration is bounded by [method size].
## [codeblock lang=gdscript]
##     var ring: StdCircularLinkedList = StdCircularLinkedList.from_array([1, 2, 3])
##     ring.rotate_left()
##     ring.head() # some(2)
## [/codeblock]


## Stores one value and two links inside the circular list.
class CircularLink extends IListNode:
	## The next node in the ring.
	var next: CircularLink
	## The previous node in the ring.
	var previous: CircularLink


var _head: CircularLink


#region Engine Methods
# Breaks the ring's cyclic references before the list is deleted.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	var node: CircularLink = _head
	for i: int in _size:
		var next_node: CircularLink = node.next
		node.next = null
		node.previous = null
		node = next_node
		pass
	_head = null
	_size = 0
	return
#endregion Engine Methods


#region Public API
## Returns the value at the head, or [code]none[/code] when empty.
func head() -> StdOption:
	if is_empty():
		return StdOption.none()
	return StdOption.some(_head.value)


## Returns the value at the tail, or [code]none[/code] when empty.
func tail() -> StdOption:
	if is_empty():
		return StdOption.none()
	return StdOption.some(_head.previous.value)


## Adds [param item] at the tail of the ring.
func push_tail(item: Variant) -> void:
	_insert_before_head(item)
	tail_pushed.emit(item)
	size_changed.emit(_size)
	return


## Adds [param item] at the head of the ring.
func push_head(item: Variant) -> void:
	_head = _insert_before_head(item)
	head_pushed.emit(item)
	size_changed.emit(_size)
	return


## Removes and returns the tail value, or [code]none[/code] when empty.
func pop_tail() -> StdOption:
	if is_empty():
		return StdOption.none()
	var value: Variant = _detach(_head.previous)
	tail_popped.emit(value)
	size_changed.emit(_size)
	return StdOption.some(value)


## Removes and returns the head value, or [code]none[/code] when empty.
func pop_head() -> StdOption:
	if is_empty():
		return StdOption.none()
	var node: CircularLink = _head
	_head = node.next if _size > 1 else null
	var value: Variant = _detach(node)
	head_popped.emit(value)
	size_changed.emit(_size)
	return StdOption.some(value)


## Returns [code]true[/code] if [param item] is stored in the ring.
func has(item: Variant) -> bool:
	var node: CircularLink = _head
	for i: int in _size:
		if node.value == item:
			return true
		node = node.next
		pass
	return false


## Unlinks and removes every value, leaving the ring reusable.
func clear() -> void:
	var node: CircularLink = _head
	for i: int in _size:
		var next_node: CircularLink = node.next
		node.next = null
		node.previous = null
		node = next_node
		pass
	_head = null
	_size = 0
	cleared.emit()
	size_changed.emit(_size)
	return


## Maps each value into a new ring without changing this ring.
## Returns an error when [param fn] is invalid.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper is invalid")
	var mapped: StdCircularLinkedList = StdCircularLinkedList.new()
	var node: CircularLink = _head
	for i: int in _size:
		mapped.push_tail(fn.call(node.value))
		node = node.next
		pass
	return StdResult.ok(mapped)


## Copies accepted values into a new ring without changing this ring.
## Returns an error when [param predicate] is invalid.
func filter(predicate: Callable) -> StdResult:
	if not predicate.is_valid():
		return StdResult.err("predicate is invalid")
	var filtered: StdCircularLinkedList = StdCircularLinkedList.new()
	var node: CircularLink = _head
	for i: int in _size:
		if predicate.call(node.value):
			filtered.push_tail(node.value)
			pass
		node = node.next
		pass
	return StdResult.ok(filtered)


## Rotates the head of the ring [param steps] nodes forward, so the
## current head becomes the tail. Negative steps rotate backward.
func rotate_left(steps: int = 1) -> void:
	if is_empty():
		return
	for i: int in posmod(steps, _size):
		_head = _head.next
		pass
	return


## Rotates the head of the ring [param steps] nodes backward, so the
## current tail becomes the head. Negative steps rotate forward.
func rotate_right(steps: int = 1) -> void:
	rotate_left(-steps)
	return
#endregion Public API


#region Type Conversions
## Creates a ring containing [param from] in array order.
static func from_array(from: Array) -> StdCircularLinkedList:
	var list: StdCircularLinkedList = StdCircularLinkedList.new()
	for item: Variant in from:
		list.push_tail(item)
		pass
	return list


## Returns a head-to-tail snapshot of the ring.
func to_array() -> Array:
	var values: Array = []
	var node: CircularLink = _head
	for i: int in _size:
		values.push_back(node.value)
		node = node.next
		pass
	return values
#endregion Type Conversions


#region Private Helpers
# Inserts a new node holding item between the tail and the head and
# returns it. On an empty ring the node links to itself.
func _insert_before_head(item: Variant) -> CircularLink:
	var node: CircularLink = CircularLink.new()
	node.value = item
	if is_empty():
		node.next = node
		node.previous = node
		_head = node
	else:
		var tail_node: CircularLink = _head.previous
		tail_node.next = node
		node.previous = tail_node
		node.next = _head
		_head.previous = node
	_size += 1
	return node


# Removes node from the ring, breaking its links (including the self
# links of a single node ring) so it can be freed, and returns its value.
func _detach(node: CircularLink) -> Variant:
	if _size == 1:
		_head = null
	else:
		node.previous.next = node.next
		node.next.previous = node.previous
	node.next = null
	node.previous = null
	_size -= 1
	return node.value
#endregion Private Helpers
