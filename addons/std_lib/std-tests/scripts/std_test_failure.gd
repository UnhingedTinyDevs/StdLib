class_name StdTestFailure
extends RefCounted
## A structured failure recorded while running an [StdTest] function.


## The source of a test failure.
enum Kind {
	## An assertion evaluated to false.
	ASSERTION,
	## An expected diagnostic was not emitted.
	EXPECTATION,
	## An unexpected engine diagnostic was emitted.
	DIAGNOSTIC,
	## The test framework was used incorrectly or could not complete an action.
	FRAMEWORK,
}


var kind: int
var name: String
var message: String


#region Engine Methods
func _init(failure_kind: int, failure_name: String, failure_message: String) -> void:
	kind = failure_kind
	name = failure_name
	message = failure_message
	return
#endregion Engine Methods


#region Public API
## Returns this failure as a compact human-readable line.
func describe() -> String:
	if name.is_empty():
		return message
	return "%s: %s" % [name, message]
#endregion Public API
