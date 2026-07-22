class_name StdBag
extends IStdPushCollection
## An unordered collection that stores repeated values with weighted random removal.
##
## A [StdBag] is backed by a [Dictionary] whose keys are the stored values and whose
## values are their occurrence counts. Unlike a [StdSet], pushing a value that is
## already present adds another occurrence.
##
## Because a bag has no ordering, [method sample], [method pop], and [method mutate]
## select a random occurrence using the [RandomNumberGenerator] supplied at
## construction. Repeated values are naturally weighted by their occurrence counts.
## [method sample] leaves the selected occurrence in the bag, while [method pop]
## removes it. [method peek] returns a snapshot of every occurrence instead of
## identifying a next value.
## [codeblock lang=gdscript]
##     var rng: RandomNumberGenerator = RandomNumberGenerator.new()
##     var bag: StdBag = StdBag.from_array(["common", "common", "rare"], rng)
##     bag.sample() # Selects one weighted random occurrence.
##     bag.pop()    # Selects and removes one weighted random occurrence.
## [/codeblock]


var _counts: Dictionary = {}
var _items: int = 0
var _rng: RandomNumberGenerator


## Creates an empty bag that draws with [param rng].
func _init(rng: RandomNumberGenerator) -> void:
	assert(rng != null, "StdBag requires a RandomNumberGenerator")
	_rng = rng
	return


#region Public API
## Adds one occurrence of [param item] to the bag.
func push(item: Variant) -> void:
	var old_size: int = size()
	_add_one(item)
	pushed.emit(item)
	if size() != old_size:
		size_changed.emit(size())
	return


## Adds [param n] occurrences of [param item] to the bag.
## Non-positive values are ignored.
func push_n(item: Variant, n: int = 1) -> void:
	if n <= 0:
		return
	var old_size: int = size()
	for occurrence: int in n:
		_add_one(item)
		pushed.emit(item)
		pass
	if size() != old_size:
		size_changed.emit(size())
	return


## Selects one random occurrence without removing it, or [code]none[/code] when
## the bag is empty. A successful sample advances the bag's generator.
func sample() -> StdOption:
	return _random_item()


## Removes and returns one random occurrence, or [code]none[/code] when the
## bag is empty.
func pop() -> StdOption:
	var selected: StdOption = _random_item()
	if selected.is_none():
		return selected

	var old_size: int = size()
	var item: Variant = selected.unwrap()
	_remove_one(item)
	popped.emit(item)

	if size() != old_size:
		size_changed.emit(size())
		pass

	return StdOption.some(item)


## Removes and returns one occurrence equal to [param item], or [code]none[/code]
## if the bag does not contain it.
func pop_item(item: Variant) -> StdOption:
	if not has(item):
		return StdOption.none()
	var old_size: int = size()
	_remove_one(item)
	popped.emit(item)
	if size() != old_size:
		size_changed.emit(size())
	return StdOption.some(item)


## Removes every occurrence equal to [param item].
## Returns the number of removed occurrences.
func pop_all(item: Variant) -> int:
	var removed: int = count(item)
	if removed == 0:
		return 0
	_counts.erase(item)
	_items -= removed
	for occurrence: int in removed:
		popped.emit(item)
		pass
	size_changed.emit(size())
	return removed


## Returns an expanded snapshot of the bag, or [code]none[/code] when empty.
## Repeated values appear once for each occurrence. Snapshot order is not
## semantic and must not be used to predict [method pop].
func peek() -> StdOption:
	if is_empty():
		return StdOption.none()

	return StdOption.some(to_array())


## Replaces one random occurrence with the value returned by [param mutator].
## The total item count does not change. Returns the replacement value, or an
## error when the bag is empty or the [Callable] is invalid.
func mutate(mutator: Callable) -> StdResult:
	if is_empty():
		return StdResult.err("bag is empty")

	if not mutator.is_valid():
		return StdResult.err("mutator is invalid")

	var selected: StdOption = _random_item()
	var old: Variant = selected.unwrap()
	var new: Variant = mutator.call(old)
	var old_size: int = size()
	_remove_one(old)
	_add_one(new)
	mutated.emit(new, old)

	if size() != old_size:
		size_changed.emit(size())
		pass

	return StdResult.ok(new)


## Returns [code]true[/code] if the bag contains at least one occurrence of
## [param item].
func has(item: Variant) -> bool:
	return _counts.has(item)


## Returns the number of occurrences of [param item].
func count(item: Variant) -> int:
	if not _counts.has(item):
		return 0
	return _counts[item]


## Returns [code]true[/code] if the bag contains no occurrences.
func is_empty() -> bool:
	return _items == 0


## Removes every occurrence from the bag.
func clear() -> void:
	_counts.clear()
	_items = 0
	cleared.emit()
	size_changed.emit(0)
	return


## Returns the number of unique values in the bag.
func size() -> int:
	return _counts.size()


## Returns the total number of occurrences in the bag, including duplicates.
func items() -> int:
	return _items


## Maps every occurrence through [param fn] into a new [StdBag].
## Occurrences whose mapped values are equal are combined under one key.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper is invalid")

	var mapped: StdBag = StdBag.new(_copy_rng())
	for item: Variant in to_array():
		mapped.push(fn.call(item))
		pass
	return StdResult.ok(mapped)


## Returns a new [StdBag] containing every occurrence accepted by [param pred].
## The predicate is called separately for each occurrence.
func filter(pred: Callable) -> StdResult:
	if not pred.is_valid():
		return StdResult.err("predicate is invalid")

	var filtered: StdBag = StdBag.new(_copy_rng())
	for item: Variant in to_array():
		if pred.call(item):
			filtered.push(item)
			pass
		pass
	return StdResult.ok(filtered)


## Returns an expanded snapshot containing one entry per occurrence.
## The returned [Array] has no semantic ordering.
func to_array() -> Array:
	var result: Array = []
	result.resize(_items)
	var index: int = 0
	for item: Variant in _counts:
		for occurrence: int in count(item):
			result[index] = item
			index += 1
			pass
		pass
	return result


## Creates a bag containing every value in [param from] and drawing with
## [param rng].
static func from_array(from: Array, rng: RandomNumberGenerator) -> StdBag:
	var bag: StdBag = StdBag.new(rng)
	for item: Variant in from:
		bag._add_one(item)
		pass
	return bag
#endregion Public API


#region Private Helpers
# Adds one occurrence without emitting collection signals.
func _add_one(item: Variant) -> void:
	_counts[item] = count(item) + 1
	_items += 1
	return


# Removes one occurrence and erases its key when its count reaches zero.
func _remove_one(item: Variant) -> void:
	var remaining: int = count(item) - 1
	if remaining <= 0:
		_counts.erase(item)
	else:
		_counts[item] = remaining
	_items -= 1
	return


# Selects one occurrence using count-weighted random sampling.
func _random_item() -> StdOption:
	if is_empty():
		return StdOption.none()

	var offset: int = _rng.randi_range(0, _items - 1)
	for item: Variant in _counts:
		offset -= count(item)
		if offset < 0:
			return StdOption.some(item)
		pass
	return StdOption.none()


# Copies the generator state so derived bags draw independently from the same point.
func _copy_rng() -> RandomNumberGenerator:
	var copy: RandomNumberGenerator = RandomNumberGenerator.new()
	copy.seed = _rng.seed
	copy.state = _rng.state
	return copy
#endregion Private Helpers
