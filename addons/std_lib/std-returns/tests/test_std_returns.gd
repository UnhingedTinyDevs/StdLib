extends StdTest
## Headless tests for StdOption/StdResult.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-returns


const FAILURE_PROBE: String = "res://addons/std_lib/std-returns/tests/fixtures/failure_probe.gd"


func _test_option() -> void:
	var s: StdOption = StdOption.some(42)
	var n: StdOption = StdOption.none()

	assert_true(s.is_some(), "some.is_some")
	assert_true(not s.is_none(), "some.is_none is false")
	assert_true(n.is_none(), "none.is_none")
	assert_true(not n.is_some(), "none.is_some is false")

	assert_true(s.is_some_and(func(v: int) -> bool: return v == 42), "is_some_and true predicate")
	assert_true(not s.is_some_and(func(v: int) -> bool: return v == 0), "is_some_and false predicate")
	assert_true(not n.is_some_and(func(_v: Variant) -> bool: return true), "none.is_some_and always false")

	assert_true(n.is_none_or(func(_v: Variant) -> bool: return false), "none.is_none_or always true")
	assert_true(s.is_none_or(func(v: int) -> bool: return v == 42), "some.is_none_or true predicate")
	assert_true(not s.is_none_or(func(v: int) -> bool: return v == 0), "some.is_none_or false predicate")

	assert_eq(s.unwrap(), 42, "some.unwrap")
	assert_eq(s.expect("should not panic"), 42, "some.expect")
	assert_eq(s.unwrap_or(0), 42, "some.unwrap_or ignores default")
	assert_eq(n.unwrap_or(7), 7, "none.unwrap_or returns default")
	assert_eq(s.unwrap_or_else(func() -> int: return 0), 42, "some.unwrap_or_else ignores callable")
	assert_eq(n.unwrap_or_else(func() -> int: return 9), 9, "none.unwrap_or_else calls callable")

	assert_true(StdOption.some(null).is_some(), "some(null) is still some")


func _test_option_transformations() -> void:
	var some: StdOption = StdOption.some(21)
	var none: StdOption = StdOption.none()
	var calls: Array[String] = []

	var mapped: StdOption = some.map(func(value: int) -> int:
		calls.append("map")
		return value * 2)
	assert_eq(mapped.unwrap(), 42, "some.map transforms the value")
	assert_true(mapped != some, "some.map returns a new option")
	assert_eq(none.map(func(_value: Variant) -> Variant:
		calls.append("none.map")
		return null), none, "none.map returns self")
	assert_eq(calls, ["map"], "map calls only on some")

	assert_eq(some.map_or(7, func(value: int) -> int: return value + 1), 22, "some.map_or maps")
	assert_eq(none.map_or(7, func(_value: Variant) -> int: return 0), 7, "none.map_or uses default")
	var eager_calls: Array[String] = []
	assert_eq(
		some.map_or(_record_value(eager_calls, "default", 7), func(value: int) -> int: return value),
		21,
		"map_or keeps the some result")
	assert_eq(eager_calls, ["default"], "map_or evaluates its default eagerly")

	var lazy_calls: Array[String] = []
	assert_eq(
		some.map_or_else(
			func() -> int:
				lazy_calls.append("default")
				return 7,
			func(value: int) -> int:
				lazy_calls.append("map")
				return value + 1),
		22,
		"some.map_or_else maps")
	assert_eq(lazy_calls, ["map"], "some.map_or_else calls only the mapper")
	lazy_calls.clear()
	assert_eq(
		none.map_or_else(
			func() -> int:
				lazy_calls.append("default")
				return 7,
			func(_value: Variant) -> int:
				lazy_calls.append("map")
				return 0),
		7,
		"none.map_or_else computes the default")
	assert_eq(lazy_calls, ["default"], "none.map_or_else calls only the default")

	var seen: Array[Variant] = []
	assert_eq(some.inspect(func(value: Variant) -> void: seen.append(value)), some, "some.inspect returns self")
	assert_eq(none.inspect(func(value: Variant) -> void: seen.append(value)), none, "none.inspect returns self")
	assert_eq(seen, [21], "inspect observes only some")

	assert_eq(some.filter(func(value: int) -> bool: return value == 21), some, "accepted filter returns self")
	assert_true(some.filter(func(value: int) -> bool: return value == 0).is_none(), "rejected filter returns none")
	assert_eq(none.filter(func(_value: Variant) -> bool: return true), none, "none.filter returns self")
	return


