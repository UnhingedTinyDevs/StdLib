class_name StdObjectPool
extends RefCounted
## A fixed-capacity pool of reusable [Node] instances.
##
## Nodes are created by a factory [Callable] and cycled between an
## active and an available pool instead of being freed and recreated.
## [method acquire] hands out an available node, creating one when
## none are available and the pool is under [method capacity];
## [method release] returns a node to the available pool. Unlike the
## other collections, values never leave the pool's ownership, so the
## API uses acquire/release rather than push/pop. [method acquire]
## returns a [StdResult], including an explicit exhaustion error.
## [method release] also returns a [StdResult] and detaches the node from
## its parent, so an inactive pooled node cannot keep processing in the scene tree.
##
## [method clear] refuses while nodes are active. [method destroy]
## explicitly frees every node. Freeing the pool releases active nodes from
## pool ownership with a warning and frees only the available nodes.
## [codeblock lang=gdscript]
## var pool: StdObjectPool = StdObjectPool.new(
##     func() -> Node: return bullet_scene.instantiate(),
##     32, 8,
##     func(bullet: Node) -> void: bullet.hide()
## )
## var bullet: StdResult = pool.acquire()
## if bullet.is_ok(): add_child(bullet.unwrap())
## [/codeblock]

## Emitted when [param obj] is acquired from the pool.
signal object_requested(obj: Node)
## Emitted when [param obj] is released back to the pool.
signal object_released(obj: Node)
## Emitted when an object is requested after the pool reaches capacity.
signal pool_exhausted()


var _factory: Callable
var _reset: Callable
# Maximum node count, where active + inactive <= _max_objects.
var _max_objects: int

# Nodes currently handed out, keyed by instance ID for O(1) release.
var _active: Dictionary
var _inactive: Array[Node]


## Creates a pool that builds nodes with [param factory], a zero-arg
## [Callable] returning a new [Node]. At most [param max_size] nodes
## are held; [param prefill] nodes are created up front, clamped to
## [param max_size] with a warning if larger. The optional
## [param reset] [Callable] receives each node during
## [method release] before it rejoins the inactive pool.
func _init(factory: Callable, max_size: int, prefill: int = 0, reset: Callable = Callable()) -> void:
	_factory = factory
	_reset = reset
	_max_objects = maxi(max_size, 0)
	if not factory.is_valid():
		push_error("StdObjectPool factory is not a valid Callable, the pool cannot create nodes")
		return

	prefill = maxi(prefill, 0)
	if _max_objects < prefill:
		push_warning(
				"StdObjectPool prefill exceeds capacity; creating %s nodes instead"
				% _max_objects)
		prefill = _max_objects

	for i: int in range(prefill):
		var created: StdResult = _create()
		if created.is_err():
			push_error(created.unwrap_err())
			break
		var node: Node = created.unwrap()
		_deactivate(node)
		_inactive.push_back(node)
		pass
	return


#region Engine Methods
# Available nodes remain pool-owned. Active nodes are released from pool
# ownership so callers never receive a silently freed checked-out node.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		StdObjectPool._free_all(_inactive)
		if not _active.is_empty():
			push_warning(
				"StdObjectPool freed with %d active nodes; pool ownership was released"
				% _active.size())
		_active.clear()
		_inactive.clear()
	return
#endregion Engine Methods


#region Public API
## Takes a node from the available pool and marks it active.
## Returns the acquired [Node], or an error when the pool is exhausted or
## the factory cannot create a live node.
func acquire() -> StdResult:
	_prune_invalid()
	var node: Node = null
	while not _inactive.is_empty():
		# Untyped so a node freed while inactive can be popped and
		# skipped instead of raising a script error on assignment.
		var candidate: Variant = _inactive.pop_back()
		if is_instance_valid(candidate):
			node = candidate
			break

	if node == null:
		if size() >= _max_objects:
			pool_exhausted.emit()
			return StdResult.err("object pool is exhausted")
		var created: StdResult = _create()
		if created.is_err(): return created
		node = created.unwrap()

	_active[node.get_instance_id()] = node
	object_requested.emit(node)
	return StdResult.ok(node)


