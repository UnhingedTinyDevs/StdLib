extends StdTest
## Headless tests for StdNode.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . --
## addons/std_lib/std-node


class DummyNode:
	extends Node2D


func _test_children_of() -> void:
	var parent: Node = Node.new()
	var sprite: Sprite2D = Sprite2D.new()
	var plain_2d: Node2D = Node2D.new()
	var dummy: DummyNode = DummyNode.new()
	parent.add_child(sprite)
	parent.add_child(plain_2d)
	parent.add_child(dummy)
	parent.add_child(Node.new())

	assert_eq(StdNode.children_of(parent, Node2D).size(), 3, "native class matches subclasses")
	assert_eq(StdNode.children_of(parent, Sprite2D), [sprite], "native class filters children")
	assert_eq(StdNode.children_of(parent, DummyNode), [dummy], "script class filters children")
	assert_eq(StdNode.children_of(parent, Timer), [], "no matches is empty")
	assert_eq(StdNode.children_of(null, Node2D), [], "dead parent is empty")

	parent.free()
	return


func _test_first_child_of() -> void:
	var parent: Node = Node.new()
	var first: Node2D = Node2D.new()
	var second: Node2D = Node2D.new()
	parent.add_child(Node.new())
	parent.add_child(first)
	parent.add_child(second)

	var found: StdOption = StdNode.first_child_of(parent, Node2D)
	assert_some(found, "matching child is some")
	assert_eq(found.unwrap(), first, "first matching child is returned")
	assert_none(StdNode.first_child_of(parent, Timer), "no match is none")
	assert_none(StdNode.first_child_of(null, Node2D), "dead parent is none")

	parent.free()
	return


func _test_descendants_of() -> void:
	var root: Node2D = Node2D.new()
	var child: Node = Node.new()
	var grandchild: Node2D = Node2D.new()
	var great_grandchild: DummyNode = DummyNode.new()
	root.add_child(child)
	child.add_child(grandchild)
	grandchild.add_child(great_grandchild)

	var found: Array[Node] = StdNode.descendants_of(root, Node2D)
	assert_eq(found.size(), 2, "matches are found at every depth")
	assert_false(found.has(root), "searched parent is excluded")
	assert_true(found.has(grandchild) and found.has(great_grandchild), "nested matches are returned")
	assert_eq(StdNode.descendants_of(root, Timer), [], "no match is empty")
	assert_eq(StdNode.descendants_of(null, Node2D), [], "dead parent is empty")

	root.free()
	return


func _test_ancestor_of() -> void:
	var root: Node2D = Node2D.new()
	var middle: Node2D = Node2D.new()
	var leaf: Node = Node.new()
	root.add_child(middle)
	middle.add_child(leaf)

	var found: StdOption = StdNode.ancestor_of(leaf, Node2D)
	assert_some(found, "matching ancestor is some")
	assert_eq(found.unwrap(), middle, "nearest matching ancestor is returned")
	assert_none(StdNode.ancestor_of(leaf, Timer), "no match is none")
	assert_none(StdNode.ancestor_of(root, Node2D), "orphan has no ancestor")
	assert_none(StdNode.ancestor_of(null, Node2D), "dead node has no ancestor")

	root.free()
	return


func _test_queue_free_children() -> void:
	var parent: Node = Node.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	parent.add_child(first)
	parent.add_child(second)

	assert_ok(StdNode.queue_free_children(parent), "live parent's children can be queued")
	assert_true(first.is_queued_for_deletion(), "first child is queued")
	assert_true(second.is_queued_for_deletion(), "second child is queued")
	assert_eq(parent.get_child_count(), 2, "queued children remain attached until frame end")
	assert_err(StdNode.queue_free_children(null), "dead parent errs")

	parent.free()
	return


func _test_is_alive() -> void:
	var live: Node = Node.new()
	var freed: Node = Node.new()
	freed.free()
	var queued: Node = Node.new()
	queued.queue_free()

	assert_true(StdNode.is_alive(live), "live node is alive")
	assert_false(StdNode.is_alive(null), "null is not alive")
	assert_false(StdNode.is_alive(freed), "freed node is not alive")
	assert_false(StdNode.is_alive(queued), "queued node is not alive")
	assert_false(StdNode.is_alive(RefCounted.new()), "non-node object is not alive")
	assert_false(StdNode.is_alive(42), "non-object is not alive")

	live.free()
	queued.free()
	return