func _test_option_composition() -> void:
	var some_a: StdOption = StdOption.some("a")
	var some_b: StdOption = StdOption.some("b")
	var none_a: StdOption = StdOption.none()
	var none_b: StdOption = StdOption.none()

	assert_eq(some_a.and_opt(some_b), some_b, "some.and_opt(some) returns alternative")
	assert_eq(some_a.and_opt(none_b), none_b, "some.and_opt(none) returns alternative")
	assert_eq(none_a.and_opt(some_b), none_a, "none.and_opt(some) returns self")
	assert_eq(none_a.and_opt(none_b), none_a, "none.and_opt(none) returns self")
	var eager_and_calls: Array[String] = []
	assert_eq(
		none_a.and_opt(_record_option(eager_and_calls, "alternative", some_b)),
		none_a,
		"none.and_opt keeps self")
	assert_eq(eager_and_calls, ["alternative"], "and_opt evaluates its alternative eagerly")

	var and_calls: Array[String] = []
	assert_eq(
		some_a.and_then(func(value: String) -> StdOption:
			and_calls.append(value)
			return some_b),
		some_b,
		"some.and_then returns callback option")
	assert_eq(
		none_a.and_then(func(_value: Variant) -> StdOption:
			and_calls.append("none")
			return some_b),
		none_a,
		"none.and_then returns self")
	assert_eq(and_calls, ["a"], "and_then calls only on some")

	assert_eq(some_a.or_opt(some_b), some_a, "some.or_opt(some) returns self")
	assert_eq(some_a.or_opt(none_b), some_a, "some.or_opt(none) returns self")
	assert_eq(none_a.or_opt(some_b), some_b, "none.or_opt(some) returns alternative")
	assert_eq(none_a.or_opt(none_b), none_b, "none.or_opt(none) returns alternative")

	var eager_calls: Array[String] = []
	assert_eq(
		some_a.or_opt(_record_option(eager_calls, "alternative", some_b)),
		some_a,
		"some.or_opt keeps self")
	assert_eq(eager_calls, ["alternative"], "or_opt evaluates its alternative eagerly")

	var or_calls: Array[String] = []
	assert_eq(
		some_a.or_else(func() -> StdOption:
			or_calls.append("some")
			return some_b),
		some_a,
		"some.or_else returns self")
	assert_eq(
		none_a.or_else(func() -> StdOption:
			or_calls.append("none")
			return some_b),
		some_b,
		"none.or_else returns callback option")
	assert_eq(or_calls, ["none"], "or_else calls only on none")

	assert_eq(some_a.xor_opt(none_b), some_a, "some xor none returns self")
	assert_eq(none_a.xor_opt(some_b), some_b, "none xor some returns other")
	assert_true(some_a.xor_opt(some_b).is_none(), "some xor some returns none")
	assert_eq(none_a.xor_opt(none_b), none_a, "none xor none returns self")

	assert_eq(StdOption.some(some_a).flatten(), some_a, "flatten some(some) returns inner some")
	assert_eq(StdOption.some(none_b).flatten(), none_b, "flatten some(none) returns inner none")
	assert_eq(none_a.flatten(), none_a, "flatten none returns self")
	return


