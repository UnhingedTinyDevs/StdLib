class_name StdRedBlackTreeNode
extends StdBinaryTreeNode
## Colored node used by [StdRedBlackTree].

## Colors used to maintain red-black balancing invariants.
enum NodeColor {
	## A red tree node.
	RED,
	## A black tree node.
	BLACK,
}

## The balancing color assigned to this node.
var color: NodeColor = NodeColor.RED
