extends StdTest
## Headless tests for StdTestLogger and StdTestLogEntry.


func _test_message_classification_and_order() -> void:
	var logger: StdTestLogger = StdTestLogger.new()
	logger._log_message("one", false)
	logger._log_message("two", true)

	var entries: Array[StdTestLogEntry] = logger.entries()
	assert_eq(entries.size(), 2, "both messages are captured")
	assert_eq(entries[0].kind, StdTestLogEntry.Kind.MESSAGE, "stdout is a message")
	assert_eq(entries[0].message, "one", "stdout text is retained")
	assert_eq(entries[1].kind, StdTestLogEntry.Kind.STDERR, "stderr is classified separately")
	assert_eq(entries[1].message, "two", "stderr text is retained")
	return


func _test_diagnostic_classification_and_metadata() -> void:
	var logger: StdTestLogger = StdTestLogger.new()
	var backtraces: Array[ScriptBacktrace] = []
	logger._log_error(
			"chance", "res://random.gd", 35, "", "probability clamped", false,
			Logger.ERROR_TYPE_WARNING, backtraces)
	logger._log_error("run", "res://suite.gd", 12, "E_SCRIPT", "", true,
			Logger.ERROR_TYPE_SCRIPT, backtraces)
	logger._log_error("draw", "res://shader.gdshader", 7, "E_SHADER", "compile failed", false,
			Logger.ERROR_TYPE_SHADER, backtraces)
	logger._log_error("load", "res://loader.gd", 3, "E_LOAD", "load failed", false,
			Logger.ERROR_TYPE_ERROR, backtraces)

	var entries: Array[StdTestLogEntry] = logger.entries()
	assert_eq(entries[0].kind, StdTestLogEntry.Kind.WARNING, "warning type is normalized")
	assert_eq(entries[0].message, "probability clamped", "rationale is the message")
	assert_eq(entries[0].function, "chance", "function metadata is retained")
	assert_eq(entries[0].file, "res://random.gd", "file metadata is retained")
	assert_eq(entries[0].line, 35, "line metadata is retained")
	assert_eq(entries[1].kind, StdTestLogEntry.Kind.SCRIPT_ERROR, "script error is normalized")
	assert_eq(entries[1].message, "E_SCRIPT", "code is used when rationale is empty")
	assert_true(entries[1].editor_notify, "editor notification flag is retained")
	assert_eq(entries[2].kind, StdTestLogEntry.Kind.SHADER_ERROR, "shader error is normalized")
	assert_eq(entries[3].kind, StdTestLogEntry.Kind.ERROR, "engine error is normalized")
	return


func _test_queries_are_snapshots_and_clear_resets_capture() -> void:
	var logger: StdTestLogger = StdTestLogger.new()
	logger._log_message("message", false)
	logger._log_error("test", "res://test.gd", 1, "", "warning", false,
			Logger.ERROR_TYPE_WARNING, [])
	logger._log_error("test", "res://test.gd", 2, "", "error", false,
			Logger.ERROR_TYPE_ERROR, [])

	assert_eq(logger.size(), 3, "size counts every entry")
	assert_eq(logger.count(StdTestLogEntry.Kind.WARNING), 1, "count filters by kind")
	assert_eq(logger.entries_of_kind(StdTestLogEntry.Kind.ERROR).size(), 1,
			"entries_of_kind filters entries")
	var snapshot: Array[StdTestLogEntry] = logger.entries()
	snapshot.clear()
	assert_eq(logger.size(), 3, "mutating a snapshot does not mutate the logger")
	logger.clear()
	assert_eq(logger.size(), 0, "clear removes every entry")
	assert_true(logger.entries().is_empty(), "entries is empty after clear")
	return


func _test_concurrent_capture_is_complete() -> void:
	var logger: StdTestLogger = StdTestLogger.new()
	var first: Thread = Thread.new()
	var second: Thread = Thread.new()
	assert_eq(first.start(_write_messages.bind(logger, "first", 100)), OK,
			"first capture thread starts")
	assert_eq(second.start(_write_messages.bind(logger, "second", 100)), OK,
			"second capture thread starts")
	first.wait_to_finish()
	second.wait_to_finish()
	assert_eq(logger.size(), 200, "concurrent callbacks retain every message")
	assert_eq(logger.count(StdTestLogEntry.Kind.MESSAGE), 200,
			"concurrent messages keep their kind")
	return


func _write_messages(logger: StdTestLogger, prefix: String, amount: int) -> void:
	for index: int in amount:
		logger._log_message("%s-%d" % [prefix, index], false)
		pass
	return