func _test_option_conversions() -> void:
	var some: StdOption = StdOption.some(42)
	var none: StdOption = StdOption.none()
	var eager_calls: Array[String] = []
	var from_some: StdResult = some.ok_or(_record_value(eager_calls, "error", "missing"))
	assert_ok(from_some, "some.ok_or returns ok")
	assert_eq(from_some.unwrap(), 42, "some.ok_or preserves value")
	assert_eq(eager_calls, ["error"], "ok_or evaluates its error eagerly")
	var from_none: StdResult = none.ok_or("missing")
	assert_err(from_none, "none.ok_or returns err")
	assert_eq(from_none.unwrap_err(), "missing", "none.ok_or preserves error")

	var lazy_calls: Array[String] = []
	var lazy_some: StdResult = some.ok_or_else(func() -> String:
		lazy_calls.append("some")
		return "missing")
	assert_ok(lazy_some, "some.ok_or_else returns ok")
	assert_eq(lazy_some.unwrap(), 42, "some.ok_or_else preserves value")
	assert_eq(lazy_calls, [], "some.ok_or_else skips error callback")
	var lazy_none: StdResult = none.ok_or_else(func() -> String:
		lazy_calls.append("none")
		return "missing")
	assert_err(lazy_none, "none.ok_or_else returns err")
	assert_eq(lazy_none.unwrap_err(), "missing", "none.ok_or_else uses callback error")
	assert_eq(lazy_calls, ["none"], "none.ok_or_else calls error callback")

	var null_result: StdResult = StdOption.some(null).ok_or("missing")
	assert_ok(null_result, "some(null).ok_or stays ok")
	assert_eq(null_result.unwrap(), null, "some(null).ok_or preserves null")
	return


func _test_option_some_null_callbacks() -> void:
	var some_null: StdOption = StdOption.some(null)
	var seen: Array[Variant] = []

	assert_true(some_null.is_some_and(func(value: Variant) -> bool:
		seen.append(value)
		return value == null), "some(null).is_some_and receives null")
	assert_true(some_null.is_none_or(func(value: Variant) -> bool:
		seen.append(value)
		return value == null), "some(null).is_none_or receives null")
	assert_true(some_null.map(func(value: Variant) -> Variant:
		seen.append(value)
		return value).is_some(), "some(null).map stays some")
	assert_eq(some_null.map_or(false, func(value: Variant) -> bool:
		seen.append(value)
		return value == null), true, "some(null).map_or receives null")
	assert_eq(some_null.map_or_else(func() -> bool: return false, func(value: Variant) -> bool:
		seen.append(value)
		return value == null), true, "some(null).map_or_else receives null")
	assert_eq(some_null.inspect(func(value: Variant) -> void: seen.append(value)), some_null,
		"some(null).inspect receives null")
	assert_eq(some_null.filter(func(value: Variant) -> bool:
		seen.append(value)
		return value == null), some_null, "some(null).filter receives null")
	var chained: StdOption = some_null.and_then(func(value: Variant) -> StdOption:
		seen.append(value)
		return StdOption.some("called"))
	assert_eq(chained.unwrap(), "called", "some(null).and_then receives null")
	assert_eq(seen.size(), 8, "every selected value callback received null")
	for value: Variant in seen:
		assert_eq(value, null, "selected callback argument is null")
		pass
	return