## Returns an acquired node to the inactive pool, calling the reset
## [Callable] first when one was provided. Returns an error when
## [param node] is null, freed, not a [Node], or not currently
## acquired from this pool (which also covers releasing twice). On
## success, the contained value is the released node. The parameter is a
## [Variant] so a freed reference produces an error instead of a script error.
func release(node: Variant) -> StdResult:
	if not is_instance_valid(node):
		return StdResult.err("released node is null or freed")
	if node is not Node:
		return StdResult.err("released value is not a Node")
	if not _active.erase(node.get_instance_id()):
		return StdResult.err("node was not acquired from this pool")

	if _reset != Callable():
		if _reset.is_valid():
			_reset.call(node)
		else:
			push_warning("StdObjectPool reset is no longer a valid Callable, skipping reset")
	_deactivate(node)
	_inactive.push_back(node)
	object_released.emit(node)
	return StdResult.ok(node)


## Returns [code]true[/code] if [param node] is held by this pool, whether
## active or inactive. The parameter is a [Variant] so [code]null[/code] and
## freed references return [code]false[/code] instead of causing a script error.
func has(node: Variant) -> bool:
	if not is_instance_valid(node) or node is not Node: return false
	return _active.has(node.get_instance_id()) or _inactive.has(node)


## Returns the number of nodes currently acquired.
func active_count() -> int:
	_prune_invalid()
	return _active.size()


## Returns the number of nodes waiting to be acquired.
func available_count() -> int:
	_prune_invalid()
	return _inactive.size()


## Returns the total number of active and inactive nodes owned by the pool.
func size() -> int:
	_prune_invalid()
	return _active.size() + _inactive.size()


## Returns the maximum number of nodes the pool can own.
func capacity() -> int:
	return _max_objects


## Returns [code]true[/code] if the pool owns no nodes.
func is_empty() -> bool:
	return size() == 0


## Returns [code]true[/code] if the next [method acquire] would fail because
## no node is available and the pool is at [method capacity].
func is_exhausted() -> bool:
	_prune_invalid()
	return _inactive.is_empty() and size() >= _max_objects


## Frees every available node.
## Returns the number freed, or an error without changing the pool when any
## nodes are active.
func clear() -> StdResult:
	_prune_invalid()
	if not _active.is_empty():
		return StdResult.err(
				"cannot clear object pool while %d nodes are active; release them or call destroy()"
				% _active.size())
	var freed: int = _inactive.size()
	StdObjectPool._free_all(_inactive)
	_inactive.clear()
	return StdResult.ok(freed)


## Destructively frees every active and available node.
## Any references held by callers become invalid.
func destroy() -> void:
	StdObjectPool._free_all(_active.values())
	StdObjectPool._free_all(_inactive)
	_active.clear()
	_inactive.clear()
	return


## Removes externally freed active and inactive nodes.
## Returns the number of stale capacity entries reclaimed.
func prune_invalid() -> int:
	return _prune_invalid()
#endregion Public API


#region Private Helpers
# Detaching is the pool's safe inactive state. The caller chooses where to
# parent a node after the next acquire.
func _deactivate(node: Node) -> void:
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	return


# Removes freed nodes from both ownership collections.
func _prune_invalid() -> int:
	var removed: int = 0
	for id: int in _active.keys():
		if is_instance_valid(_active[id]):
			continue
		_active.erase(id)
		removed += 1
		pass
	for i: int in range(_inactive.size() - 1, -1, -1):
		if is_instance_valid(_inactive[i]):
			continue
		_inactive.remove_at(i)
		removed += 1
		pass
	return removed


# Builds one live Node or returns a descriptive error.
func _create() -> StdResult:
	if not _factory.is_valid():
		return StdResult.err("object pool factory is not a valid Callable")
	var node: Variant = _factory.call()
	if node is not Node:
		return StdResult.err("object pool factory must return a Node, got: %s" % type_string(typeof(node)))
	if not is_instance_valid(node):
		return StdResult.err("object pool factory returned a freed Node")
	return StdResult.ok(node)


# Untyped loop so nodes freed externally are skipped instead of
# raising a script error on assignment.
static func _free_all(nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			node.free()
	return
#endregion Private Helpers
