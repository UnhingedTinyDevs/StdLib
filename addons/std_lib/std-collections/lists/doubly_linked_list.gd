class_name StdDoublyLinkedList
extends IStdDoubleEndedListCollection
## A doubly linked list with constant-time operations at both ends.
##
## Each link points to its next and previous neighbors. [method head],
## [method tail], insertion, and removal at either end are O(1).
## [codeblock lang=gdscript]
##     var list: StdDoublyLinkedList = StdDoublyLinkedList.from_array([1, 2])
##     list.pop_tail() # some(2)
## [/codeblock]


## Stores one value and two directional links inside the list.
class DoubleLink extends IListNode:
	## The next node toward the tail, or [code]null[/code] at the tail.
	var next: DoubleLink
	## The previous node toward the head, or [code]null[/code] at the head.
	var previous: DoubleLink


var _head: DoubleLink
var _tail: DoubleLink


#region Engine Methods
# Breaks bidirectional references before the list is deleted.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		StdDoublyLinkedList._unlink_links(_head)
	return
#endregion Engine Methods


#region Public API
## Returns the value at the head, or [code]none[/code] when empty.
func head() -> StdOption:
	if _head == null:
		return StdOption.none()
	return StdOption.some(_head.value)


## Returns the value at the tail, or [code]none[/code] when empty.
func tail() -> StdOption:
	if _tail == null:
		return StdOption.none()
	return StdOption.some(_tail.value)


## Adds [param item] at the head.
func push_head(item: Variant) -> void:
	var node: DoubleLink = _make_link(item)
	if _head == null:
		_tail = node
	else:
		node.next = _head
		_head.previous = node
	_head = node
	_size += 1
	head_pushed.emit(item)
	size_changed.emit(_size)
	return


## Adds [param item] at the tail.
func push_tail(item: Variant) -> void:
	var node: DoubleLink = _make_link(item)
	if _tail == null:
		_head = node
	else:
		node.previous = _tail
		_tail.next = node
	_tail = node
	_size += 1
	tail_pushed.emit(item)
	size_changed.emit(_size)
	return


## Removes and returns the value at the head, or [code]none[/code] when empty.
func pop_head() -> StdOption:
	if _head == null:
		return StdOption.none()

	var old_head: DoubleLink = _head
	_head = old_head.next
	if _head == null:
		_tail = null
	else:
		_head.previous = null
	old_head.next = null
	_size -= 1

	head_popped.emit(old_head.value)
	size_changed.emit(_size)
	return StdOption.some(old_head.value)


## Removes and returns the value at the tail, or [code]none[/code] when empty.
func pop_tail() -> StdOption:
	if _tail == null:
		return StdOption.none()

	var old_tail: DoubleLink = _tail
	_tail = old_tail.previous
	if _tail == null:
		_head = null
	else:
		_tail.next = null
	old_tail.previous = null
	_size -= 1

	tail_popped.emit(old_tail.value)
	size_changed.emit(_size)
	return StdOption.some(old_tail.value)


## Returns [code]true[/code] if [param item] is stored in the list.
func has(item: Variant) -> bool:
	var node: DoubleLink = _head
	while node != null:
		if node.value == item:
			return true
		node = node.next
		pass
	return false


## Unlinks and removes every value, leaving the list reusable.
func clear() -> void:
	_unlink_all()
	cleared.emit()
	size_changed.emit(_size)
	return


## Maps each value into a new list without changing this list.
## Returns an error when [param fn] is invalid.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper is invalid")

	var mapped: StdDoublyLinkedList = StdDoublyLinkedList.new()
	var node: DoubleLink = _head
	while node != null:
		mapped.push_tail(fn.call(node.value))
		node = node.next
		pass
	return StdResult.ok(mapped)


## Copies accepted values into a new list without changing this list.
## Returns an error when [param pred] is invalid.
func filter(pred: Callable) -> StdResult:
	if not pred.is_valid():
		return StdResult.err("predicate is invalid")

	var filtered: StdDoublyLinkedList = StdDoublyLinkedList.new()
	var node: DoubleLink = _head
	while node != null:
		if pred.call(node.value):
			filtered.push_tail(node.value)
			pass
		node = node.next
		pass
	return StdResult.ok(filtered)
#endregion Public API


#region Type Conversions
## Creates a list containing [param from] in array order.
static func from_array(from: Array) -> StdDoublyLinkedList:
	var list: StdDoublyLinkedList = StdDoublyLinkedList.new()
	for item: Variant in from:
		list.push_tail(item)
		pass
	return list


## Returns a head-to-tail snapshot of the list.
func to_array() -> Array:
	var values: Array = []
	var node: DoubleLink = _head
	while node != null:
		values.push_back(node.value)
		node = node.next
		pass
	return values
#endregion Type Conversions


#region Private Helpers
# Creates a detached link containing the item.
func _make_link(item: Variant) -> DoubleLink:
	var link: DoubleLink = DoubleLink.new()
	link.value = item
	return link


# Breaks every link and resets the list to its empty state.
func _unlink_all() -> void:
	StdDoublyLinkedList._unlink_links(_head)
	_head = null
	_tail = null
	_size = 0
	return


# Breaks the forward and backward references in a linear chain.
static func _unlink_links(from: DoubleLink) -> void:
	var node: DoubleLink = from
	while node != null:
		var next_node: DoubleLink = node.next
		node.next = null
		node.previous = null
		node = next_node
		pass
	return
#endregion Private Helpers