func _test_result() -> void:
	var o: StdResult = StdResult.ok("value")
	var e: StdResult = StdResult.err("boom")

	assert_ok(o, "ok.is_ok")
	assert_true(not o.is_err(), "ok.is_err is false")
	assert_err(e, "err.is_err")
	assert_true(not e.is_ok(), "err.is_ok is false")

	assert_true(o.is_ok_and(func(v: String) -> bool: return v == "value"), "is_ok_and true predicate")
	assert_true(not o.is_ok_and(func(_v: Variant) -> bool: return false), "is_ok_and false predicate")
	assert_true(not e.is_ok_and(func(_v: Variant) -> bool: return true), "err.is_ok_and always false")

	assert_true(e.is_err_and(func(v: String) -> bool: return v == "boom"), "is_err_and true predicate")
	assert_true(not e.is_err_and(func(_v: Variant) -> bool: return false), "is_err_and false predicate")
	assert_true(not o.is_err_and(func(_v: Variant) -> bool: return true), "ok.is_err_and always false")

	assert_eq(o.unwrap(), "value", "ok.unwrap")
	assert_eq(o.expect("should not panic"), "value", "ok.expect")
	assert_eq(o.unwrap_or("default"), "value", "ok.unwrap_or ignores default")
	assert_eq(e.unwrap_or("default"), "default", "err.unwrap_or returns default")
	assert_eq(o.unwrap_or_else(func(_err: Variant) -> String: return "x"), "value", "ok.unwrap_or_else ignores callable")
	assert_eq(
		e.unwrap_or_else(func(err: String) -> String: return err + "!"),
		"boom!",
		"err.unwrap_or_else receives error")

	assert_eq(e.unwrap_err(), "boom", "err.unwrap_err")
	assert_eq(e.expect_err("should not panic"), "boom", "err.expect_err")

	assert_true(o.get_ok().is_some(), "ok.get_ok is some")
	assert_eq(o.get_ok().unwrap(), "value", "ok.get_ok unwraps value")
	assert_true(o.get_err().is_none(), "ok.get_err is none")
	assert_true(e.get_err().is_some(), "err.get_err is some")
	assert_eq(e.get_err().unwrap(), "boom", "err.get_err unwraps error")
	assert_true(e.get_ok().is_none(), "err.get_ok is none")

	assert_eq(o.map_err(func(_err: Variant) -> String: return "x"), o, "ok.map_err returns self")
	var mapped: StdResult = e.map_err(func(err: String) -> String: return err + "!")
	assert_err(mapped, "err.map_err stays err")
	assert_eq(mapped.unwrap_err(), "boom!", "err.map_err transforms error")

	var seen: Array = []
	assert_eq(o.inspect_err(func(err: Variant) -> void: seen.append(err)), o, "ok.inspect_err returns self")
	assert_eq(seen.size(), 0, "ok.inspect_err does not call callable")
	assert_eq(e.inspect_err(func(err: Variant) -> void: seen.append(err)), e, "err.inspect_err returns self")
	assert_eq(seen, ["boom"], "err.inspect_err receives error")

	var fallback: StdResult = StdResult.ok("fallback")
	assert_eq(o.or_res(fallback), o, "ok.or_res returns self")
	assert_eq(e.or_res(fallback), fallback, "err.or_res returns fallback")
	assert_eq(o.or_else(func(_err: Variant) -> StdResult: return fallback), o, "ok.or_else returns self")
	var recovered: StdResult = e.or_else(
		func(err: String) -> StdResult: return StdResult.ok(err + "?"))
	assert_ok(recovered, "err.or_else recovers to ok")
	assert_eq(recovered.unwrap(), "boom?", "err.or_else receives error")
	return


func _test_result_transformations() -> void:
	var ok: StdResult = StdResult.ok(21)
	var err: StdResult = StdResult.err("boom")
	var calls: Array[String] = []

	var mapped: StdResult = ok.map(func(value: int) -> int:
		calls.append("map")
		return value * 2)
	assert_eq(mapped.unwrap(), 42, "ok.map transforms the value")
	assert_true(mapped != ok, "ok.map returns a new result")
	assert_eq(err.map(func(_value: Variant) -> Variant:
		calls.append("err.map")
		return null), err, "err.map returns self")
	assert_eq(calls, ["map"], "map calls only on ok")

	assert_eq(ok.map_or(7, func(value: int) -> int: return value + 1), 22, "ok.map_or maps")
	assert_eq(err.map_or(7, func(_value: Variant) -> int: return 0), 7, "err.map_or uses default")
	var eager_calls: Array[String] = []
	assert_eq(
		ok.map_or(_record_value(eager_calls, "default", 7), func(value: int) -> int: return value),
		21,
		"map_or keeps the ok result")
	assert_eq(eager_calls, ["default"], "map_or evaluates its default eagerly")

	var lazy_calls: Array[String] = []
	assert_eq(
		ok.map_or_else(
			func(_error: Variant) -> int:
				lazy_calls.append("default")
				return 7,
			func(value: int) -> int:
				lazy_calls.append("map")
				return value + 1),
		22,
		"ok.map_or_else maps")
	assert_eq(lazy_calls, ["map"], "ok.map_or_else calls only the mapper")
	lazy_calls.clear()
	assert_eq(
		err.map_or_else(
			func(error: String) -> String:
				lazy_calls.append("default")
				return error + "!",
			func(_value: Variant) -> String:
				lazy_calls.append("map")
				return "mapped"),
		"boom!",
		"err.map_or_else receives the error")
	assert_eq(lazy_calls, ["default"], "err.map_or_else calls only the fallback")

	var seen: Array[Variant] = []
	assert_eq(ok.inspect(func(value: Variant) -> void: seen.append(value)), ok, "ok.inspect returns self")
	assert_eq(err.inspect(func(value: Variant) -> void: seen.append(value)), err, "err.inspect returns self")
	assert_eq(seen, [21], "inspect observes only ok")
	return


