extends SceneTree
## Public Godot-only launcher for [StdTest] suites.
##
## The launcher streams the internal worker's normal results while buffering
## engine diagnostics. Diagnostics are discarded after a passing run and
## replayed after a failing run. Pass [code]--show-engine-errors[/code] after
## Godot's [code]--[/code] separator to stream them immediately. Result colors
## are enabled automatically for terminals and disabled for redirected output.


const StdTestProcess = preload("std_test_process.gd")

const WORKER_PATH: String = "res://addons/std_lib/std-tests/scripts/std_test_worker.gd"
const SHOW_ENGINE_ERRORS: String = "--show-engine-errors"
const COLOR_PREFIX: String = "--color="
const COLOR_AUTO: String = "auto"
const COLOR_ALWAYS: String = "always"
const COLOR_NEVER: String = "never"

const ANSI_RESET: String = "\u001b[0m"
const ANSI_BOLD: String = "\u001b[1m"
const ANSI_RED: String = "\u001b[31m"
const ANSI_GREEN: String = "\u001b[32m"
const ANSI_YELLOW: String = "\u001b[33m"
const ANSI_CYAN: String = "\u001b[36m"
const ANSI_GRAY: String = "\u001b[90m"

var _process: StdTestProcess
var _show_engine_errors: bool = false
var _stdout_color_enabled: bool = false
var _stderr_color_enabled: bool = false
var _stdout_buffer: PackedByteArray = []
var _stderr_buffer: PackedByteArray = []
var _skip_banner_blank: bool = false
var _worker_log_path: String = ""


#region Engine Methods
func _init() -> void:
	call_deferred(&"_run")
	return
#endregion Engine Methods


#region Private Runner
func _run() -> void:
	var worker_user_args: PackedStringArray = []
	var color_mode: String = COLOR_AUTO
	for arg: String in OS.get_cmdline_user_args():
		if arg == SHOW_ENGINE_ERRORS:
			_show_engine_errors = true
			continue
		if arg.begins_with(COLOR_PREFIX):
			color_mode = arg.trim_prefix(COLOR_PREFIX)
			if color_mode not in [COLOR_AUTO, COLOR_ALWAYS, COLOR_NEVER]:
				printerr("unknown color mode: %s (expected auto, always, or never)" % \
						color_mode)
				quit(2)
				return
			continue
		worker_user_args.append(arg)
		pass
	_configure_colors(color_mode)

	_worker_log_path = OS.get_temp_dir().path_join(
			"std_test_worker_%d.log" % OS.get_process_id())
	var worker_args: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--log-file",
		_worker_log_path,
		"-s",
		WORKER_PATH,
	]
	if not worker_user_args.is_empty():
		worker_args.append("--")
		worker_args.append_array(worker_user_args)

	_process = StdTestProcess.new()
	var error: Error = _process.start(OS.get_executable_path(), worker_args)
	if error != OK:
		_print_stderr_line("could not start the StdTest worker (error %d)" % error)
		_remove_worker_log()
		quit(1)
		return

	while _process.is_running():
		_drain_process()
		await process_frame
		pass
	_drain_process()
	_flush_stdout()

	var exit_status: int = _process.exit_code()
	if exit_status < 0:
		exit_status = 1
		_print_stderr_line("StdTest worker exited without an available status")
	_finish_stderr(exit_status)
	_process.close()
	_process = null
	_remove_worker_log()
	quit(exit_status)
	return


func _drain_process() -> void:
	var stdout_bytes: PackedByteArray = _process.read_stdout()
	if not stdout_bytes.is_empty():
		_stdout_buffer.append_array(stdout_bytes)
		_emit_stdout_lines()
	var stderr_bytes: PackedByteArray = _process.read_stderr()
	if not stderr_bytes.is_empty():
		_stderr_buffer.append_array(stderr_bytes)
		if _show_engine_errors:
			_emit_stderr_lines()
	return


func _finish_stderr(exit_status: int) -> void:
	if _show_engine_errors:
		_flush_stderr()
		return
	if exit_status == 0 or _stderr_buffer.is_empty():
		_stderr_buffer.clear()
		return
	var diagnostic_text: String = _stderr_buffer.get_string_from_utf8().trim_suffix("\n")
	_stderr_buffer.clear()
	if diagnostic_text.is_empty():
		return
	printerr("")
	_print_stderr_line("--- engine diagnostics ---")
	printerr(diagnostic_text)
	return


