@abstract
class_name StdReturn
extends RefCounted
## Abstract storage and invariant handling for std-lib return wrappers.
##
## [StdResult] and [StdOption] extend this class. Construct those concrete
## wrappers through their static factories rather than constructing
## [StdReturn] directly.

## The types of returns that are allowed by a [code]StdReturn[/code] type.
## StdResult can return [OK, ERR], StdOption can return [SOME, NONE]
enum Returns {
	## A successful [StdResult].
	OK,
	## A failed [StdResult].
	ERR,
	## A present [StdOption].
	SOME,
	## An absent [StdOption].
	NONE,
}

# The kind of return this instance holds.
var _type: Returns

# The wrapped value (SOME/OK) or error (ERR); null for NONE.
var _value: Variant


func _init(type: Returns, value: Variant = null) -> void:
	_type = type
	_value = value
	return


# Reports a violated return-type invariant. Assertions give the editor and
# debug exports their normal breakpoint; release exports need an explicit
# crash because Godot strips assertions from them.
func _fail(message: String) -> void:
	_fail_for_build(message, OS.is_debug_build())
	return


# Kept separate so the release branch can be exercised by a subprocess test
# without requiring an export template.
func _fail_for_build(message: String, debug_build: bool) -> void:
	if debug_build:
		assert(false, message)
		return
	OS.crash(message)
	return


# Validates only when a callback is about to run. This preserves the lazy and
# short-circuiting contracts of the public combinators.
func _valid_callable(cb: Callable, caller: String) -> bool:
	if cb.is_valid():
		return true
	_fail("%s called with an invalid Callable" % caller)
	return false


@abstract func expect(msg: String) -> Variant
@abstract func unwrap() -> Variant
@abstract func unwrap_or(default: Variant) -> Variant
@abstract func unwrap_or_else(cb: Callable) -> Variant