func _test_result_composition() -> void:
	var ok_a: StdResult = StdResult.ok("a")
	var ok_b: StdResult = StdResult.ok("b")
	var err_a: StdResult = StdResult.err("a")
	var err_b: StdResult = StdResult.err("b")

	assert_eq(ok_a.and_res(ok_b), ok_b, "ok.and_res(ok) returns alternative")
	assert_eq(ok_a.and_res(err_b), err_b, "ok.and_res(err) returns alternative")
	assert_eq(err_a.and_res(ok_b), err_a, "err.and_res(ok) returns self")
	assert_eq(err_a.and_res(err_b), err_a, "err.and_res(err) returns self")
	var eager_calls: Array[String] = []
	assert_eq(
		err_a.and_res(_record_result(eager_calls, "alternative", ok_b)),
		err_a,
		"err.and_res keeps self")
	assert_eq(eager_calls, ["alternative"], "and_res evaluates its alternative eagerly")

	var chained: StdResult = ok_a.and_then(func(value: String) -> StdResult:
		return StdResult.ok(value + "!"))
	assert_eq(chained.unwrap(), "a!", "ok.and_then receives value")
	var calls: Array[String] = []
	assert_eq(
		err_a.and_then(func(_value: Variant) -> StdResult:
			calls.append("and_then")
			return ok_b),
		err_a,
		"err.and_then returns self")
	assert_true(calls.is_empty(), "err.and_then skips callable")

	assert_eq(StdResult.ok(ok_a).flatten(), ok_a, "flatten ok(ok) returns inner ok")
	assert_eq(StdResult.ok(err_b).flatten(), err_b, "flatten ok(err) returns inner err")
	assert_eq(err_a.flatten(), err_a, "flatten err returns self")
	return


func _test_result_warn() -> void:
	expect_warning("boom", "err.warn warns")
	expect_warning("python: boom", "prefixed err.warn warns")
	expect_warning("boom", "check_err err.warn warns")
	expect_warning("boom", "unwrap_err err.warn warns")
	expect_warning("python: boom", "chained prefixed err.warn warns")
	expect_warning("x", "chained err.warn warns")
	var o: StdResult = StdResult.ok(1)
	var e: StdResult = StdResult.err("boom")

	assert_eq(o.warn(), o, "ok.warn returns self")
	assert_eq(e.warn(), e, "err.warn returns self")
	assert_eq(o.warn("python"), o, "ok.warn(prefix) returns self")
	assert_eq(e.warn("python"), e, "err.warn(prefix) returns self")

	assert_ok(o.warn(), "ok.warn stays ok")
	assert_eq(o.warn().unwrap(), 1, "ok.warn does not touch the value")
	assert_err(e.warn(), "err.warn stays err")
	assert_eq(e.warn().unwrap_err(), "boom", "err.warn does not touch the error")

	# The point of returning self: it drops into a call chain without a temp.
	assert_eq(e.warn("python").unwrap_or(9), 9, "warn chains into unwrap_or")
	assert_eq(StdResult.err("x").warn().or_res(StdResult.ok(2)).unwrap(), 2, "warn chains into or_res")
	return


func _test_result_warn_output() -> void:
	var outcome: Dictionary = _run_failure_probes(
		PackedStringArray(["result_warn", "result_warn_ok"]))
	var output: String = outcome.output
	assert_eq(outcome.code, 0, "warning probe exits normally")
	assert_true(output.contains("probe: boom"), "err.warn writes its prefixed error")
	assert_true(not output.contains("probe-ok: quiet"), "ok.warn remains silent")
	return


