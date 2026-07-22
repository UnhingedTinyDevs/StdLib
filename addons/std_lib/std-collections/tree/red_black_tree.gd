class_name StdRedBlackTree
extends StdBinarySearchTree
## A self-balancing binary search tree using red-black coloring.
##
## Lookup, insertion, and removal are O(log n). Comparator-equal values are
## retained as repeated occurrences, and [method to_array] returns values in
## comparator order.
## [codeblock lang=gdscript]
##     var tree: StdRedBlackTree = StdRedBlackTree.new(
##         func(a: int, b: int) -> int: return a - b)
##     tree.push(2)
##     tree.push(1)
##     tree.to_array() # [1, 2]
## [/codeblock]

## Identifies a child side during tree balancing.
enum Side {
	## The left child side.
	LEFT,
	## The right child side.
	RIGHT,
}

## The integer representation of a red [enum StdRedBlackTreeNode.NodeColor].
const RED: int = StdRedBlackTreeNode.NodeColor.RED
## The integer representation of a black [enum StdRedBlackTreeNode.NodeColor].
const BLACK: int = StdRedBlackTreeNode.NodeColor.BLACK


## Creates an empty tree ordered by [param compare].
## The comparator must follow the contract described by [StdBinarySearchTree].
func _init(compare: Callable) -> void:
	super(compare)
	var nil: StdRedBlackTreeNode = StdRedBlackTreeNode.new()
	nil.color = BLACK
	nil.left = NIL
	nil.right = NIL
	nil.parent = NIL
	_nodes.set(NIL, nil)
	return


## Creates a tree ordered by [param compare] and pushes values from [param from]
## in array order.
static func from_array(
	from: Array,
	compare: Callable,
) -> StdRedBlackTree:
	var tree: StdRedBlackTree = StdRedBlackTree.new(compare)
	for item: Variant in from:
		tree.push(item)
		pass
	return tree


#region Binary Search Tree Hooks
# Creates an empty red-black tree that reuses this tree's comparator.
func _new_tree() -> StdBinarySearchTree:
	return StdRedBlackTree.new(_compare)


# Creates a red node containing the item.
func _new_node(item: Variant) -> StdBinaryTreeNode:
	return StdRedBlackTreeNode.new(item)


# Repairs red-black invariants when a black node is removed.
func _after_delete(removed: int, replacement: int) -> void:
	if _color(removed) == BLACK:
		_delete_fixup(replacement)
	_set_color(NIL, BLACK)
	return
#endregion Binary Search Tree Hooks


#region Rotations
# Rotates the subtree left around the node at the given index.
func _rotate_left(index: int) -> void:
	var node: StdBinaryTreeNode = _nodes.get(index)
	var pivot_index: int = node.right
	var pivot: StdBinaryTreeNode = _nodes.get(pivot_index)
	node.right = pivot.left
	if pivot.left != NIL:
		_nodes.get(pivot.left).parent = index
		pass
	pivot.parent = node.parent
	if node.parent == NIL:
		_root = pivot_index
	else:
		var parent: StdBinaryTreeNode = _nodes.get(node.parent)
		if index == parent.left:
			parent.left = pivot_index
		else:
			parent.right = pivot_index
		pass
	pivot.left = index
	node.parent = pivot_index
	return


# Rotates the subtree right around the node at the given index.
func _rotate_right(index: int) -> void:
	var node: StdBinaryTreeNode = _nodes.get(index)
	var pivot_index: int = node.left
	var pivot: StdBinaryTreeNode = _nodes.get(pivot_index)
	node.left = pivot.right
	if pivot.right != NIL:
		_nodes.get(pivot.right).parent = index
		pass
	pivot.parent = node.parent
	if node.parent == NIL:
		_root = pivot_index
	else:
		var parent: StdBinaryTreeNode = _nodes.get(node.parent)
		if index == parent.right:
			parent.right = pivot_index
		else:
			parent.left = pivot_index
		pass
	pivot.right = index
	node.parent = pivot_index
	return
#endregion Rotations


#region Red-Black Balancing
# Restores red-black invariants after inserting a red node.
func _insert_fixup(index: int) -> void:
	var current: int = index
	while _color(_nodes.get(current).parent) == RED:
		var parent: int = _nodes.get(current).parent
		var grandparent: int = _nodes.get(parent).parent
		var side: int = Side.LEFT if parent == _nodes.get(grandparent).left else Side.RIGHT
		var uncle: int = _child(grandparent, _opposite(side))
		if _color(uncle) == RED:
			_set_color(parent, BLACK)
			_set_color(uncle, BLACK)
			_set_color(grandparent, RED)
			current = grandparent
		else:
			if current == _child(parent, _opposite(side)):
				current = parent
				if side == Side.LEFT:
					_rotate_left(current)
				else:
					_rotate_right(current)
				pass
			parent = _nodes.get(current).parent
			grandparent = _nodes.get(parent).parent
			_set_color(parent, BLACK)
			_set_color(grandparent, RED)
			if side == Side.LEFT:
				_rotate_right(grandparent)
			else:
				_rotate_left(grandparent)
			pass
		pass
	_set_color(_root, BLACK)
	return


# Restores red-black invariants after removing a black node.
func _delete_fixup(index: int) -> void:
	var current: int = index
	while current != _root and _color(current) == BLACK:
		var parent: int = _nodes.get(current).parent
		var side: int = Side.LEFT if current == _nodes.get(parent).left else Side.RIGHT
		var sibling: int = _child(parent, _opposite(side))
		if _color(sibling) != BLACK:
			_set_color(sibling, BLACK)
			_set_color(parent, RED)
			if side == Side.LEFT:
				_rotate_left(parent)
			else:
				_rotate_right(parent)
			sibling = _child(parent, _opposite(side))
			pass

		var near_child: int = _child(sibling, side)
		var far_child: int = _child(sibling, _opposite(side))
		if _color(near_child) == BLACK and _color(far_child) == BLACK:
			_set_color(sibling, RED)
			current = parent
		else:
			if _color(far_child) == BLACK:
				_set_color(near_child, BLACK)
				_set_color(sibling, RED)
				if side == Side.LEFT:
					_rotate_right(sibling)
				else:
					_rotate_left(sibling)
				sibling = _child(parent, _opposite(side))
				far_child = _child(sibling, _opposite(side))
				pass
			_set_color(sibling, _color(parent))
			_set_color(parent, BLACK)
			_set_color(far_child, BLACK)
			if side == Side.LEFT:
				_rotate_left(parent)
			else:
				_rotate_right(parent)
			current = _root
			pass
		pass
	_set_color(current, BLACK)
	return


# Returns the child index on the requested side of a node.
func _child(index: int, side: int) -> int:
	return _nodes.get(index).left if side == Side.LEFT else _nodes.get(index).right


# Returns the side opposite the requested side.
func _opposite(side: int) -> int:
	return Side.RIGHT if side == Side.LEFT else Side.LEFT


# Returns the color of the node at the given index.
func _color(index: int) -> int:
	return _nodes.get(index).color


# Assigns a color to the node at the given index.
func _set_color(index: int, color: int) -> void:
	_nodes.get(index).color = color
	return
#endregion Red-Black Balancing
