class_name StdHeap
extends IStdPriorityCollection
## A binary min-heap or max-heap for prioritized values.
##
## [method push] inserts a value with an integer priority. [method pop] and
## [method peek] read the value nearest the root according to [enum StdHeap.Order].
## Values with equal priorities are returned in insertion order.
## [codeblock lang=gdscript]
##     var heap: StdHeap = StdHeap.new(StdHeap.Order.MIN)
##     heap.push("later", 10)
##     heap.push("now", 1)
##     heap.pop() # some("now")
## [/codeblock]

## Determines whether lower or higher priorities are returned first.
enum Order {
	## Returns lower priority values first.
	MIN,
	## Returns higher priority values first.
	MAX,
}

# This is a heap a simple array with some quick maths
var _heap: Array[StdHeapNode] = []
var _seq: int = 0
var _order: Order

#region Engine Methods
## Creates an empty heap using [param order].
func _init(order: Order = Order.MIN) -> void:
	_heap = []
	_seq = 0
	_order = order
	return

#endregion Engine Methods


#region Collection Methods
## Removes every value from the heap.
func clear() -> void:
	_heap.clear()
	_seq = 0
	cleared.emit()
	size_changed.emit(0)
	return


## Returns [code]true[/code] if the heap contains no values.
func is_empty() -> bool:
	return _heap.is_empty()


## Returns the number of values in the heap.
func size() -> int:
	return _heap.size()


## Returns [code]true[/code] if the heap contains [param item].
func has(item: Variant) -> bool:
	for n: StdHeapNode in _heap:
		if n.value == item:
			return true
	return false


## Adds [param value] with [param priority].
## Values with equal priorities retain their insertion order.
func push(value: Variant, priority: int) -> void:
	# 1. create a new heap node
	var node: StdHeapNode = StdHeapNode.new(value, priority, _seq)
	_seq += 1 # increment the sequence for the next node.
	# 2. add the heap node to the back of the heap.
	_heap.push_back(node)
	# 3. run percolate up on the heap to rebalance it.
	_percolate_up()
	pushed.emit(value, priority)
	size_changed.emit(size())
	return


## Removes and returns the highest-ranked value, or [code]none[/code] when empty.
func pop() -> StdOption:
	if is_empty(): return StdOption.none()
	# 1. Swap the top and the last leaf node.
	_swap(0, size() - 1)
	# 2. Remove the old root (last leaf)
	var rn: StdHeapNode = _heap.pop_back()
	# 3. Run percolate down to rebalance the heap
	_percolate_down()
	popped.emit(rn.value)
	size_changed.emit(size())
	return StdOption.some(rn.value)


## Returns the highest-ranked value without removing it, or [code]none[/code]
## when empty.
func peek() -> StdOption:
	if is_empty(): return StdOption.none()
	return StdOption.some(_heap.get(0).value)


## Replaces the highest-ranked value with the result of [param mutator].
## The value's priority and insertion order remain unchanged. Returns the
## replacement value, or an error when [param mutator] is invalid.
func mutate(mutator: Callable) -> StdResult:
	if is_empty():
		return StdResult.err("heap is empty")
	if not mutator.is_valid():
		return StdResult.err("mutator is not a valid callable")

	# 1. Grab the top nodes value
	var val: Variant = _heap.get(0).value

	# 2. Run the mutator on the value
	var new_val: Variant = mutator.call(val)

	# 3. Put the new value back on the root
	_heap.get(0).value = new_val
	mutated.emit(new_val, val)
	return StdResult.ok(new_val)


## Creates a new heap by mapping every stored value through [param fn].
## Priorities, insertion order, and heap ordering are preserved.
## Returns an error when [param fn] is invalid.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper function is not valid")

	var mapped_heap: StdHeap = StdHeap.new(_order)
	for node: StdHeapNode in _heap:
		var mapped_node: StdHeapNode = StdHeapNode.new(
			fn.call(node.value),
			node.priority,
			node.sequence
		)

		# The existing layout remains valid because priority and sequence
		# have not changed.
		mapped_heap._heap.push_back(mapped_node)

	mapped_heap._seq = _seq
	return StdResult.ok(mapped_heap)