func _test_failure_contracts() -> void:
	var debug_cases: Dictionary = {
		"result_unwrap": "called StdResult.unwrap() on an Err value: boom",
		"result_expect": "result expect probe",
		"result_unwrap_err": "called StdResult.unwrap_err() on an Ok value: value",
		"result_expect_err": "result expect_err probe",
		"option_unwrap": "called StdOption.unwrap() on a None value",
		"option_expect": "option expect probe",
		"result_constructor": "StdResult constructed with invalid return type 2",
		"option_constructor": "StdOption constructed with invalid return type 0",
		"result_constructor_unknown": "StdResult constructed with invalid return type 99",
		"option_constructor_unknown": "StdOption constructed with invalid return type 99",
		"result_is_ok_and": "StdResult.is_ok_and() called with an invalid Callable",
		"result_is_err_and": "StdResult.is_err_and() called with an invalid Callable",
		"result_unwrap_or_else": "StdResult.unwrap_or_else() called with an invalid Callable",
		"result_map": "StdResult.map() called with an invalid Callable",
		"result_map_or": "StdResult.map_or() called with an invalid Callable",
		"result_map_or_else_ok": "StdResult.map_or_else() called with an invalid Callable",
		"result_map_or_else_err": "StdResult.map_or_else() called with an invalid Callable",
		"result_inspect": "StdResult.inspect() called with an invalid Callable",
		"result_map_err": "StdResult.map_err() called with an invalid Callable",
		"result_inspect_err": "StdResult.inspect_err() called with an invalid Callable",
		"result_and_then": "StdResult.and_then() called with an invalid Callable",
		"result_and_then_return": "StdResult.and_then() callback must return an StdResult",
		"result_or_else": "StdResult.or_else() called with an invalid Callable",
		"result_or_else_return": "StdResult.or_else() callback must return an StdResult",
		"result_flatten": "StdResult.flatten() called on an Ok value that does not contain an StdResult",
		"option_is_some_and": "StdOption.is_some_and() called with an invalid Callable",
		"option_is_none_or": "StdOption.is_none_or() called with an invalid Callable",
		"option_unwrap_or_else": "StdOption.unwrap_or_else() called with an invalid Callable",
		"option_map": "StdOption.map() called with an invalid Callable",
		"option_map_or": "StdOption.map_or() called with an invalid Callable",
		"option_map_or_else_some": "StdOption.map_or_else() called with an invalid Callable",
		"option_map_or_else_none": "StdOption.map_or_else() called with an invalid Callable",
		"option_inspect": "StdOption.inspect() called with an invalid Callable",
		"option_filter": "StdOption.filter() called with an invalid Callable",
		"option_and_then": "StdOption.and_then() called with an invalid Callable",
		"option_and_then_return": "StdOption.and_then() callback must return an StdOption",
		"option_or_else": "StdOption.or_else() called with an invalid Callable",
		"option_or_else_return": "StdOption.or_else() callback must return an StdOption",
		"option_flatten": "StdOption.flatten() called on a Some value that does not contain an StdOption",
		"option_ok_or_else": "StdOption.ok_or_else() called with an invalid Callable",
		"option_and_opt_null": "StdOption.and_opt() called with a null StdOption",
		"option_or_opt_null": "StdOption.or_opt() called with a null StdOption",
		"option_xor_opt_null": "StdOption.xor_opt() called with a null StdOption",
		"result_and_res_null": "StdResult.and_res() called with a null StdResult",
		"result_or_res_null": "StdResult.or_res() called with a null StdResult",
	}
	var debug_case_names: PackedStringArray = PackedStringArray()
	for case_name: String in debug_cases:
		debug_case_names.append(case_name)
	var debug_outcome: Dictionary = _run_failure_probes(debug_case_names)
	var debug_output: String = debug_outcome.output
	for case_name: String in debug_cases:
		assert_true(debug_output.contains(debug_cases[case_name]), "%s reports its invariant" % case_name)
	assert_true(not debug_output.contains("PROBE_RETURNED_WRONG_PAYLOAD"), "debug failures have safe fallbacks")

	var release_outcome: Dictionary = _run_failure_probes(PackedStringArray(["release_failure"]))
	var release_output: String = release_outcome.output
	assert_true(int(release_outcome.code) != 0, "release failure exits abnormally")
	assert_true(release_output.contains("forced release failure"), "release failure reports its invariant")
	assert_true(not release_output.contains("PROBE_CONTINUED"), "release failure cannot continue")
	return


