class_name StdBinaryTreeNode
extends RefCounted
## [Array] entry used by [StdBinarySearchTree].

## The value stored by this node.
var value: Variant
## The number of comparator-equal occurrences stored by this node.
var count: int = 1
## The parent node index, or [constant StdBinarySearchTree.NIL] when absent.
var parent: int = 0
## The left child index, or [constant StdBinarySearchTree.NIL] when absent.
var left: int = 0
## The right child index, or [constant StdBinarySearchTree.NIL] when absent.
var right: int = 0


## Creates a node containing [param item].
func _init(item: Variant = null) -> void:
	value = item
	return
