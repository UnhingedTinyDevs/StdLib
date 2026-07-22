class_name StdStack
extends IStdPushCollection
## A last-in, first-out collection.
##
## [method push] adds a value at the top. [method pop] and [method peek]
## read from the top. [Array] conversions use next-out-first order, so index
## [code]0[/code] represents the top of the stack.
## [codeblock lang=gdscript]
##     var stack: StdStack = StdStack.from_array(["top", "bottom"])
##     stack.pop() # some("top")
## [/codeblock]

var _stack: Array = []


#region Public API
## Pushes [param value] onto the top.
func push(value: Variant) -> void:
	_stack.push_back(value)
	pushed.emit(value)
	size_changed.emit(_stack.size())
	return


## Removes and returns the top value, or [code]none[/code] when empty.
func pop() -> StdOption:
	if is_empty(): return StdOption.none()
	var val: Variant = _stack.pop_back()
	popped.emit(val)
	size_changed.emit(_stack.size())
	return StdOption.some(val)


## Returns the top value without removing it, or [code]none[/code] when empty.
func peek() -> StdOption:
	if is_empty(): return StdOption.none()
	return StdOption.some(_stack.back())


## Replaces the top with the value returned by [param mutator].
## Returns the replacement value, or an error when the stack is empty or
## [param mutator] is invalid.
func mutate(mutator: Callable) -> StdResult:
	if is_empty(): return StdResult.err("stack is empty")
	if not mutator.is_valid(): return StdResult.err("mutator is invalid")

	# 1. remove the old one
	var old: Variant = _stack.pop_back() # take the old one off
	# 2. Create the new mutated value
	var new: Variant = mutator.call(old) # create the new onw
	# 3. Add the mutated value to the top of the stack
	_stack.push_back(new)
	# 4. Emit the signal
	mutated.emit(new, old)
	return StdResult.ok(new)


## Returns [code]true[/code] if the stack contains [param value].
func has(value: Variant) -> bool:
	return _stack.has(value)


## Returns a new [StdStack] containing values accepted by [param pred].
## The pop order of accepted values is preserved.
func filter(pred: Callable) -> StdResult:
	if not pred.is_valid():
		return StdResult.err("predicate is invalid")
	return StdResult.ok(StdStack.from_array(to_array().filter(pred)))


## Returns a new [StdStack] containing each value transformed by [param fn].
## The pop order is preserved.
func map(fn: Callable) -> StdResult:
	if not fn.is_valid():
		return StdResult.err("mapper is invalid")
	return StdResult.ok(StdStack.from_array(to_array().map(fn)))


## Returns the number of values in the stack.
func size() -> int:
	return _stack.size()


## Returns [code]true[/code] if the stack contains no values.
func is_empty() -> bool:
	return _stack.is_empty()


## Removes every value from the stack.
func clear() -> void:
	_stack.clear()
	cleared.emit()
	size_changed.emit(_stack.size())
	return

#endregion Public API


#region Type Conversions
## Creates a stack whose top is the first element of [param from].
static func from_array(from: Array) -> StdStack:
	var stack: StdStack = StdStack.new()
	stack._stack = from.duplicate()
	stack._stack.reverse()
	return stack


## Returns a top-to-bottom snapshot in pop order.
func to_array() -> Array:
	var result: Array = _stack.duplicate()
	result.reverse()
	return result
#endregion Type Conversions
