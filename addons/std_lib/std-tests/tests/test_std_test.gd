extends StdTest
## Self-tests for StdTest execution, assertions, lifecycle, and cleanup.


const PASSING_SUITE: GDScript = preload("fixtures/passing_std_test_suite.gd")
const FAILING_SUITE: GDScript = preload("fixtures/failing_std_test_suite.gd")
const DIAGNOSTIC_SUITE: GDScript = preload("fixtures/diagnostic_std_test_suite.gd")


func _test_complete_suite_execution() -> void:
	var suite: StdTest = PASSING_SUITE.new() as StdTest
	var context: StdTestContext = StdTestContext.new(
			Engine.get_main_loop() as SceneTree, StdTestLogger.new(), false)
	var result: StdTestSuiteResult = await suite.run(context, "passing fixture")

	assert_true(result.is_passed(), "passing fixture passes")
	assert_eq(result.cases.size(), 2, "both test functions are discovered")
	assert_eq(result.passed_functions(), 2, "both functions pass")
	assert_eq(result.failed_functions(), 0, "no function fails")
	assert_eq(result.lifecycle_passed_checks, 2, "lifecycle assertions are counted")
	assert_eq(suite.events, [
		"before_all",
		"before_each", "after_each",
		"before_each", "after_each",
		"after_all",
	], "lifecycle hooks run in order")
	assert_false(is_instance_id_valid(suite.test_node_id), "per-test node is freed")
	assert_false(is_instance_id_valid(suite.shared_node_id), "suite node is freed after after_all")
	return


func _test_failure_and_zero_check_accounting() -> void:
	var suite: StdTest = FAILING_SUITE.new() as StdTest
	var context: StdTestContext = StdTestContext.new(
			Engine.get_main_loop() as SceneTree, StdTestLogger.new(), false)
	var result: StdTestSuiteResult = await suite.run(context, "failing fixture")

	assert_false(result.is_passed(), "failing fixture fails")
	assert_eq(result.passed_functions(), 0, "no function passes")
	assert_eq(result.failed_functions(), 2, "both functions fail")
	assert_eq(result.failed_checks(), 2, "assertion and zero-check failures are counted")
	assert_has(result.cases[0].failures[0].message, "got 1, expected 2",
			"assertion failure retains values")
	assert_has(result.cases[1].failures[0].message, "performed no checks",
			"zero-check failure explains the problem")
	return


func _test_expected_diagnostics_are_checks() -> void:
	expect_warning("expected framework warning", "warning is captured")
	push_warning("expected framework warning")
	expect_error("expected framework error", "error is captured")
	push_error("expected framework error")
	return


func _test_unexpected_diagnostics_fail_the_function() -> void:
	expect_warning("nested unexpected warning", "outer suite consumes fixture warning")
	var logger: StdTestLogger = StdTestLogger.new()
	OS.add_logger(logger)
	var suite: StdTest = DIAGNOSTIC_SUITE.new() as StdTest
	var context: StdTestContext = StdTestContext.new(
			Engine.get_main_loop() as SceneTree, logger, false)
	var result: StdTestSuiteResult = await suite.run(context, "diagnostic fixture")
	OS.remove_logger(logger)

	assert_false(result.is_passed(), "unexpected warning fails fixture")
	assert_eq(result.failed_functions(), 1, "warning is attributed to its function")
	assert_has(result.cases[0].failures[0].message, "unexpected warning",
			"diagnostic failure retains its category")
	return
