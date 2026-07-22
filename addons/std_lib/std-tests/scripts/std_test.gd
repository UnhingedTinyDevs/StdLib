class_name StdTest
extends RefCounted
## Base class for lightweight, engine-aware StdLib test suites.
##
## Test methods begin with [code]_test_[/code]. Each function receives isolated
## check counts, diagnostic expectations, signal monitors, and scene-tree nodes.
## Setup and teardown hooks may be synchronous or use [code]await[/code].


enum DiagnosticExpectation {
	WARNING,
	ERROR,
}


## Compatibility count populated while a suite runs.
var passed: int = 0
## Compatibility count populated while a suite runs.
var failed: int = 0

var _context: StdTestContext
var _suite_result: StdTestSuiteResult
var _current_case: StdTestCaseResult
var _log_start: int = 0
var _expected_kinds: Array[int] = []
var _expected_texts: Array[String] = []
var _expected_names: Array[String] = []


#region Lifecycle Hooks
## Runs once before this suite's test functions. Override when needed.
func _before_all() -> void:
	return


## Runs before every test function. Override when needed.
func _before_each() -> void:
	return


## Runs after every test function. Override when needed.
func _after_each() -> void:
	return


## Runs once after this suite's test functions. Override when needed.
func _after_all() -> void:
	return
#endregion Lifecycle Hooks


#region Runner API
## Runs every [code]_test_*[/code] method in declaration order.
##
## This method is called by the StdTest runner. Synchronous and coroutine test
## methods are both supported.
func run(context: StdTestContext, suite_path: String = "") -> StdTestSuiteResult:
	_context = context
	_suite_result = StdTestSuiteResult.new(suite_path)
	passed = 0
	failed = 0

	await _run_lifecycle(&"_before_all")
	for method: Dictionary in get_script().get_script_method_list():
		var method_name: StringName = method.name
		if not method_name.begins_with("_test_"):
			continue
		await _run_case(method_name)
		pass
	await _run_lifecycle(&"_after_all", true)

	var result: StdTestSuiteResult = _suite_result
	_current_case = null
	_suite_result = null
	_context = null
	return result
#endregion Runner API


#region Boolean Assertions
## Passes when [param value] is [code]true[/code].
func assert_true(value: bool, name: String) -> void:
	_record(value, name, "expected true, got false")
	return


## Passes when [param value] is [code]false[/code].
func assert_false(value: bool, name: String) -> void:
	_record(not value, name, "expected false, got true")
	return


## Passes when [param actual] equals [param expected].
func assert_eq(actual: Variant, expected: Variant, name: String) -> void:
	if actual == expected:
		_record_pass()
		return
	_record_failure(StdTestFailure.Kind.ASSERTION, name,
			"got %s, expected %s" % [_show(actual), _show(expected)])
	return


## Passes when [param actual] does not equal [param expected].
func assert_ne(actual: Variant, expected: Variant, name: String) -> void:
	if actual != expected:
		_record_pass()
		return
	_record_failure(StdTestFailure.Kind.ASSERTION, name, "both values were %s" % _show(actual))
	return


## Passes when numeric [param actual] is less than [param expected].
func assert_lt(actual: Variant, expected: Variant, name: String) -> void:
	if not _require_numbers(actual, expected, name):
		return
	_record(actual < expected, name, "%s was not less than %s" % [_show(actual), _show(expected)])
	return


## Passes when numeric [param actual] is less than or equal to [param expected].
func assert_lte(actual: Variant, expected: Variant, name: String) -> void:
	if not _require_numbers(actual, expected, name):
		return
	_record(actual <= expected, name, "%s was greater than %s" % [_show(actual), _show(expected)])
	return


## Passes when numeric [param actual] is greater than [param expected].
func assert_gt(actual: Variant, expected: Variant, name: String) -> void:
	if not _require_numbers(actual, expected, name):
		return
	_record(actual > expected, name, "%s was not greater than %s" % [_show(actual), _show(expected)])
	return


## Passes when numeric [param actual] is greater than or equal to [param expected].
func assert_gte(actual: Variant, expected: Variant, name: String) -> void:
	if not _require_numbers(actual, expected, name):
		return
	_record(actual >= expected, name, "%s was less than %s" % [_show(actual), _show(expected)])
	return


