extends StdTest
## Headless tests for StdObjectPool.


var _node_factory: Callable = func() -> Node: return Node.new()


func _test_empty_pool_and_exhaustion_error() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 0)
	assert_true(pool.is_empty(), "zero-capacity pool is empty")
	assert_eq(pool.capacity(), 0, "capacity is zero")
	assert_true(pool.is_exhausted(), "zero-capacity pool is exhausted")
	assert_err(pool.acquire(), "exhaustion is an explicit error")
	return


func _test_negative_capacity_and_prefill_clamp_to_zero() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, -10, -20)
	assert_eq(pool.capacity(), 0, "negative capacity clamps to zero")
	assert_eq(pool.size(), 0, "negative prefill creates no nodes")
	assert_true(pool.is_exhausted(), "clamped zero-capacity pool is exhausted")
	assert_err(pool.acquire(), "clamped zero-capacity acquire errors")
	return


func _test_prefill_and_counts() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 5, 3)
	assert_eq(pool.available_count(), 3, "prefill creates available nodes")
	assert_eq(pool.active_count(), 0, "prefill activates nothing")
	assert_eq(pool.size(), 3, "size counts active plus available")
	assert_eq(pool.capacity(), 5, "capacity reports total ceiling")
	var acquired: StdResult = pool.acquire()
	assert_ok(acquired, "prefilled node can be acquired")
	assert_eq(pool.active_count(), 1, "acquire increments active")
	assert_eq(pool.available_count(), 2, "acquire decrements available")
	pool.destroy()
	return


func _test_prefill_clamps_to_capacity() -> void:
	expect_warning("StdObjectPool prefill exceeds capacity", "oversized prefill warns")
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 2, 5)
	assert_eq(pool.size(), 2, "prefill clamps to capacity")
	pool.destroy()
	return


func _test_release_round_trip_and_reset() -> void:
	var reset: Callable = func(node: Node) -> void: node.set_meta("reset", true)
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 2, 1, reset)
	var node: Node = pool.acquire().unwrap()
	assert_ok(pool.release(node), "release accepts acquired node")
	assert_true(node.get_meta("reset", false), "release invokes reset")
	assert_eq(pool.available_count(), 1, "released node becomes available")
	assert_eq(pool.acquire().unwrap(), node, "acquire reuses released node")
	pool.destroy()
	return


func _test_signals_report_acquire_release_and_exhaustion() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 1)
	var requested: Array[Node] = []
	var released: Array[Node] = []
	var exhausted: Array[bool] = []
	pool.object_requested.connect(func(node: Node) -> void: requested.push_back(node))
	pool.object_released.connect(func(node: Node) -> void: released.push_back(node))
	pool.pool_exhausted.connect(func() -> void: exhausted.push_back(true))
	var node: Node = pool.acquire().unwrap()
	assert_err(pool.acquire(), "second acquire exhausts capacity")
	assert_ok(pool.release(node), "release succeeds")
	assert_eq(requested, [node], "successful acquire emits requested")
	assert_eq(released, [node], "successful release emits released")
	assert_eq(exhausted, [true], "exhausted acquire emits exhausted")
	pool.destroy()
	return


func _test_release_detaches_from_scene_tree() -> void:
	var parent: Node = Node.new()
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 1)
	var node: Node = pool.acquire().unwrap()
	parent.add_child(node)
	assert_ok(pool.release(node), "parented node releases")
	assert_eq(node.get_parent(), null, "inactive node is detached")
	assert_eq(parent.get_child_count(), 0, "inactive node cannot keep processing under parent")
	pool.destroy()
	parent.free()
	return


func _test_release_errors() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 1)
	var node: Node = pool.acquire().unwrap()
	var foreign: Node = Node.new()
	assert_err(pool.release(foreign), "foreign release errs")
	assert_ok(pool.release(node), "first release succeeds")
	assert_err(pool.release(node), "double release errs")
	assert_err(pool.release(null), "null release errs")
	foreign.free()
	pool.destroy()
	return


