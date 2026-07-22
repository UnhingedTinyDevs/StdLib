class_name StdCmp
extends RefCounted
## Collection of useful comparable functions used by the std-lib


## returns the standard less than comparable callable
static func less_than() -> Callable:
	return func(a, b) -> bool: return a < b


## returns the standard greater than comparable callable
static func greater_than() -> Callable:
	return func(a, b) -> bool: return a > b


## returns the standard equal to comparable callable
static func equal_to() -> Callable:
	return func(a,b) -> bool: return a == b
