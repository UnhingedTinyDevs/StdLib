class_name StdOption
extends "res://addons/std_lib/std-returns/scripts/std_return.gd"
## An explicit optional value.
##
## Wraps an optional value: either [code]Some(value)[/code] or [code]None[/code].
## Construct with [code]StdOption.some[/code] or [code]StdOption.none[/code].
## [code]some(null)[/code] is present and distinct from [code]none()[/code].
## [codeblock lang=gdscript]
##     var target: StdOption = find_target()
##     if target.is_some():
##         use_target(target.unwrap())
## [/codeblock]

# Construct through some() or none(); direct construction exists for factories.
func _init(type: Returns, value: Variant = null) -> void:
	super(type, value)
	if type == Returns.SOME or type == Returns.NONE:
		# makes sure the types are valid otherwise error.
		return

	var message: String = "StdOption constructed with invalid return type %s" % type
	_fail(message)

	# If play back is resumed during debug the Option should become none.
	# keeps bad value from leaking into the game.
	_type = Returns.NONE
	_value = null

	return

## Creates an option wrapping the provided value.
## Prefer this factory over direct construction.
static func some(value: Variant) -> StdOption:
	return StdOption.new(Returns.SOME, value)


## Creates an empty option.
## Prefer this factory over direct construction.
static func none() -> StdOption:
	return StdOption.new(Returns.NONE)


## Returns true if the option is some
func is_some() -> bool:
	return _type == Returns.SOME


## Returns true if the option is None
func is_none() -> bool:
	return _type == Returns.NONE


## Returns true if the option is some and the value inside of it
## matches the predicate.
func is_some_and(cb: Callable) -> bool:
	if not is_some():
		return false
	if not _valid_callable(cb, "StdOption.is_some_and()"):
		return false
	return cb.call(_value)


## Returns true if the option is none or the value inside of it
## matches the predicate
func is_none_or(cb: Callable) -> bool:
	if is_none():
		return true
	if not _valid_callable(cb, "StdOption.is_none_or()"):
		return false
	return cb.call(_value)


## Returns a new option containing the value produced by [param cb] when this
## option is some. A none option passes through unchanged.
func map(cb: Callable) -> StdOption:
	if is_none():
		return self
	if not _valid_callable(cb, "StdOption.map()"):
		return self
	return StdOption.some(cb.call(_value))


## Returns the value produced by [param cb] when this option is some, or the
## eagerly supplied [param default] when it is none.
func map_or(default: Variant, cb: Callable) -> Variant:
	if is_none():
		return default
	if not _valid_callable(cb, "StdOption.map_or()"):
		return default
	return cb.call(_value)


## Returns the value produced by [param cb] when this option is some, or the
## value produced by [param default_cb] when it is none. Only the selected
## callable runs.
func map_or_else(default_cb: Callable, cb: Callable) -> Variant:
	if is_some():
		if not _valid_callable(cb, "StdOption.map_or_else()"):
			return null
		return cb.call(_value)
	if not _valid_callable(default_cb, "StdOption.map_or_else()"):
		return null
	return default_cb.call()


## Calls [param cb] with the wrapped value when this option is some, then
## returns this option unchanged. Useful for side effects such as logging.
func inspect(cb: Callable) -> StdOption:
	if is_none():
		return self
	if not _valid_callable(cb, "StdOption.inspect()"):
		return self
	cb.call(_value)
	return self


## Returns this option when it is some and its value satisfies
## [param predicate]. Returns none when absent or rejected.
func filter(predicate: Callable) -> StdOption:
	if is_none():
		return self
	if not _valid_callable(predicate, "StdOption.filter()"):
		return StdOption.none()
	return self if predicate.call(_value) else StdOption.none()


## Returns [param option] when this option is some, otherwise returns this none
## option. The alternative is supplied eagerly and must not be null.
func and_opt(option: StdOption) -> StdOption:
	if not _valid_option(option, "StdOption.and_opt()"):
		return StdOption.none()
	return option if is_some() else self