## Passes when two floating-point values differ by no more than [param tolerance].
func assert_approx_eq(actual: float, expected: float, tolerance: float, name: String) -> void:
	if tolerance < 0.0:
		_record_framework_failure(name, "tolerance must be non-negative")
		return
	_record(absf(actual - expected) <= tolerance, name,
			"%s differed from %s by more than %s" % [actual, expected, tolerance])
	return


## Passes when [param value] is [code]null[/code].
func assert_null(value: Variant, name: String) -> void:
	_record(value == null, name, "expected null, got %s" % _show(value))
	return


## Passes when [param value] is not [code]null[/code].
func assert_not_null(value: Variant, name: String) -> void:
	_record(value != null, name, "expected a value, got null")
	return
#endregion Boolean Assertions


#region StdReturn Assertions
## Passes when [param option] is [StdOption.some].
func assert_some(option: StdOption, name: String) -> void:
	if option == null:
		_record_framework_failure(name, "expected StdOption, got null")
		return
	_record(option.is_some(), name, "expected some, got none")
	return


## Passes when [param option] is [StdOption.none].
func assert_none(option: StdOption, name: String) -> void:
	if option == null:
		_record_framework_failure(name, "expected StdOption, got null")
		return
	var detail: String = "expected none"
	if option.is_some():
		detail = "expected none, got some(%s)" % _show(option.unwrap())
	_record(option.is_none(), name, detail)
	return


## Passes when [param result] is [StdResult.ok].
func assert_ok(result: StdResult, name: String) -> void:
	if result == null:
		_record_framework_failure(name, "expected StdResult, got null")
		return
	var detail: String = "expected ok"
	if result.is_err():
		detail = "expected ok, got err(%s)" % _show(result.unwrap_err())
	_record(result.is_ok(), name, detail)
	return


## Passes when [param result] is [StdResult.err].
func assert_err(result: StdResult, name: String) -> void:
	if result == null:
		_record_framework_failure(name, "expected StdResult, got null")
		return
	var detail: String = "expected err"
	if result.is_ok():
		detail = "expected err, got ok(%s)" % _show(result.unwrap())
	_record(result.is_err(), name, detail)
	return
#endregion StdReturn Assertions


#region Collection Assertions
## Passes when a supported collection, string, or object reports itself empty.
func assert_empty(value: Variant, name: String) -> void:
	var state: int = _empty_state(value)
	if state < 0:
		_record_framework_failure(name, "value does not support is_empty(): %s" % _show(value))
		return
	if state == 1:
		_record_pass()
		return
	_record_failure(StdTestFailure.Kind.ASSERTION, name, "expected empty, got %s" % _show(value))
	return


## Passes when a supported collection, string, or object is not empty.
func assert_not_empty(value: Variant, name: String) -> void:
	var state: int = _empty_state(value)
	if state < 0:
		_record_framework_failure(name, "value does not support is_empty(): %s" % _show(value))
		return
	_record(state == 0, name, "expected a non-empty value")
	return


## Passes when [param collection] contains [param item].
func assert_has(collection: Variant, item: Variant, name: String) -> void:
	var state: int = _has_state(collection, item)
	if state < 0:
		_record_framework_failure(name, "value does not support has(): %s" % _show(collection))
		return
	if state == 1:
		_record_pass()
		return
	_record_failure(StdTestFailure.Kind.ASSERTION, name,
			"%s did not contain %s" % [_show(collection), _show(item)])
	return


## Passes when [param collection] does not contain [param item].
func assert_not_has(collection: Variant, item: Variant, name: String) -> void:
	var state: int = _has_state(collection, item)
	if state < 0:
		_record_framework_failure(name, "value does not support has(): %s" % _show(collection))
		return
	if state == 0:
		_record_pass()
		return
	_record_failure(StdTestFailure.Kind.ASSERTION, name,
			"%s unexpectedly contained %s" % [_show(collection), _show(item)])
	return
#endregion Collection Assertions


