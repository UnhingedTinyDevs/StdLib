class_name StdSet
extends IStdCollection
## An unordered collection of unique values.
##
## Values use Godot's normal [Dictionary] key behavior unless an identifier
## [Callable] is supplied. The identifier maps each value to its membership key.
## [codeblock lang=gdscript]
##     var set: StdSet = StdSet.from_array([1, 1, 2])
##     set.size() # 2
## [/codeblock]

## Emitted after [param item] is added to the set.
signal item_pushed(item: Variant)
## Emitted after [param item] is removed from the set.
signal item_popped(item: Variant)


var _items: Dictionary = {}
var _identifier: Callable


## Creates an empty set. When supplied, [param identifier] selects the key used
## to determine whether two values are the same set member. Identifiers must be
## stable while their values are stored.
func _init(identifier: Callable = Callable()) -> void:
	_identifier = identifier
	return


#region Public API
## Returns [code]true[/code] if the set contains no values.
func is_empty() -> bool:
	return _items.is_empty()


## Returns the number of unique values in the set.
func size() -> int:
	return _items.size()


## Removes every value from the set.
func clear() -> void:
	_items.clear()
	cleared.emit()
	size_changed.emit(0)
	return


## Returns [code]true[/code] if [param item] belongs to the set.
func has(item: Variant) -> bool:
	return _items.has(_key(item))


## Returns the originally stored value matching [param item], or
## [code]none[/code] when no matching key exists.
func peek(item: Variant) -> StdOption:
	var key: Variant = _key(item)
	if not _items.has(key):
		return StdOption.none()
	return StdOption.some(_items[key])


## Adds [param item] when its key is not already present.
func push(item: Variant) -> void:
	var key: Variant = _key(item)
	if _items.has(key):
		return

	_items[key] = item
	item_pushed.emit(item)
	size_changed.emit(size())
	return


## Removes the value matching [param item], returning the originally stored
## value, or [code]none[/code] when no matching key exists.
func pop(item: Variant) -> StdOption:
	var key: Variant = _key(item)
	if not _items.has(key):
		return StdOption.none()

	var stored: Variant = _items[key]
	_items.erase(key)
	item_popped.emit(stored)
	size_changed.emit(size())
	return StdOption.some(stored)


## Maps every stored value into a new set using Godot's default keys.
## Returns an error when [param fn] is invalid.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper is invalid")

	var mapped: StdSet = StdSet.new()
	for item: Variant in _items.values():
		mapped.push(fn.call(item))
		pass
	return StdResult.ok(mapped)


## Returns a new set containing values accepted by [param pred].
## The new set retains this set's identifier. Returns an error when
## [param pred] is invalid.
func filter(pred: Callable) -> StdResult:
	if not pred.is_valid():
		return StdResult.err("predicate is invalid")

	var filtered: StdSet = StdSet.new(_identifier)
	for item: Variant in _items.values():
		if pred.call(item):
			filtered.push(item)
			pass
		pass
	return StdResult.ok(filtered)

#region Set Arthimetic
## Returns a new set containing values found in either set.
## Returns an error when [param other] is [code]null[/code].
func union(other: StdSet) -> StdResult:
	if other == null:
		return StdResult.err("other set is null")

	var result: StdSet = StdSet.new(_identifier)
	for item: Variant in _items.values():
		result.push(item)
		pass
	for item: Variant in other._items.values():
		result.push(item)
		pass
	return StdResult.ok(result)


## Returns a new set containing values found in both sets.
## Returns an error when [param other] is [code]null[/code].
func intersection(other: StdSet) -> StdResult:
	if other == null:
		return StdResult.err("other set is null")

	var result: StdSet = StdSet.new(_identifier)
	var other_items: Dictionary = _normalize(other)
	for key: Variant in _items:
		if other_items.has(key):
			result.push(_items[key])
			pass
		pass
	return StdResult.ok(result)


## Returns a new set containing values found in this set but not [param other].
## Returns an error when [param other] is [code]null[/code].
func difference(other: StdSet) -> StdResult:
	if other == null:
		return StdResult.err("other set is null")

	var result: StdSet = StdSet.new(_identifier)
	var other_items: Dictionary = _normalize(other)
	for key: Variant in _items:
		if not other_items.has(key):
			result.push(_items[key])
			pass
		pass
	return StdResult.ok(result)


## Returns a new set containing values found in exactly one set.
## Returns an error when [param other] is [code]null[/code].
func symmetric_difference(other: StdSet) -> StdResult:
	if other == null:
		return StdResult.err("other set is null")

	var result: StdSet = StdSet.new(_identifier)
	var other_items: Dictionary = _normalize(other)
	for key: Variant in _items:
		if not other_items.has(key):
			result.push(_items[key])
			pass
		pass
	for key: Variant in other_items:
		if not _items.has(key):
			result.push(other_items[key])
			pass
		pass
	return StdResult.ok(result)

#endregion

#region Comparison
## Returns [code]true[/code] if every value in this set is in [param other].
func subset(other: StdSet) -> bool:
	if other == null:
		return false

	var other_items: Dictionary = _normalize(other)
	if size() > other_items.size():
		return false
	for key: Variant in _items:
		if not other_items.has(key):
			return false
		pass
	return true


## Returns [code]true[/code] if this set contains every value in [param other].
func superset(other: StdSet) -> bool:
	if other == null:
		return false
	var other_items: Dictionary = _normalize(other)
	for key: Variant in other_items:
		if not _items.has(key):
			return false
		pass
	return true


## Returns [code]true[/code] if the sets have no values in common.
func disjoint(other: StdSet) -> bool:
	if other == null:
		return false

	var other_items: Dictionary = _normalize(other)
	for key: Variant in _items:
		if other_items.has(key):
			return false
		pass
	return true


## Returns [code]true[/code] if both sets contain the same values.
func equals(other: StdSet) -> bool:
	if other == null:
		return false
	var other_items: Dictionary = _normalize(other)
	if size() != other_items.size():
		return false
	for key: Variant in _items:
		if not other_items.has(key):
			return false
		pass
	return true
#endregion Comparisons

#endregion Public API


#region Type Conversions
## Creates a set containing the values in [param from].
## When supplied, [param identifier] determines each value's membership key.
static func from_array(from: Array, identifier: Callable = Callable()) -> StdSet:
	var set: StdSet = StdSet.new(identifier)
	for item: Variant in from:
		set.push(item)
		pass
	return set


## Returns a snapshot of the stored values.
func to_array() -> Array:
	return _items.values()


## Returns a snapshot of the stored values. Snapshot order is not semantic.
func values() -> Array:
	return to_array()


## Removes stored objects that were freed externally.
## Returns the number of removed entries.
func prune_invalid() -> int:
	var removed: int = 0
	for key: Variant in _items.keys():
		var value: Variant = _items.get(key)
		if not _is_freed_object(key) and not _is_freed_object(value):
			continue
		_items.erase(key)
		removed += 1
		pass
	if removed > 0:
		size_changed.emit(size())
	return removed
#endregion Type Conversions


#region Private Helpers
# Returns the membership key selected for the item.
func _key(item: Variant) -> Variant:
	if _identifier.is_valid():
		return _identifier.call(item)
	return item


# Re-keys another set using this set's identifier.
func _normalize(other: StdSet) -> Dictionary:
	var normalized: Dictionary = {}
	for item: Variant in other._items.values():
		var key: Variant = _key(item)
		if not normalized.has(key):
			normalized[key] = item
		pass
	return normalized


# Returns whether a Variant is an Object reference that has been freed.
func _is_freed_object(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and not is_instance_valid(value)
#endregion Private Helpers