## Returns the option produced by [param cb] when this option is some,
## otherwise returns this none option unchanged. The callable must return an
## [code]StdOption[/code].
func and_then(cb: Callable) -> StdOption:
	if is_none():
		return self
	if not _valid_callable(cb, "StdOption.and_then()"):
		return StdOption.none()
	var option: Variant = cb.call(_value)
	if option is StdOption:
		return option as StdOption
	_fail("StdOption.and_then() callback must return an StdOption")
	return StdOption.none()


## Returns this option when it is some, otherwise returns the eagerly supplied
## [param option], which must not be null.
func or_opt(option: StdOption) -> StdOption:
	if not _valid_option(option, "StdOption.or_opt()"):
		return self
	return self if is_some() else option


## Returns this option when it is some, otherwise returns the option produced
## by [param cb]. The callable must return an [code]StdOption[/code].
func or_else(cb: Callable) -> StdOption:
	if is_some():
		return self
	if not _valid_callable(cb, "StdOption.or_else()"):
		return self
	var option: Variant = cb.call()
	if option is StdOption:
		return option as StdOption
	_fail("StdOption.or_else() callback must return an StdOption")
	return self


## Returns the one some option when exactly one of this option and
## [param option] is some. Returns none when both have the same side. The
## operand must not be null.
func xor_opt(option: StdOption) -> StdOption:
	if not _valid_option(option, "StdOption.xor_opt()"):
		return StdOption.none()
	if is_some():
		return StdOption.none() if option.is_some() else self
	return option if option.is_some() else self


## Removes one level of nesting from an [code]StdOption[lb]StdOption[rb][/code]. A
## some value that is not an [code]StdOption[/code] is an invariant violation.
func flatten() -> StdOption:
	if is_none():
		return self
	if _value is StdOption:
		return _value as StdOption
	_fail("StdOption.flatten() called on a Some value that does not contain an StdOption")
	return StdOption.none()


## Converts this option to a [code]StdResult[/code], wrapping a some value as ok or the
## eagerly supplied [param error] as err when none.
func ok_or(error: Variant) -> StdResult:
	return StdResult.ok(_value) if is_some() else StdResult.err(error)


## Converts this option to a [code]StdResult[/code], wrapping a some value as ok or the value
## produced by [param cb] as err when none.
func ok_or_else(cb: Callable) -> StdResult:
	if is_some():
		return StdResult.ok(_value)
	var message: String = "StdOption.ok_or_else() called with an invalid Callable"
	if not _valid_callable(cb, "StdOption.ok_or_else()"):
		return StdResult.err(message)
	return StdResult.err(cb.call())


## Returns the some value. If none, halts on an assertion in debug builds and
## crashes release builds with the provided message. If debug execution is
## manually resumed, returns [code]null[/code]. Use [code]StdOption.unwrap_or[/code]
## when absence should be recoverable.
func expect(msg: String) -> Variant:
	if not is_some():
		_fail(msg)
		return null
	return _value


## Returns the contained some value. If none, halts on an assertion in debug
## builds and crashes release builds. If debug execution is manually resumed,
## returns [code]null[/code]. Use [code]StdOption.unwrap_or[/code] when absence should
## be recoverable.
func unwrap() -> Variant:
	if not is_some():
		_fail("called StdOption.unwrap() on a None value")
		return null
	return _value


## Returns the some value or the provided default.
func unwrap_or(default: Variant) -> Variant:
	return _value if is_some() else default


## Returns the some value or the value returned by the provided
## [Callable]
func unwrap_or_else(cb: Callable) -> Variant:
	if is_some():
		return _value
	if not _valid_callable(cb, "StdOption.unwrap_or_else()"):
		return null
	return cb.call()


# Rejects a null operand before a composition method uses it.
func _valid_option(option: StdOption, caller: String) -> bool:
	if option != null:
		return true
	_fail("%s called with a null StdOption" % caller)
	return false
