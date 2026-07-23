class_name StdResult
extends "res://addons/std_lib/std-returns/scripts/std_return.gd"
## An explicit success or failure value.
##
## Wraps either a success value ([code]Ok(value)[/code]) or an error
## ([code]Err(error)[/code]). The error side can hold any [Variant].
## Construct with [code]StdResult.ok[/code] or [code]StdResult.err[/code].
## [codeblock lang=gdscript]
##     var result: StdResult = load_profile()
##     if result.is_err():
##         push_warning(result.unwrap_err())
##         return
##     var profile: Dictionary = result.unwrap() as Dictionary
## [/codeblock]


func _init(type: Returns, value: Variant = null) -> void:
	super(type, value)
	if type == Returns.OK or type == Returns.ERR:
		return

	var message: String = "StdResult constructed with invalid return type %s" % type
	_fail(message)

	# A developer may resume after the debug assertion. Leave a valid StdResult
	# behind instead of preserving the impossible tag.
	_type = Returns.ERR
	_value = message
	return


## Creates a result wrapping a success value.
static func ok(value: Variant) -> StdResult:
	return StdResult.new(Returns.OK, value)


## Creates a result wrapping an error. The error can be any [Variant],
## for example an [Err] instance.
static func err(error: Variant) -> StdResult:
	return StdResult.new(Returns.ERR, error)


## Creates an error result containing [code]"Method not implemented."[/code].
static func not_implemented() -> StdResult:
	return StdResult.new(Returns.ERR, "Method not implemented.")


## Returns true if the result is ok
func is_ok() -> bool:
	return _type == Returns.OK


## Returns true if the result is ok and the value matches a predicate
func is_ok_and(cb: Callable) -> bool:
	if not is_ok():
		return false
	if not _valid_callable(cb, "StdResult.is_ok_and()"):
		return false
	return cb.call(_value)


## Returns true if the result is an err
func is_err() -> bool:
	return _type == Returns.ERR


## Returns true if result is an err and the value inside it matches
## the predicate
func is_err_and(cb: Callable) -> bool:
	if not is_err():
		return false
	if not _valid_callable(cb, "StdResult.is_err_and()"):
		return false
	return cb.call(_value)


## Returns the ok value. If err, halts on an assertion in debug builds and
## crashes release builds with the provided message. If debug execution is
## manually resumed, returns [code]null[/code]. Use [code]StdResult.unwrap_or[/code]
## when failure should be recoverable.
func expect(msg: String) -> Variant:
	if not is_ok():
		_fail(msg)
		return null
	return _value


## Returns the contained ok value. If err, halts on an assertion in debug
## builds and crashes release builds. If debug execution is manually resumed,
## returns [code]null[/code]. Use [code]StdResult.unwrap_or[/code] when failure should
## be recoverable.
func unwrap() -> Variant:
	if not is_ok():
		_fail("called StdResult.unwrap() on an Err value: %s" % _value)
		return null
	return _value


## Returns the ok value or the provided default.
func unwrap_or(default: Variant) -> Variant:
	return _value if is_ok() else default


## Returns the ok value or the value returned by the provided
## [Callable], which receives the error.
func unwrap_or_else(cb: Callable) -> Variant:
	if is_ok():
		return _value
	if not _valid_callable(cb, "StdResult.unwrap_or_else()"):
		return null
	return cb.call(_value)


## Returns the contained err value. If ok, halts on an assertion in debug
## builds and crashes release builds. If debug execution is manually resumed,
## returns [code]null[/code]. Use [code]StdResult.get_err[/code] when the side is not
## already known.
func unwrap_err() -> Variant:
	if not is_err():
		_fail("called StdResult.unwrap_err() on an Ok value: %s" % _value)
		return null
	return _value


## Returns the err value. If ok, halts on an assertion in debug builds and
## crashes release builds with the provided message. If debug execution is
## manually resumed, returns [code]null[/code].
func expect_err(msg: String) -> Variant:
	if not is_err():
		_fail(msg)
		return null
	return _value


## Converts the ok side to an [code]StdOption[/code]: [code]Some(value)[/code] if ok,
## otherwise [code]None[/code].
func get_ok() -> StdOption:
	return StdOption.some(_value) if is_ok() else StdOption.none()


## Converts the err side to an [code]StdOption[/code]: [code]Some(error)[/code] if err,
## otherwise [code]None[/code].
func get_err() -> StdOption:
	return StdOption.some(_value) if is_err() else StdOption.none()


