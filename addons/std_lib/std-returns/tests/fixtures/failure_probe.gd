extends SceneTree
## Subprocess fixture for return-type invariant failures.


const CONTINUED: String = "PROBE_CONTINUED"
const WRONG_PAYLOAD: String = "PROBE_RETURNED_WRONG_PAYLOAD"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("failure probe needs at least one case")
		quit(2)
		return
	var can_halt: bool = false
	for case_name: String in args:
		if case_name != "result_warn" and case_name != "result_warn_ok":
			can_halt = true
			break
	if can_halt:
		call_deferred("_finish_halted_probe")
	for case_name: String in args:
		_run_case(case_name)
	print(CONTINUED)
	quit(0)
	return


func _finish_halted_probe() -> void:
	# An assertion can abort the current stack in an unattended headless run.
	# Give that path a deterministic exit instead of leaving the child alive.
	quit(86)
	return


func _run_case(case_name: String) -> void:
	match case_name:
		"result_unwrap":
			var value: Variant = StdResult.err("boom").unwrap()
			if value == "boom":
				print(WRONG_PAYLOAD)
		"result_expect":
			var value: Variant = StdResult.err("boom").expect("result expect probe")
			if value == "boom":
				print(WRONG_PAYLOAD)
		"result_unwrap_err":
			var value: Variant = StdResult.ok("value").unwrap_err()
			if value == "value":
				print(WRONG_PAYLOAD)
		"result_expect_err":
			var value: Variant = StdResult.ok("value").expect_err("result expect_err probe")
			if value == "value":
				print(WRONG_PAYLOAD)
		"option_unwrap":
			var value: Variant = StdOption.none().unwrap()
			if value != null:
				print(WRONG_PAYLOAD)
		"option_expect":
			var value: Variant = StdOption.none().expect("option expect probe")
			if value != null:
				print(WRONG_PAYLOAD)
		"result_constructor":
			var result: StdResult = StdResult.new(StdReturn.Returns.SOME, "value")
			if not result.is_err():
				print(WRONG_PAYLOAD)
		"option_constructor":
			var option: StdOption = StdOption.new(StdReturn.Returns.OK, "value")
			if not option.is_none():
				print(WRONG_PAYLOAD)
		"result_constructor_unknown":
			var result: StdResult = StdResult.new(99, "value")
			if not result.is_err():
				print(WRONG_PAYLOAD)
		"option_constructor_unknown":
			var option: StdOption = StdOption.new(99, "value")
			if not option.is_none():
				print(WRONG_PAYLOAD)
		"result_is_ok_and":
			var matched: bool = StdResult.ok(1).is_ok_and(Callable())
			if matched:
				print(WRONG_PAYLOAD)
		"result_is_err_and":
			var matched: bool = StdResult.err("boom").is_err_and(Callable())
			if matched:
				print(WRONG_PAYLOAD)
		"result_unwrap_or_else":
			var value: Variant = StdResult.err("boom").unwrap_or_else(Callable())
			if value != null:
				print(WRONG_PAYLOAD)
		"result_map":
			var result: StdResult = StdResult.ok(1)
			if result.map(Callable()) != result:
				print(WRONG_PAYLOAD)
		"result_map_or":
			var value: Variant = StdResult.ok(1).map_or(7, Callable())
			if value != 7:
				print(WRONG_PAYLOAD)
		"result_map_or_else_ok":
			var value: Variant = StdResult.ok(1).map_or_else(
				func(_error: Variant) -> int: return 7, Callable())
			if value != null:
				print(WRONG_PAYLOAD)
		"result_map_or_else_err":
			var value: Variant = StdResult.err("boom").map_or_else(
				Callable(), func(value: Variant) -> Variant: return value)
			if value != null:
				print(WRONG_PAYLOAD)
		"result_inspect":
			var result: StdResult = StdResult.ok(1)
			if result.inspect(Callable()) != result:
				print(WRONG_PAYLOAD)
		"result_map_err":
			var result: StdResult = StdResult.err("boom")
			if result.map_err(Callable()) != result:
				print(WRONG_PAYLOAD)
		"result_inspect_err":
			var result: StdResult = StdResult.err("boom")
			if result.inspect_err(Callable()) != result:
				print(WRONG_PAYLOAD)
		"result_and_then":
			if not StdResult.ok(1).and_then(Callable()).is_err():
				print(WRONG_PAYLOAD)
		"result_and_then_return":
			var result: StdResult = StdResult.ok(1).and_then(
				func(value: Variant) -> Variant: return StdOption.some(value))
			if not result.is_err():
				print(WRONG_PAYLOAD)
		"result_or_else":
			var result: StdResult = StdResult.err("boom")
			if result.or_else(Callable()) != result:
				print(WRONG_PAYLOAD)
		"result_or_else_return":
			var original: StdResult = StdResult.err("boom")
			var result: StdResult = original.or_else(
				func(_error: Variant) -> Variant: return StdOption.some(1))
			if result != original:
				print(WRONG_PAYLOAD)
		"result_flatten":
			if not StdResult.ok(1).flatten().is_err():
				print(WRONG_PAYLOAD)
		"option_is_some_and":
			var matched: bool = StdOption.some(1).is_some_and(Callable())
			if matched:
				print(WRONG_PAYLOAD)
		"option_is_none_or":
			var matched: bool = StdOption.some(1).is_none_or(Callable())
			if matched:
				print(WRONG_PAYLOAD)
		"option_unwrap_or_else":
			var value: Variant = StdOption.none().unwrap_or_else(Callable())
			if value != null:
				print(WRONG_PAYLOAD)
		"option_map":
			var option: StdOption = StdOption.some(1)
			if option.map(Callable()) != option:
				print(WRONG_PAYLOAD)
		"option_map_or":
			var value: Variant = StdOption.some(1).map_or(7, Callable())
			if value != 7:
				print(WRONG_PAYLOAD)
		"option_map_or_else_some":
			var value: Variant = StdOption.some(1).map_or_else(func() -> int: return 7, Callable())
			if value != null:
				print(WRONG_PAYLOAD)
		"option_map_or_else_none":
			var value: Variant = StdOption.none().map_or_else(Callable(), func(value: Variant) -> Variant: return value)
			if value != null:
				print(WRONG_PAYLOAD)
		"option_inspect":
			var option: StdOption = StdOption.some(1)
			if option.inspect(Callable()) != option:
				print(WRONG_PAYLOAD)
		"option_filter":
			if not StdOption.some(1).filter(Callable()).is_none():
				print(WRONG_PAYLOAD)
		"option_and_then":
			if not StdOption.some(1).and_then(Callable()).is_none():
				print(WRONG_PAYLOAD)
		"option_and_then_return":
			var option: StdOption = StdOption.some(1).and_then(
				func(value: Variant) -> Variant: return StdResult.ok(value))
			if not option.is_none():
				print(WRONG_PAYLOAD)
		"option_or_else":
			var option: StdOption = StdOption.none()
			if option.or_else(Callable()) != option:
				print(WRONG_PAYLOAD)
		"option_or_else_return":
			var original: StdOption = StdOption.none()
			var option: StdOption = original.or_else(func() -> Variant: return StdResult.ok(1))
			if option != original:
				print(WRONG_PAYLOAD)
		"option_flatten":
			if not StdOption.some(1).flatten().is_none():
				print(WRONG_PAYLOAD)
		"option_ok_or_else":
			var result: StdResult = StdOption.none().ok_or_else(Callable())
			if not result.is_err():
				print(WRONG_PAYLOAD)
		"option_and_opt_null":
			var option: StdOption = StdOption.some(1).and_opt(null)
			if not option.is_none():
				print(WRONG_PAYLOAD)
		"option_or_opt_null":
			var option: StdOption = StdOption.none().or_opt(null)
			if not option.is_none():
				print(WRONG_PAYLOAD)
		"option_xor_opt_null":
			var option: StdOption = StdOption.some(1).xor_opt(null)
			if not option.is_none():
				print(WRONG_PAYLOAD)
		"result_and_res_null":
			var result: StdResult = StdResult.ok(1).and_res(null)
			if not result.is_err():
				print(WRONG_PAYLOAD)
		"result_or_res_null":
			var original: StdResult = StdResult.err("boom")
			var result: StdResult = original.or_res(null)
			if result != original:
				print(WRONG_PAYLOAD)
		"result_warn":
			var _result: StdResult = StdResult.err("boom").warn("probe")
		"result_warn_ok":
			var _result: StdResult = StdResult.ok("quiet").warn("probe-ok")
		"release_failure":
			StdResult.ok(null)._fail_for_build("forced release failure", false)
		_:
			printerr("unknown failure probe: %s" % case_name)
			quit(2)
			return
	return