func _remove_worker_log() -> void:
	if _worker_log_path.is_empty() or not FileAccess.file_exists(_worker_log_path):
		return
	var error: Error = DirAccess.remove_absolute(_worker_log_path)
	if error != OK:
		_print_stderr_line("could not remove temporary worker log %s (error %d)" % [
				_worker_log_path, error])
	_worker_log_path = ""
	return
#endregion Private Runner


#region Output Framing
func _emit_stdout_lines() -> void:
	var newline: int = _stdout_buffer.find(10)
	while newline >= 0:
		var line_bytes: PackedByteArray = _stdout_buffer.slice(0, newline)
		_stdout_buffer = _stdout_buffer.slice(newline + 1)
		_emit_stdout_line(line_bytes.get_string_from_utf8().trim_suffix("\r"))
		newline = _stdout_buffer.find(10)
		pass
	return


func _emit_stdout_line(line: String) -> void:
	if line.begins_with("Godot Engine v"):
		_skip_banner_blank = true
		return
	if _skip_banner_blank:
		_skip_banner_blank = false
		if line.is_empty():
			return
	print(_color_stdout_line(line))
	return


func _flush_stdout() -> void:
	if _stdout_buffer.is_empty():
		return
	_emit_stdout_line(_stdout_buffer.get_string_from_utf8().trim_suffix("\r"))
	_stdout_buffer.clear()
	return


func _emit_stderr_lines() -> void:
	var newline: int = _stderr_buffer.find(10)
	while newline >= 0:
		var line_bytes: PackedByteArray = _stderr_buffer.slice(0, newline)
		_stderr_buffer = _stderr_buffer.slice(newline + 1)
		_print_stderr_line(line_bytes.get_string_from_utf8().trim_suffix("\r"))
		newline = _stderr_buffer.find(10)
		pass
	return


func _flush_stderr() -> void:
	if _stderr_buffer.is_empty():
		return
	_print_stderr_line(_stderr_buffer.get_string_from_utf8().trim_suffix("\r"))
	_stderr_buffer.clear()
	return
#endregion Output Framing


#region Output Colors
func _configure_colors(color_mode: String) -> void:
	if color_mode == COLOR_ALWAYS:
		_stdout_color_enabled = true
		_stderr_color_enabled = true
		return
	if color_mode == COLOR_NEVER or OS.has_environment("NO_COLOR"):
		_stdout_color_enabled = false
		_stderr_color_enabled = false
		return
	_stdout_color_enabled = OS.get_stdout_type() == OS.STD_HANDLE_CONSOLE
	_stderr_color_enabled = OS.get_stderr_type() == OS.STD_HANDLE_CONSOLE
	return


func _color_stdout_line(line: String) -> String:
	if not _stdout_color_enabled:
		return line
	if line.begins_with("PASS "):
		return _ansi(line, ANSI_GREEN)
	if line.begins_with("FAIL ") or line.begins_with("  - ") \
			or line.begins_with("  LIFECYCLE FAIL:"):
		return _ansi(line, ANSI_RED)
	if line.begins_with("--- "):
		return _ansi(line, ANSI_BOLD + ANSI_CYAN)
	if line.begins_with("suites:") or line.begins_with("functions:") \
			or line.begins_with("checks:"):
		var summary_color: String = ANSI_GREEN if line.ends_with("0 failed") else ANSI_RED
		return _ansi(line, ANSI_BOLD + summary_color)
	if line.begins_with("  functions:"):
		return _ansi(line, ANSI_GRAY)
	return line


func _print_stderr_line(line: String) -> void:
	if not _stderr_color_enabled:
		printerr(line)
		return
	var normalized: String = line.strip_edges()
	if normalized.begins_with("WARNING:"):
		printerr(_ansi(line, ANSI_YELLOW))
		return
	if normalized.begins_with("ERROR:") or normalized.begins_with("SCRIPT ERROR:") \
			or normalized.begins_with("SHADER ERROR:"):
		printerr(_ansi(line, ANSI_RED))
		return
	if line == "--- engine diagnostics ---":
		printerr(_ansi(line, ANSI_BOLD + ANSI_YELLOW))
		return
	printerr(line)
	return


func _ansi(text: String, color: String) -> String:
	return color + text + ANSI_RESET
#endregion Output Colors