## Returns a new result containing the value produced by [param cb] when this
## result is ok. An err result passes through unchanged.
func map(cb: Callable) -> StdResult:
	if is_err():
		return self
	if not _valid_callable(cb, "StdResult.map()"):
		return self
	return StdResult.ok(cb.call(_value))


## Returns the value produced by [param cb] when this result is ok, or the
## eagerly supplied [param default] when it is err.
func map_or(default: Variant, cb: Callable) -> Variant:
	if is_err():
		return default
	if not _valid_callable(cb, "StdResult.map_or()"):
		return default
	return cb.call(_value)


## Returns the value produced by [param cb] when this result is ok, or the
## value produced by [param default_cb] from the error when it is err. Only
## the selected callable runs.
func map_or_else(default_cb: Callable, cb: Callable) -> Variant:
	if is_ok():
		if not _valid_callable(cb, "StdResult.map_or_else()"):
			return null
		return cb.call(_value)
	if not _valid_callable(default_cb, "StdResult.map_or_else()"):
		return null
	return default_cb.call(_value)


## Calls [param cb] with the wrapped value when this result is ok, then
## returns this result unchanged. Useful for side effects such as logging.
func inspect(cb: Callable) -> StdResult:
	if is_err():
		return self
	if not _valid_callable(cb, "StdResult.inspect()"):
		return self
	cb.call(_value)
	return self


## Returns a result with the error transformed by the provided
## [Callable], leaving an ok result untouched.
func map_err(cb: Callable) -> StdResult:
	if not is_err():
		return self
	if not _valid_callable(cb, "StdResult.map_err()"):
		return self
	return StdResult.err(cb.call(_value))


## Calls the provided [Callable] with the error if the result is an err,
## then returns the result unchanged. Useful for logging.
func inspect_err(cb: Callable) -> StdResult:
	if not is_err():
		return self
	if not _valid_callable(cb, "StdResult.inspect_err()"):
		return self
	cb.call(_value)
	return self


## Pushes the error to the Godot warning log if the result is an err, then
## returns the result unchanged. Ok results pass through silently.
##
## The canned [method inspect_err] for the most common case there is: a call
## whose failure is worth saying out loud but not worth handling. Audio,
## effects, saving and navigation all return results a game would rather log
## than die on.
func warn(prefix: String = "") -> StdResult:
	return inspect_err(func(error: Variant) -> void:
			push_warning("%s%s" % ["%s: " % prefix if not prefix.is_empty() else "", error]))


## Returns [param res] when this result is ok, otherwise returns this err
## result. The alternative is supplied eagerly and must not be null.
func and_res(res: StdResult) -> StdResult:
	if not _valid_result(res, "StdResult.and_res()"):
		return StdResult.err("StdResult.and_res() called with a null StdResult")
	return res if is_ok() else self


## Returns the result produced by [param cb] when this result is ok,
## otherwise returns this err result unchanged. The callable must return an
## [code]StdResult[/code].
func and_then(cb: Callable) -> StdResult:
	if is_err():
		return self
	var message: String = "StdResult.and_then() called with an invalid Callable"
	if not _valid_callable(cb, "StdResult.and_then()"):
		return StdResult.err(message)
	var result: Variant = cb.call(_value)
	if result is StdResult:
		return result as StdResult
	message = "StdResult.and_then() callback must return an StdResult"
	_fail(message)
	return StdResult.err(message)


## Returns the result if it is ok, otherwise the provided result. The supplied
## result must not be null.
func or_res(res: StdResult) -> StdResult:
	if not _valid_result(res, "StdResult.or_res()"):
		return self
	return self if is_ok() else res


## Returns the result if it is ok, otherwise the result returned by the
## provided [Callable], which receives the error.
func or_else(cb: Callable) -> StdResult:
	if is_ok():
		return self
	if not _valid_callable(cb, "StdResult.or_else()"):
		return self
	var result: Variant = cb.call(_value)
	if result is StdResult:
		return result as StdResult
	_fail("StdResult.or_else() callback must return an StdResult")
	return self


## Removes one level of nesting from an [code]StdResult[lb]StdResult[rb][/code].
## An ok value that is not an [code]StdResult[/code] is an invariant violation.
func flatten() -> StdResult:
	if is_err():
		return self
	if _value is StdResult:
		return _value as StdResult
	var message: String = "StdResult.flatten() called on an Ok value that does not contain an StdResult"
	_fail(message)
	return StdResult.err(message)


# Rejects a null operand before a composition method uses it.
func _valid_result(result: StdResult, caller: String) -> bool:
	if result != null:
		return true
	_fail("%s called with a null StdResult" % caller)
	return false