## Maps every stored value through [param fn] in place.
## Priorities, insertion order, and heap ordering are unchanged.
## Returns this heap, or an error when [param fn] is invalid.
func map_in_place(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper function is not valid")

	var old_root: Variant = null
	if not is_empty():
		old_root = _heap[0].value
	for node: StdHeapNode in _heap:
		node.value = fn.call(node.value)
	if not is_empty():
		mutated.emit(_heap[0].value, old_root)

	return StdResult.ok(self)


## Creates a new heap containing only values accepted by [param pred].
## Priorities and relative insertion order are preserved. The predicate must
## return a [bool]. Returns an error when [param pred] is invalid.
func filter(pred: Callable) -> StdResult:
	if not pred.is_valid():
		return StdResult.err("predicate is not valid")

	var filtered_heap: StdHeap = StdHeap.new(_order)
	for node: StdHeapNode in _heap:
		var keep: bool = pred.call(node.value)
		if keep:
			filtered_heap._heap.push_back(
				StdHeapNode.new(
					node.value,
					node.priority,
					node.sequence
				)
			)

	# Removing nodes can invalidate the array's heap layout.
	for idx: int in range(filtered_heap._last_internal(), -1, -1):
		filtered_heap._percolate_down(idx)

	filtered_heap._seq = _seq
	return StdResult.ok(filtered_heap)


## Removes every value rejected by [param pred] in place.
## Priorities and relative insertion order are preserved. The predicate must
## return a [bool]. Returns this heap, or an error when [param pred] is invalid.
func filter_in_place(pred: Callable) -> StdResult:
	if not pred.is_valid():
		return StdResult.err("predicate is not valid")

	var old_size: int = size()
	var write_idx: int = 0
	for read_idx: int in range(_heap.size()):
		var node: StdHeapNode = _heap[read_idx]
		var keep: bool = pred.call(node.value)
		if keep:
			_heap[write_idx] = node
			write_idx += 1

	_heap.resize(write_idx)
	# Restore heap ordering after compacting the array.
	for idx: int in range(_last_internal(), -1, -1):
		_percolate_down(idx)
	if size() != old_size:
		size_changed.emit(size())

	return StdResult.ok(self)
#endregion Collection Methods

#region Heap Methods
## Returns the parent [StdHeapNode] of the node at [param idx].
## Returns an error if the indexed node has no parent.
func parent_node(idx: int) -> StdResult:
	if not _in_bounds(idx) or idx == 0:
		return StdResult.err("No parent of index: %s" % idx)
	# 1. get the parent index
	var pidx: int = _parent_index(idx)
	# 2. make sure the index is in bounds
	if not _in_bounds(pidx):
		return StdResult.err("No parent of index: %s" % idx)
	# 3. Fetch the node and return it
	return StdResult.ok(_heap.get(pidx))


## Returns the right child [StdHeapNode] of the node at [param idx].
## Returns an error if the indexed node has no right child.
func right_node(idx: int) -> StdResult:
	if not _in_bounds(idx):
		return StdResult.err("No right child of index: %s" % idx)
	# 1. get the right index
	var cidx: int = _right_index(idx)
	# 2. make sure the index is in bounds
	if not _in_bounds(cidx):
		return StdResult.err("No right child of index: %s" % idx)
	# 3. Fetch the node and return it
	return StdResult.ok(_heap.get(cidx))


## Returns the left child [StdHeapNode] of the node at [param idx].
## Returns an error if the indexed node has no left child.
func left_node(idx: int) -> StdResult:
	if not _in_bounds(idx):
		return StdResult.err("No left child of index: %s" % idx)
	# 1. get the left index
	var cidx: int = _left_index(idx)
	# 2. make sure the index is in bounds
	if not _in_bounds(cidx):
		return StdResult.err("No left child of index: %s" % idx)
	# 3. Fetch the node and return it
	return StdResult.ok(_heap.get(cidx))


## Returns the priority of the parent of the node at [param idx].
## Returns an error if the indexed node has no parent.
func parent_priority(idx: int) -> StdResult:
	var rv: StdResult = parent_node(idx)
	if rv.is_err(): return rv
	var pri: int = (rv.unwrap() as StdHeapNode).priority
	return StdResult.ok(pri)


## Returns the priority of the right child of the node at [param idx].
## Returns an error if the indexed node has no right child.
func right_priority(idx: int) -> StdResult:
	var rv: StdResult = right_node(idx)
	if rv.is_err(): return rv
	var pri: int = (rv.unwrap() as StdHeapNode).priority
	return StdResult.ok(pri)



## Returns the priority of the left child of the node at [param idx].
## Returns an error if the indexed node has no left child.
func left_priority(idx: int) -> StdResult:
	var rv: StdResult = left_node(idx)
	if rv.is_err(): return rv
	var pri: int = (rv.unwrap() as StdHeapNode).priority
	return StdResult.ok(pri)



## Returns the value of the parent of the node at [param idx].
## Returns an error if the indexed node has no parent.
func parent_value(idx: int) -> StdResult:
	var rv: StdResult = parent_node(idx)
	if rv.is_err(): return rv
	var val: Variant = (rv.unwrap() as StdHeapNode).value
	return StdResult.ok(val)



## Returns the value of the right child of the node at [param idx].
## Returns an error if the indexed node has no right child.
func right_value(idx: int) -> StdResult:
	var rv: StdResult = right_node(idx)
	if rv.is_err(): return rv
	var val: Variant = (rv.unwrap() as StdHeapNode).value
	return StdResult.ok(val)



## Returns the value of the left child of the node at [param idx].
## Returns an error if the indexed node has no left child.
func left_value(idx: int) -> StdResult:
	var rv: StdResult = left_node(idx)
	if rv.is_err(): return rv
	var val: Variant = (rv.unwrap() as StdHeapNode).value
	return StdResult.ok(val)

#endregion Heap Methods

#region Helpers
# Returns whether the index identifies a stored heap node.
func _in_bounds(idx: int) -> bool:
	if idx < 0 or idx > _heap.size() - 1: return false
	return true

# Calculates the left child index in the implicit binary-tree layout.
func _left_index(idx: int) -> int:
	return 2 * idx + 1

# Calculates the right child index in the implicit binary-tree layout.
func _right_index(idx: int) -> int:
	return 2 * idx + 2

# Calculates the parent index in the implicit binary-tree layout.
func _parent_index(idx: int) -> int:
	return (idx - 1) / 2

# Returns the last index that can have at least one child.
func _last_internal() -> int:
	return (self.size() / 2) - 1

# Restores heap order starting from the newest leaf.
func _percolate_up() -> void:
	var idx: int = _heap.size() - 1
	while idx > 0:
		var parent_idx: int = _parent_index(idx)

		if not _comes_before(_heap[idx], _heap[parent_idx]):
			break

		_swap(idx, parent_idx)
		idx = parent_idx

# Restores heap order below the node at the starting index.
func _percolate_down(start_idx: int = 0) -> void:
	var idx: int = start_idx
	while true:
		var left_idx: int = _left_index(idx)
		if not _in_bounds(left_idx):
			return

		var right_idx: int = _right_index(idx)
		var best_idx: int = left_idx

		if _in_bounds(right_idx)and _comes_before(_heap[right_idx], _heap[left_idx]):
			best_idx = right_idx

		if not _comes_before(_heap[best_idx], _heap[idx]):
			return

		_swap(idx, best_idx)
		idx = best_idx

# Returns whether the first node should appear closer to the root than the second.
func _comes_before(a: StdHeapNode, b: StdHeapNode) -> bool:
	# if equal use sequence
	if a.priority == b.priority:
		return a.sequence < b.sequence
	# min heap ordering
	if _order == Order.MIN: return a.priority < b.priority
	# max heap ordering
	return a.priority > b.priority

# Exchanges two nodes in the heap array.
func _swap(a: int, b: int) -> void:
	var temp: StdHeapNode = _heap[a]
	_heap[a] = _heap[b]
	_heap[b] = temp
#endregion
