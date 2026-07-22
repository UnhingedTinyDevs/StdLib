class_name StdSinglyLinkedList
extends StdLinkedListBase
## A singly linked list with constant-time insertion at either end.
##
## Each link points only to the next link. [method head], [method tail],
## [method push_head], [method push_tail], and [method pop_head] are O(1).
## [codeblock lang=gdscript]
##     var list: StdSinglyLinkedList = StdSinglyLinkedList.from_array([1, 2])
##     list.pop_head() # some(1)
## [/codeblock]


## Stores one value and a forward link inside the list.
class SingleLink extends IListNode:
	## The next node toward the tail, or [code]null[/code] at the tail.
	var next: SingleLink


var _head: SingleLink
var _tail: SingleLink


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
	var node: SingleLink = _make_link(item)
	if _head == null:
		_tail = node
	else:
		node.next = _head
	_head = node
	_size += 1
	head_pushed.emit(item)
	size_changed.emit(_size)
	return


## Adds [param item] at the tail.
func push_tail(item: Variant) -> void:
	var node: SingleLink = _make_link(item)
	if _tail == null:
		_head = node
	else:
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

	var old_head: SingleLink = _head
	_head = old_head.next
	old_head.next = null
	_size -= 1
	if _head == null:
		_tail = null

	head_popped.emit(old_head.value)
	size_changed.emit(_size)
	return StdOption.some(old_head.value)


## Returns [code]true[/code] if [param item] is stored in the list.
func has(item: Variant) -> bool:
	var node: SingleLink = _head
	while node != null:
		if node.value == item:
			return true
		node = node.next
		pass
	return false


## Removes every value and leaves the list reusable.
func clear() -> void:
	var node: SingleLink = _head
	while node != null:
		var next_node: SingleLink = node.next
		node.next = null
		node = next_node
		pass

	_head = null
	_tail = null
	_size = 0
	cleared.emit()
	size_changed.emit(_size)
	return


## Maps each value into a new list without changing this list.
## Returns an error when [param fn] is invalid.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper is invalid")

	var mapped: StdSinglyLinkedList = StdSinglyLinkedList.new()
	var node: SingleLink = _head
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

	var filtered: StdSinglyLinkedList = StdSinglyLinkedList.new()
	var node: SingleLink = _head
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
static func from_array(from: Array) -> StdSinglyLinkedList:
	var list: StdSinglyLinkedList = StdSinglyLinkedList.new()
	for item: Variant in from:
		list.push_tail(item)
		pass
	return list


## Returns a head-to-tail snapshot of the list.
func to_array() -> Array:
	var values: Array = []
	var node: SingleLink = _head
	while node != null:
		values.push_back(node.value)
		node = node.next
		pass
	return values
#endregion Type Conversions


#region Private Helpers
# Creates a detached link containing the item.
func _make_link(item: Variant) -> SingleLink:
	var link: SingleLink = SingleLink.new()
	link.value = item
	return link
#endregion Private Helpers
