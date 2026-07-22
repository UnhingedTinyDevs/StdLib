class_name StdNode
extends RefCounted
## Typed node-tree queries, child cleanup, and liveness checks.
##
## Query methods match native classes and [Script] types with
## [method @GlobalScope.is_instance_of]. They inspect non-internal children,
## matching [method Node.get_children]'s default behavior.


#region Public API
## Returns every direct, non-internal child of [param parent] matching
## [param type]. Returns an empty array when [param parent] is not alive or no
## child matches.
static func children_of(parent: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	if not is_alive(parent):
		return found

	for child: Node in parent.get_children():
		if is_instance_of(child, type):
			found.append(child)
			pass
		pass
	return found


## Returns the first direct, non-internal child of [param parent] matching
## [param type], or [code]none[/code] when [param parent] is not alive or no
## child matches.
static func first_child_of(parent: Node, type: Variant) -> StdOption:
	if not is_alive(parent):
		return StdOption.none()

	for child: Node in parent.get_children():
		if is_instance_of(child, type):
			return StdOption.some(child)
		pass
	return StdOption.none()


## Returns every matching, non-internal descendant of [param parent]. Never
## includes [param parent] itself. Returns an empty array when [param parent]
## is not alive or no descendant matches. Result order is not guaranteed.
static func descendants_of(parent: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	if not is_alive(parent):
		return found

	var stack: Array[Node] = parent.get_children()
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if is_instance_of(node, type):
			found.append(node)
			pass
		stack.append_array(node.get_children())
		pass
	return found


## Returns the nearest ancestor of [param node] matching [param type], or
## [code]none[/code] when [param node] is not alive or no ancestor matches.
## Never returns [param node] itself.
static func ancestor_of(node: Node, type: Variant) -> StdOption:
	if not is_alive(node):
		return StdOption.none()

	var ancestor: Node = node.get_parent()
	while ancestor != null:
		if is_instance_of(ancestor, type):
			return StdOption.some(ancestor)
		ancestor = ancestor.get_parent()
		pass
	return StdOption.none()


## Calls [method Node.queue_free] on every non-internal child of [param parent].
## Errs when [param parent] is not alive.
static func queue_free_children(parent: Node) -> StdResult:
	if not is_alive(parent):
		return StdResult.err("parent is null, freed, or queued for deletion")

	for child: Node in parent.get_children():
		child.queue_free()
		pass
	return StdResult.ok(true)


## Returns [code]true[/code] when [param node] is a valid [Node] that is not
## queued for deletion.
static func is_alive(node: Variant) -> bool:
	if not is_instance_valid(node) or not node is Node:
		return false
	return not node.is_queued_for_deletion()
#endregion Public API
