extends StdTest
## Subprocess coverage for the StdTest public launcher and internal worker.


const LAUNCHER_PATH: String = \
		"res://addons/std_lib/std-tests/scripts/std_test_runner.gd"
const PASSING_DIAGNOSTIC_SUITE: String = \
		"res://addons/std_lib/std-tests/tests/test_std_test.gd"
const FAILING_DIAGNOSTIC_SUITE: String = \
		"res://addons/std_lib/std-tests/tests/fixtures/diagnostic_std_test_suite.gd"


#region Tests
func _test_passing_run_hides_expected_diagnostics() -> void:
	var result: Dictionary = _run_launcher([PASSING_DIAGNOSTIC_SUITE])
	var output: String = result.output

	assert_eq(result.exit_status, 0, "passing launcher exits successfully")
	assert_has(output, "suites: 1 passed, 0 failed", "passing totals are retained")
	assert_not_has(output, "WARNING: expected framework warning",
			"expected warning is hidden")
	assert_not_has(output, "ERROR: expected framework error", "expected error is hidden")
	assert_not_has(output, "nested unexpected warning", "nested expected warning is hidden")
	assert_not_has(output, "\u001b[", "automatic color stays off when output is captured")
	return


func _test_failing_run_replays_engine_diagnostics() -> void:
	var result: Dictionary = _run_launcher([FAILING_DIAGNOSTIC_SUITE])
	var output: String = result.output

	assert_eq(result.exit_status, 1, "diagnostic failure exit is propagated")
	assert_has(output, "FAIL _test_unexpected_warning", "function failure is retained")
	assert_has(output, "unexpected warning: nested unexpected warning",
			"structured diagnostic failure is retained")
	assert_has(output, "--- engine diagnostics ---", "raw diagnostic section is replayed")
	assert_has(output, "WARNING: nested unexpected warning", "raw warning is replayed")
	return


func _test_show_engine_errors_streams_passing_diagnostics() -> void:
	var result: Dictionary = _run_launcher([
		"--show-engine-errors",
		"--color=always",
		PASSING_DIAGNOSTIC_SUITE,
	])
	var output: String = result.output

	assert_eq(result.exit_status, 0, "diagnostic display does not change success")
	assert_has(output, "WARNING: expected framework warning", "expected warning is shown")
	assert_has(output, "ERROR: expected framework error", "expected error is shown")
	assert_has(output, "\u001b[", "forced color emits ANSI terminal codes")
	return


func _test_color_never_disables_ansi_output() -> void:
	var result: Dictionary = _run_launcher([
		"--color=never",
		PASSING_DIAGNOSTIC_SUITE,
	])
	var output: String = result.output

	assert_eq(result.exit_status, 0, "color-disabled launcher exits successfully")
	assert_not_has(output, "\u001b[", "disabled color emits plain output")
	return


func _test_invalid_color_mode_exits_cleanly() -> void:
	var result: Dictionary = _run_launcher(["--color=sparkles"])
	var output: String = result.output

	assert_eq(result.exit_status, 2, "invalid color mode uses option exit status")
	assert_has(output, "unknown color mode: sparkles", "invalid color mode is explained")
	return


func _test_invalid_option_exit_is_propagated() -> void:
	var result: Dictionary = _run_launcher(["--not-a-test-option"])
	var output: String = result.output

	assert_eq(result.exit_status, 2, "invalid option exit is propagated")
	assert_has(output, "unknown test runner option: --not-a-test-option",
			"invalid option explanation is replayed")
	return
#endregion Tests


#region Private Helpers
func _run_launcher(user_args: PackedStringArray) -> Dictionary:
	var output: Array[String] = []
	var log_path: String = OS.get_temp_dir().path_join(
			"std_test_launcher_%d_%d.log" % [OS.get_process_id(), Time.get_ticks_usec()])
	var arguments: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--log-file",
		log_path,
		"-s",
		LAUNCHER_PATH,
	]
	if not user_args.is_empty():
		arguments.append("--")
		arguments.append_array(user_args)
	var exit_status: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	if FileAccess.file_exists(log_path):
		var removal_error: Error = DirAccess.remove_absolute(log_path)
		if removal_error != OK:
			output.append("could not remove temporary launcher log (error %d)" % removal_error)
	return {
		"exit_status": exit_status,
		"output": "\n".join(output),
	}
#endregion Private Helpers