func _test_invalid_callables_stay_lazy() -> void:
	var invalid: Callable = Callable()

	assert_true(not StdResult.err("boom").is_ok_and(invalid), "err.is_ok_and skips invalid callable")
	assert_true(not StdResult.ok(1).is_err_and(invalid), "ok.is_err_and skips invalid callable")
	assert_eq(StdResult.ok(1).unwrap_or_else(invalid), 1, "ok.unwrap_or_else skips invalid callable")
	var err: StdResult = StdResult.err("boom")
	var ok: StdResult = StdResult.ok(1)
	assert_eq(err.map(invalid), err, "err.map skips invalid callable")
	assert_eq(err.map_or(7, invalid), 7, "err.map_or skips invalid callable")
	assert_eq(ok.map_or_else(invalid, func(value: int) -> int: return value), 1,
		"ok.map_or_else skips invalid fallback callable")
	assert_eq(err.map_or_else(func(_error: Variant) -> int: return 7, invalid), 7,
		"err.map_or_else skips invalid mapper")
	assert_eq(err.inspect(invalid), err, "err.inspect skips invalid callable")
	assert_eq(StdResult.ok(1).map_err(invalid).unwrap(), 1, "ok.map_err skips invalid callable")
	assert_eq(StdResult.ok(1).inspect_err(invalid).unwrap(), 1, "ok.inspect_err skips invalid callable")
	assert_eq(err.and_then(invalid), err, "err.and_then skips invalid callable")
	assert_eq(StdResult.ok(1).or_else(invalid).unwrap(), 1, "ok.or_else skips invalid callable")

	assert_true(not StdOption.none().is_some_and(invalid), "none.is_some_and skips invalid callable")
	assert_true(StdOption.none().is_none_or(invalid), "none.is_none_or skips invalid callable")
	assert_eq(StdOption.some(1).unwrap_or_else(invalid), 1, "some.unwrap_or_else skips invalid callable")
	var none: StdOption = StdOption.none()
	var some: StdOption = StdOption.some(1)
	assert_eq(none.map(invalid), none, "none.map skips invalid callable")
	assert_eq(none.map_or(7, invalid), 7, "none.map_or skips invalid callable")
	assert_eq(some.map_or_else(invalid, func(value: int) -> int: return value), 1,
		"some.map_or_else skips invalid default callable")
	assert_eq(none.map_or_else(func() -> int: return 7, invalid), 7,
		"none.map_or_else skips invalid mapper")
	assert_eq(none.inspect(invalid), none, "none.inspect skips invalid callable")
	assert_eq(none.filter(invalid), none, "none.filter skips invalid callable")
	assert_eq(none.and_then(invalid), none, "none.and_then skips invalid callable")
	assert_eq(some.or_else(invalid), some, "some.or_else skips invalid callable")
	assert_eq(some.ok_or_else(invalid).unwrap(), 1, "some.ok_or_else skips invalid callable")
	return


func _run_failure_probes(case_names: PackedStringArray) -> Dictionary:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		FAILURE_PROBE,
		"--",
	])
	args.append_array(case_names)
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	return {"code": code, "output": "\n".join(output)}


func _record_value(calls: Array[String], marker: String, value: Variant) -> Variant:
	calls.append(marker)
	return value


func _record_option(calls: Array[String], marker: String, option: StdOption) -> StdOption:
	calls.append(marker)
	return option


func _record_result(calls: Array[String], marker: String, result: StdResult) -> StdResult:
	calls.append(marker)
	return result