#region Signal Assertions
## Starts recording emissions from [param sig] until the current test is cleaned up.
func monitor_signal(sig: Signal) -> StdTestSignalMonitor:
	var monitor: StdTestSignalMonitor = StdTestSignalMonitor.new(sig)
	if _context == null:
		_record_framework_failure("monitor_signal", "requires an active test context")
		return monitor
	var error: Error = monitor.start()
	if error != OK:
		_record_framework_failure("monitor_signal", "could not monitor signal (error %d)" % error)
		return monitor
	_context.track_monitor(monitor)
	return monitor


## Passes when [param monitor] recorded at least one emission.
func assert_emitted(monitor: StdTestSignalMonitor, name: String) -> void:
	if not _require_monitor(monitor, name):
		return
	_record(monitor.emission_count() > 0, name, "signal was not emitted")
	return


## Passes when [param monitor] recorded exactly [param expected] emissions.
func assert_emitted_count(monitor: StdTestSignalMonitor, expected: int, name: String) -> void:
	if not _require_monitor(monitor, name):
		return
	if expected < 0:
		_record_framework_failure(name, "expected emission count must be non-negative")
		return
	_record(monitor.emission_count() == expected, name,
			"signal emitted %d times, expected %d" % [monitor.emission_count(), expected])
	return


## Passes when one recorded emission equals [param expected_args].
func assert_emitted_with(monitor: StdTestSignalMonitor, expected_args: Array, name: String) -> void:
	if not _require_monitor(monitor, name):
		return
	var emissions: Array[Array] = monitor.emissions()
	if emissions.has(expected_args):
		_record_pass()
		return
	_record_failure(StdTestFailure.Kind.ASSERTION, name,
			"signal never emitted with %s; got %s" % [_show(expected_args), _show(emissions)])
	return
#endregion Signal Assertions


#region Diagnostic Expectations
## Expects one engine warning containing [param text] during the current function.
func expect_warning(text: String, name: String = "") -> void:
	_add_diagnostic_expectation(DiagnosticExpectation.WARNING, text, name)
	return


## Expects one engine or script error containing [param text] during the current function.
func expect_error(text: String, name: String = "") -> void:
	_add_diagnostic_expectation(DiagnosticExpectation.ERROR, text, name)
	return
#endregion Diagnostic Expectations


#region Engine Helpers
## Waits for [param frames] process frames. Call with [code]await[/code].
func process_wait(frames: int = 1) -> void:
	if not _require_wait_context(frames, "process_wait"):
		return
	for _index: int in frames:
		await _context.tree.process_frame
		pass
	return


## Waits for [param frames] physics frames. Call with [code]await[/code].
func physics_wait(frames: int = 1) -> void:
	if not _require_wait_context(frames, "physics_wait"):
		return
	for _index: int in frames:
		await _context.tree.physics_frame
		pass
	return


## Adds [param node] to the test tree and frees it automatically after the test.
func add_to_tree(node: Node) -> Node:
	if _context == null or _context.tree == null:
		_record_framework_failure("add_to_tree", "requires an active test context")
		return node
	if node == null or not is_instance_valid(node):
		_record_framework_failure("add_to_tree", "requires a valid node")
		return node
	if node.get_parent() != null or node.is_inside_tree():
		_record_framework_failure("add_to_tree", "node already belongs to a tree")
		return node
	_context.tree.root.add_child(node)
	_context.track_node(node)
	return node


