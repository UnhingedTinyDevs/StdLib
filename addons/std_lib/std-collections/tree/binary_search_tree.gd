@abstract
class_name StdBinarySearchTree
extends IStdTreeCollection
## Abstract array-backed binary search tree.
##
## Values are ordered by a comparator [Callable] that returns a negative integer,
## zero, or a positive integer when its first argument sorts before, equal to, or
## after its second argument. Comparator-equal values are stored as occurrences
## on the same node.

## The node index used to represent a missing parent or child.
const NIL: int = 0

var _nodes: Array[StdBinaryTreeNode] = []
var _free: Array[int] = []
var _root: int = NIL
var _size: int = 0
var _compare: Callable


## Initializes the tree with [param compare] as its ordering function.
func _init(compare: Callable) -> void:
	assert(compare.is_valid(), "StdBinarySearchTree requires a valid comparator")
	_compare = compare
	_nodes.push_back(StdBinaryTreeNode.new()) # Sentinel node.
	return


#region Public API
## Adds one occurrence of [param item] to the tree.
func push(item: Variant) -> void:
	_insert(item)
	_size += 1
	pushed.emit(item)
	size_changed.emit(_size)
	return


## Returns the stored value comparator-equal to [param item] without removing it.
func peek(item: Variant) -> StdOption:
	var index: int = _find(item)
	return StdOption.none() if index == NIL else StdOption.some(_nodes.get(index).value)


## Removes and returns one occurrence comparator-equal to [param item].
## Returns [code]none[/code] when no equal value is stored.
func pop(item: Variant) -> StdOption:
	var index: int = _find(item)
	if index == NIL:
		return StdOption.none()
	var node: StdBinaryTreeNode = _nodes.get(index)
	var value: Variant = node.value
	node.count -= 1
	_size -= 1
	if node.count == 0:
		_delete(index)
		pass
	popped.emit(value)
	size_changed.emit(_size)
	return StdOption.some(value)


## Returns [code]true[/code] if the tree stores a value comparator-equal to
## [param item].
func has(item: Variant) -> bool:
	return _find(item) != NIL


## Returns a new tree containing values accepted by [param pred].
## Ordering and duplicate occurrences are preserved. Returns an error when
## [param pred] is invalid.
func filter(pred: Callable) -> StdResult:
	if not pred.is_valid():
		return StdResult.err("predicate is invalid")

	var filtered: StdBinarySearchTree = _new_tree()
	for item: Variant in to_array():
		if pred.call(item):
			filtered.push(item)
			pass
		pass
	return StdResult.ok(filtered)


## Returns a new tree containing each value transformed by [param fn].
## Mapped values are inserted using the same comparator. Returns an error when
## [param fn] is invalid.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper is invalid")

	var mapped: StdBinarySearchTree = _new_tree()
	for item: Variant in to_array():
		mapped.push(fn.call(item))
		pass
	return StdResult.ok(mapped)


## Returns the number of stored occurrences, including duplicates.
func size() -> int:
	return _size


## Returns [code]true[/code] if the tree contains no values.
func is_empty() -> bool:
	return _root == NIL


## Removes every value from the tree.
func clear() -> void:
	_nodes.resize(1)
	_nodes.get(NIL).parent = NIL
	_nodes.get(NIL).left = NIL
	_nodes.get(NIL).right = NIL
	_free.clear()
	_root = NIL
	_size = 0
	cleared.emit()
	size_changed.emit(0)
	return


## Returns an ordered snapshot of every stored occurrence.
func to_array() -> Array:
	var values: Array = []
	values.resize(_size)
	var stack: Array[int] = []
	var current: int = _root
	var write_index: int = 0
	while current != NIL or not stack.is_empty():
		while current != NIL:
			stack.push_back(current)
			current = _nodes.get(current).left
			pass
		current = stack.pop_back()
		var node: StdBinaryTreeNode = _nodes.get(current)
		for occurrence: int in node.count:
			values.set(write_index, node.value)
			write_index += 1
			pass
		current = _nodes.get(current).right
		pass
	return values
#endregion Public API


#region Tree Mechanics
# Inserts an occurrence and invokes the subclass balancing hook for a new node.
func _insert(item: Variant) -> void:
	var parent: int = NIL
	var current: int = _root
	var comparison: int = 0
	while current != NIL:
		parent = current
		comparison = _compare_value(item, _nodes.get(current).value)
		if comparison == 0:
			_nodes.get(current).count += 1
			return
		current = _nodes.get(current).left if comparison < 0 \
				else _nodes.get(current).right
		pass

	var index: int = _allocate(item)
	_nodes.get(index).parent = parent
	if parent == NIL:
		_root = index
	elif comparison < 0:
		_nodes.get(parent).left = index
	else:
		_nodes.get(parent).right = index

	_insert_fixup(index)
	return


# Removes a node slot, replacing a two-child node with its in-order successor.
func _delete(index: int) -> void:
	var node: StdBinaryTreeNode = _nodes.get(index)
	var removed: int = index
	var removed_node: StdBinaryTreeNode = node
	if node.left != NIL and node.right != NIL:
		removed = _minimum(node.right)
		removed_node = _nodes.get(removed)
		node.value = removed_node.value
		node.count = removed_node.count

	var child: int = removed_node.left
	if child == NIL:
		child = removed_node.right
	_transplant(removed, child)
	_after_delete(removed, child)
	_release(removed)
	_nodes.get(NIL).parent = NIL
	return


# Replaces one subtree root with another while preserving the parent link.
func _transplant(old: int, replacement: int) -> void:
	var parent: int = _nodes.get(old).parent
	if parent == NIL:
		_root = replacement
	elif old == _nodes.get(parent).left:
		_nodes.get(parent).left = replacement
	else:
		_nodes.get(parent).right = replacement
	_nodes.get(replacement).parent = parent
	return


# Finds the slot containing a comparator-equal value, or NIL when absent.
func _find(item: Variant) -> int:
	var found: int = NIL
	var current: int = _root
	while current != NIL:
		var comparison: int = _compare_value(item, _nodes.get(current).value)
		if comparison == 0:
			found = current
			current = _nodes.get(current).left
		elif comparison < 0:
			current = _nodes.get(current).left
		else:
			current = _nodes.get(current).right
		pass
	return found


# Finds the leftmost node in the subtree rooted at the given index.
func _minimum(index: int) -> int:
	var current: int = index
	while _nodes.get(current).left != NIL:
		current = _nodes.get(current).left
		pass
	return current


# Normalizes the comparator result to an integer.
func _compare_value(first: Variant, second: Variant) -> int:
	return int(_compare.call(first, second))


# Allocates a node in an available slot or appends a new slot.
func _allocate(item: Variant) -> int:
	var node: StdBinaryTreeNode = _new_node(item)
	if _free.is_empty():
		_nodes.push_back(node)
		return _nodes.size() - 1
	var index: int = _free.pop_back()
	_nodes.set(index, node)
	return index


# Clears a node slot and makes its index available for reuse.
func _release(index: int) -> void:
	_nodes.set(index, null)
	_free.push_back(index)
	return
#endregion Tree Mechanics


#region Subclass Hooks
# Creates an empty tree with the concrete subclass's configuration.
@abstract func _new_tree() -> StdBinarySearchTree
# Creates the concrete node type used by the subclass.
@abstract func _new_node(item: Variant) -> StdBinaryTreeNode
# Restores subclass invariants after inserting a new node.
@abstract func _insert_fixup(index: int) -> void
# Restores subclass invariants after removing a node.
@abstract func _after_delete(removed: int, replacement: int) -> void
#endregion Subclass Hooks
