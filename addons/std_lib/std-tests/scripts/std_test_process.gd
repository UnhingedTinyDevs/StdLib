extends RefCounted
## Internal nonblocking child-process pipes used by the StdTest launcher.


const READ_SIZE: int = 65536

var pid: int = -1

var _stdio: FileAccess
var _stderr: FileAccess


#region Public API
func start(path: String, arguments: PackedStringArray) -> Error:
	var pipes: Dictionary = OS.execute_with_pipe(path, arguments, false)
	if pipes.is_empty():
		return FAILED
	_stdio = pipes.get("stdio") as FileAccess
	_stderr = pipes.get("stderr") as FileAccess
	pid = int(pipes.get("pid", -1))
	if _stdio == null or _stderr == null or pid <= 0:
		close()
		return FAILED
	return OK


func is_running() -> bool:
	return pid > 0 and OS.is_process_running(pid)


func exit_code() -> int:
	if pid <= 0 or is_running():
		return -1
	return OS.get_process_exit_code(pid)


func read_stdout() -> PackedByteArray:
	return _read_available(_stdio)


func read_stderr() -> PackedByteArray:
	return _read_available(_stderr)


func close() -> void:
	if _stdio != null:
		_stdio.close()
		_stdio = null
	if _stderr != null:
		_stderr.close()
		_stderr = null
	pid = -1
	return
#endregion Public API


#region Private Helpers
func _read_available(pipe: FileAccess) -> PackedByteArray:
	var output: PackedByteArray = []
	if pipe == null:
		return output
	while true:
		var chunk: PackedByteArray = pipe.get_buffer(READ_SIZE)
		if chunk.is_empty():
			break
		output.append_array(chunk)
		pass
	return output
#endregion Private Helpers