func _test_factory_error_is_returned() -> void:
	var pool: StdObjectPool = StdObjectPool.new(func() -> Variant: return null, 2)
	assert_err(pool.acquire(), "invalid factory result is an error")
	assert_eq(pool.size(), 0, "failed creation consumes no capacity")
	return


func _test_freed_available_node_is_skipped() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 2, 2)
	var node: Node = pool.acquire().unwrap()
	var _released: StdResult = pool.release(node)
	node.free()
	var acquired: StdResult = pool.acquire()
	assert_ok(acquired, "freed available node is skipped")
	assert_true(is_instance_valid(acquired.unwrap()), "replacement node is live")
	assert_eq(pool.size(), 1, "dead available node no longer counts")
	pool.destroy()
	return


func _test_freed_active_node_reclaims_capacity() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 1)
	var dead: Node = pool.acquire().unwrap()
	dead.free()
	assert_eq(pool.prune_invalid(), 1, "dead active entry is pruned")
	assert_eq(pool.active_count(), 0, "dead active entry no longer counts")
	var replacement: StdResult = pool.acquire()
	assert_ok(replacement, "reclaimed capacity can create a replacement")
	assert_true(is_instance_valid(replacement.unwrap()), "replacement is live")
	pool.destroy()
	return


func _test_clear_refuses_active_nodes() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 2, 2)
	var active: Node = pool.acquire().unwrap()
	assert_err(pool.clear(), "clear refuses while a node is active")
	assert_true(is_instance_valid(active), "failed clear leaves active node alive")
	assert_eq(pool.size(), 2, "failed clear leaves pool unchanged")
	var _released: StdResult = pool.release(active)
	var cleared: StdResult = pool.clear()
	assert_ok(cleared, "clear succeeds after all nodes are released")
	assert_eq(cleared.unwrap(), 2, "clear reports freed available count")
	assert_true(pool.is_empty(), "successful clear empties pool")
	assert_ok(pool.acquire(), "pool remains reusable after clear")
	pool.destroy()
	return


func _test_destroy_is_explicitly_destructive() -> void:
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 2, 1)
	var active: Node = pool.acquire().unwrap()
	var available: Node = pool.acquire().unwrap()
	var _released: StdResult = pool.release(available)
	pool.destroy()
	assert_true(not is_instance_valid(active), "destroy frees active node")
	assert_true(not is_instance_valid(available), "destroy frees available node")
	assert_true(pool.is_empty(), "destroy empties pool")
	return


func _test_pool_free_releases_active_ownership_and_frees_available() -> void:
	expect_warning("StdObjectPool freed with 1 active nodes", "freeing an active pool warns")
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 2, 1)
	var active: Node = pool.acquire().unwrap()
	var available: Node = pool.acquire().unwrap()
	var _released: StdResult = pool.release(available)
	pool = null
	assert_true(is_instance_valid(active), "pool destruction detaches active node")
	assert_true(not is_instance_valid(available), "pool destruction frees available node")
	active.free()
	return


func _test_deterministic_stress_respects_capacity_and_ownership() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x9001
	var pool: StdObjectPool = StdObjectPool.new(_node_factory, 64, 16)
	var active: Array[Node] = []
	for step: int in range(3000):
		if active.is_empty() or (active.size() < pool.capacity() and rng.randi_range(0, 1) == 0):
			var acquired: StdResult = pool.acquire()
			assert_ok(acquired, "stress acquire succeeds within capacity")
			active.push_back(acquired.unwrap())
		else:
			var index: int = rng.randi_range(0, active.size() - 1)
			var node: Node = active.pop_at(index)
			assert_ok(pool.release(node), "stress release succeeds for active node")
		assert_eq(pool.active_count(), active.size(), "stress active count matches model")
		assert_true(pool.size() <= pool.capacity(), "stress size stays within capacity")
		pass
	for node: Node in active:
		assert_ok(pool.release(node), "stress cleanup release succeeds")
		pass
	assert_eq(pool.active_count(), 0, "stress cleanup releases every active node")
	assert_eq(pool.size(), pool.available_count(), "all stress nodes become available")
	pool.destroy()
	return
