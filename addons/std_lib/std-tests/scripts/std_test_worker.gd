extends SceneTree
## Internal worker that discovers and executes [StdTest] suites.
##
## Use [code]std_test_runner.gd[/code] as the public entry point. This worker
## leaves engine diagnostics enabled so [StdTestLogger] can evaluate them.


const DEFAULT_ROOT: String = "res://"
const SUITE_PREFIX: String = "test_"
const SUITE_SUFFIX: String = ".gd"

var _logger: StdTestLogger
var _original_print_errors: bool
var _original_print_stdout: bool


#region Engine Methods
func _init() -> void:
	_logger = StdTestLogger.new()
	OS.add_logger(_logger)
	_original_print_errors = Engine.print_error_messages
	_original_print_stdout = Engine.print_to_stdout
	call_deferred(&"_run")
	return
#endregion Engine Methods


#region Private Runner
func _run() -> void:
	var roots: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			printerr("unknown test runner option: %s" % arg)
			_finish(2)
			return
		roots.append(arg)
		pass
	if roots.is_empty():
		roots.append(DEFAULT_ROOT)

	Engine.print_to_stdout = true
	Engine.print_error_messages = true

	var suites: Array[String] = []
	for path: String in roots:
		if not _collect(path, suites):
			_finish(1)
			return
		pass
	suites.sort()

	if suites.is_empty():
		printerr("no test scripts found under %s" % ", ".join(roots))
		_finish(1)
		return

	var suites_passed: int = 0
	var suites_failed: int = 0
	var functions_passed: int = 0
	var functions_failed: int = 0
	var checks_passed: int = 0
	var checks_failed: int = 0
	for path: String in suites:
		print("--- %s" % path)
		var result: StdTestSuiteResult = await _run_suite(path)
		if result == null:
			suites_failed += 1
			continue
		functions_passed += result.passed_functions()
		functions_failed += result.failed_functions()
		checks_passed += result.passed_checks()
		checks_failed += result.failed_checks()
		if result.is_passed():
			suites_passed += 1
		else:
			suites_failed += 1
		_print_suite_result(result)
		pass

	print("")
	print("suites: %d passed, %d failed" % [suites_passed, suites_failed])
	print("functions: %d passed, %d failed" % [functions_passed, functions_failed])
	print("checks: %d passed, %d failed" % [checks_passed, checks_failed])
	_finish(1 if suites_failed > 0 else 0)
	return


func _run_suite(path: String) -> StdTestSuiteResult:
	var script: GDScript = load(path) as GDScript
	if script == null:
		printerr("FAIL: could not load %s" % path)
		return null
	var suite: StdTest = script.new() as StdTest
	if suite == null:
		printerr("FAIL: %s does not extend StdTest" % path)
		return null
	var context: StdTestContext = StdTestContext.new(self, _logger, true, true)
	return await suite.run(context, path)


func _print_suite_result(result: StdTestSuiteResult) -> void:
	for failure: StdTestFailure in result.lifecycle_failures:
		print("  LIFECYCLE FAIL: %s" % failure.describe())
		pass
	print("  functions: %d passed, %d failed | checks: %d passed, %d failed" % [
			result.passed_functions(), result.failed_functions(),
			result.passed_checks(), result.failed_checks()])
	return


func _finish(exit_status: int) -> void:
	Engine.print_error_messages = _original_print_errors
	Engine.print_to_stdout = _original_print_stdout
	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null
	quit(exit_status)
	return
#endregion Private Runner


#region Discovery
func _to_res_path(path: String) -> String:
	if path.begins_with(DEFAULT_ROOT):
		return path
	return DEFAULT_ROOT.path_join(path)


func _collect(path: String, suites: Array[String]) -> bool:
	var res_path: String = _to_res_path(path)
	if DirAccess.dir_exists_absolute(res_path):
		_collect_dir(res_path, suites)
		return true
	if not FileAccess.file_exists(res_path):
		printerr("path not found: %s" % path)
		return false
	if not res_path.ends_with(SUITE_SUFFIX):
		printerr("not a GDScript suite: %s" % path)
		return false
	if not suites.has(res_path):
		suites.append(res_path)
	return true


func _collect_dir(dir: String, suites: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if not _is_discoverable_suite(file):
			continue
		var path: String = dir.path_join(file)
		if not suites.has(path):
			suites.append(path)
		pass
	for sub: String in DirAccess.get_directories_at(dir):
		if sub.begins_with("."):
			continue
		_collect_dir(dir.path_join(sub), suites)
		pass
	return


func _is_discoverable_suite(file: String) -> bool:
	return file.begins_with(SUITE_PREFIX) and file.ends_with(SUITE_SUFFIX)
#endregion Discovery