## Detaches a tracked node from its parent. Automatic cleanup still owns it.
func remove_from_tree(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		_record_framework_failure("remove_from_tree", "requires a valid node")
		return
	var parent: Node = node.get_parent()
	if parent == null:
		_record_framework_failure("remove_from_tree", "node has no parent")
		return
	parent.remove_child(node)
	return
#endregion Engine Helpers


#region Deprecated Compatibility API
## @deprecated: Use [method assert_true] instead.
func check(condition: bool, name: String) -> void:
	assert_true(condition, name)
	return


## @deprecated: Use [method assert_eq] instead.
func check_eq(actual: Variant, expected: Variant, name: String) -> void:
	assert_eq(actual, expected, name)
	return


## @deprecated: Use [method assert_ok] instead.
func check_ok(result: StdResult, name: String) -> void:
	assert_ok(result, name)
	return


## @deprecated: Use [method assert_err] instead.
func check_err(result: StdResult, name: String) -> void:
	assert_err(result, name)
	return
#endregion Deprecated Compatibility API


#region Private Runner Helpers
func _run_case(method_name: StringName) -> void:
	var result: StdTestCaseResult = StdTestCaseResult.new(method_name)
	var started_usec: int = Time.get_ticks_usec()
	_context.begin_case()
	_begin_result(result)
	await call(&"_before_each")
	await call(method_name)
	await call(&"_after_each")
	_context.cleanup_case()
	_finish_result(result, true)
	result.elapsed_usec = Time.get_ticks_usec() - started_usec
	_suite_result.add_case(result)
	if _context.print_results:
		_print_case_result(result)
	_current_case = null
	return


func _run_lifecycle(method_name: StringName, cleanup_after: bool = false) -> void:
	var result: StdTestCaseResult = StdTestCaseResult.new(method_name)
	_begin_result(result)
	await call(method_name)
	if cleanup_after:
		_context.cleanup_all()
	_finish_result(result, false)
	_suite_result.add_lifecycle_result(result)
	if _context.print_results and not result.is_passed():
		_print_case_result(result)
	_current_case = null
	return


func _begin_result(result: StdTestCaseResult) -> void:
	_current_case = result
	_expected_kinds.clear()
	_expected_texts.clear()
	_expected_names.clear()
	_log_start = _context.logger.size() if _context.logger != null else 0
	return


func _finish_result(result: StdTestCaseResult, require_check: bool) -> void:
	_reconcile_diagnostics(result)
	if require_check and result.check_count() == 0:
		_record_failure(StdTestFailure.Kind.FRAMEWORK, result.name,
				"test function performed no checks")
	return


func _print_case_result(result: StdTestCaseResult) -> void:
	if result.is_passed():
		print("PASS %s (%d checks, %.3f ms)" % [
				result.name, result.check_count(), result.elapsed_usec / 1000.0])
		return
	print("FAIL %s (%d passed, %d failed)" % [
				result.name, result.passed_checks, result.failed_checks])
	for failure: StdTestFailure in result.failures:
		print("  - %s" % failure.describe())
		pass
	return
#endregion Private Runner Helpers


#region Private Assertion Helpers
func _record(condition: bool, name: String, failure_message: String) -> void:
	if condition:
		_record_pass()
		return
	_record_failure(StdTestFailure.Kind.ASSERTION, name, failure_message)
	return


func _record_pass() -> void:
	passed += 1
	if _current_case != null:
		_current_case.record_pass()
	return


func _record_failure(kind: int, name: String, message: String) -> void:
	failed += 1
	if _current_case == null:
		printerr("FAIL: %s" % StdTestFailure.new(kind, name, message).describe())
		return
	_current_case.record_failure(StdTestFailure.new(kind, name, message))
	return


func _record_framework_failure(name: String, message: String) -> void:
	_record_failure(StdTestFailure.Kind.FRAMEWORK, name, message)
	return


func _require_numbers(actual: Variant, expected: Variant, name: String) -> bool:
	if _is_number(actual) and _is_number(expected):
		return true
	_record_framework_failure(name, "comparison requires numeric values; got %s and %s" % [
			_show(actual), _show(expected)])
	return false


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _require_monitor(monitor: StdTestSignalMonitor, name: String) -> bool:
	if monitor != null:
		return true
	_record_framework_failure(name, "requires a valid StdTestSignalMonitor")
	return false


func _require_wait_context(frames: int, method_name: String) -> bool:
	if _context == null or _context.tree == null:
		_record_framework_failure(method_name, "requires an active test context")
		return false
	if frames < 1:
		_record_framework_failure(method_name, "frame count must be at least 1")
		return false
	return true


func _show(value: Variant) -> String:
	return str(value)


func _empty_state(value: Variant) -> int:
	var value_type: int = typeof(value)
	if value_type in [
		TYPE_STRING, TYPE_STRING_NAME, TYPE_ARRAY, TYPE_DICTIONARY,
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	]:
		return 1 if value.is_empty() else 0
	if value_type == TYPE_OBJECT:
		var object: Object = value as Object
		if object != null and is_instance_valid(object) and object.has_method(&"is_empty"):
			return 1 if object.call(&"is_empty") else 0
	return -1


func _has_state(collection: Variant, item: Variant) -> int:
	var collection_type: int = typeof(collection)
	if collection_type == TYPE_STRING:
		if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
			return -1
		return 1 if String(collection).contains(String(item)) else 0
	if collection_type in [
		TYPE_ARRAY, TYPE_DICTIONARY,
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	]:
		return 1 if collection.has(item) else 0
	if collection_type == TYPE_OBJECT:
		var object: Object = collection as Object
		if object != null and is_instance_valid(object) and object.has_method(&"has"):
			return 1 if object.call(&"has", item) else 0
	return -1
#endregion Private Assertion Helpers


#region Private Diagnostic Helpers
func _add_diagnostic_expectation(kind: int, text: String, name: String) -> void:
	if text.is_empty():
		_record_framework_failure(name, "diagnostic expectation requires non-empty text")
		return
	_expected_kinds.append(kind)
	_expected_texts.append(text)
	_expected_names.append(name)
	return


func _reconcile_diagnostics(result: StdTestCaseResult) -> void:
	if not _context.diagnostics_available:
		for index: int in _expected_texts.size():
			_record_failure(StdTestFailure.Kind.EXPECTATION, _expectation_name(index, result.name),
					"cannot evaluate diagnostic expectations while engine errors are muted")
			pass
		return
	if _context.logger == null:
		for index: int in _expected_texts.size():
			_record_failure(StdTestFailure.Kind.EXPECTATION, _expectation_name(index, result.name),
					"diagnostic expectations require a StdTestLogger")
			pass
		return

	var diagnostics: Array[StdTestLogEntry] = []
	var entries: Array[StdTestLogEntry] = _context.logger.entries()
	for index: int in range(_log_start, entries.size()):
		var entry: StdTestLogEntry = entries[index]
		if _diagnostic_kind(entry) >= 0:
			diagnostics.append(entry)
		continue

	var matched: Array[bool] = []
	matched.resize(diagnostics.size())
	matched.fill(false)
	for expectation_index: int in _expected_texts.size():
		var diagnostic_index: int = _find_diagnostic(
				diagnostics, matched, _expected_kinds[expectation_index], _expected_texts[expectation_index])
		if diagnostic_index < 0:
			_record_failure(StdTestFailure.Kind.EXPECTATION,
					_expectation_name(expectation_index, result.name),
					"expected diagnostic containing %s was not emitted" % _show(_expected_texts[expectation_index]))
			continue
		matched[diagnostic_index] = true
		_record_pass()
		pass

	for index: int in diagnostics.size():
		if matched[index]:
			continue
		var entry: StdTestLogEntry = diagnostics[index]
		_record_failure(StdTestFailure.Kind.DIAGNOSTIC, result.name,
				"unexpected %s: %s" % [_diagnostic_label(entry), entry.message])
		pass
	return


func _find_diagnostic(
		diagnostics: Array[StdTestLogEntry],
		matched: Array[bool],
		expected_kind: int,
		text: String,
) -> int:
	for index: int in diagnostics.size():
		if not matched[index] and _diagnostic_kind(diagnostics[index]) == expected_kind \
				and diagnostics[index].message == text:
			return index
	for index: int in diagnostics.size():
		if not matched[index] and _diagnostic_kind(diagnostics[index]) == expected_kind \
				and diagnostics[index].message.contains(text):
			return index
	return -1


func _diagnostic_kind(entry: StdTestLogEntry) -> int:
	if entry.kind == StdTestLogEntry.Kind.WARNING:
		return DiagnosticExpectation.WARNING
	if entry.kind == StdTestLogEntry.Kind.ERROR or entry.kind == StdTestLogEntry.Kind.SCRIPT_ERROR \
			or entry.kind == StdTestLogEntry.Kind.SHADER_ERROR:
		return DiagnosticExpectation.ERROR
	return -1


func _diagnostic_label(entry: StdTestLogEntry) -> String:
	if entry.kind == StdTestLogEntry.Kind.WARNING:
		return "warning"
	if entry.kind == StdTestLogEntry.Kind.SCRIPT_ERROR:
		return "script error"
	if entry.kind == StdTestLogEntry.Kind.SHADER_ERROR:
		return "shader error"
	return "engine error"


func _expectation_name(index: int, fallback: String) -> String:
	return _expected_names[index] if not _expected_names[index].is_empty() else fallback
#endregion Private Diagnostic Helpers
