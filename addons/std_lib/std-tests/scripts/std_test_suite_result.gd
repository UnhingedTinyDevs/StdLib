class_name StdTestSuiteResult
extends RefCounted
## Aggregated results for one [StdTest] script.


var path: String
var cases: Array[StdTestCaseResult] = []
var lifecycle_passed_checks: int = 0
var lifecycle_failed_checks: int = 0
var lifecycle_failures: Array[StdTestFailure] = []


#region Engine Methods
func _init(suite_path: String) -> void:
	path = suite_path
	return
#endregion Engine Methods


#region Public API
## Appends one completed test function result.
func add_case(result: StdTestCaseResult) -> void:
	cases.append(result)
	return


## Merges checks from a setup or teardown hook without counting it as a test function.
func add_lifecycle_result(result: StdTestCaseResult) -> void:
	lifecycle_passed_checks += result.passed_checks
	lifecycle_failed_checks += result.failed_checks
	lifecycle_failures.append_array(result.failures)
	return


## Returns the number of passing test functions.
func passed_functions() -> int:
	var amount: int = 0
	for result: StdTestCaseResult in cases:
		if result.is_passed():
			amount += 1
		continue
	return amount


## Returns the number of failing test functions.
func failed_functions() -> int:
	return cases.size() - passed_functions()


## Returns the total number of successful checks, including lifecycle checks.
func passed_checks() -> int:
	var amount: int = lifecycle_passed_checks
	for result: StdTestCaseResult in cases:
		amount += result.passed_checks
		pass
	return amount


## Returns the total number of failed checks, including lifecycle failures.
func failed_checks() -> int:
	var amount: int = lifecycle_failed_checks
	for result: StdTestCaseResult in cases:
		amount += result.failed_checks
		pass
	return amount


## Returns whether every test function and lifecycle hook passed.
func is_passed() -> bool:
	return failed_functions() == 0 and lifecycle_failed_checks == 0 and not cases.is_empty()
#endregion Public API
