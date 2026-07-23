extends SceneTree
## Subprocess fixture for fatal [StdGrid2D] argument contracts.


func _init() -> void:
	var cases: PackedStringArray = OS.get_cmdline_user_args()
	if cases.is_empty():
		printerr("grid failure probe needs at least one case")
		quit(2)
		return
	call_deferred("_finish_halted_probe")
	for case_name: String in cases:
		match case_name:
			"random_free":
				var _result: StdOption = StdGrid2D.new(
						Vector2i.ONE, Vector2.ONE).random_free_cell(null, null)
			"random_wall":
				var _result: StdOption = StdGrid2D.new(
						Vector2i(3, 3), Vector2.ONE).random_wall_cell(
								StdGrid2D.Side.TOP, null)
			_:
				printerr("unknown grid failure probe case: %s" % case_name)
				quit(2)
				return
	print("PROBE_CONTINUED")
	quit(0)
	return


func _finish_halted_probe() -> void:
	quit(86)
	return
