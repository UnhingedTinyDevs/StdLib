class_name StdTestCaseResult
extends RefCounted
## Check counts and failures produced by one [code]_test_*[/code] function.


var name: String
var passed_checks: int = 0
var failed_checks: int = 0
var elapsed_usec: int = 0
var failures: Array[StdTestFailure] = []


#region Engine Methods
func _init(case_name: String) -> void:
	name = case_name
	return
#endregion Engine Methods


#region Public API
## Records one successful check.
func record_pass() -> void:
	passed_checks += 1
	return


## Records one failed check and its details.
func record_failure(failure: StdTestFailure) -> void:
	failed_checks += 1
	failures.append(failure)
	return


## Returns the total number of checks performed by this function.
func check_count() -> int:
	return passed_checks + failed_checks


## Returns whether this function completed without failures.
func is_passed() -> bool:
	return failed_checks == 0
#endregion Public API
