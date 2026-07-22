extends StdTest
## Deterministic model-based stress tests for StdOption and StdResult.


func _test_falsy_and_null_payloads_remain_wrapped() -> void:
	var values: Array = [null, false, 0, 0.0, "", Vector2.ZERO, [], {}]
	for value: Variant in values:
		var option: StdOption = StdOption.some(value)
		assert_true(option.is_some(), "falsy payload remains some")
		assert_eq(option.unwrap(), value, "some preserves falsy payload")
		assert_ok(option.ok_or("missing"), "some falsy converts to ok")
		assert_eq(option.ok_or("missing").unwrap(), value, "option conversion preserves falsy payload")

		var ok: StdResult = StdResult.ok(value)
		assert_true(ok.is_ok(), "falsy payload remains ok")
		assert_eq(ok.unwrap(), value, "ok preserves falsy payload")
		assert_true(ok.get_ok().is_some(), "ok falsy converts to some")
		assert_eq(ok.get_ok().unwrap(), value, "result conversion preserves falsy payload")

		var err: StdResult = StdResult.err(value)
		assert_true(err.is_err(), "falsy payload remains err")
		assert_eq(err.unwrap_err(), value, "err preserves falsy payload")
		assert_true(err.get_err().is_some(), "err falsy converts to some")
		assert_eq(err.get_err().unwrap(), value, "error conversion preserves falsy payload")
		pass
	return


func _test_factories_and_not_implemented_contract() -> void:
	var none: StdOption = StdOption.none()
	assert_true(none.is_none(), "none factory creates none")
	assert_eq(none.unwrap_or(null), null, "none permits null fallback")
	var not_implemented: StdResult = StdResult.not_implemented()
	assert_err(not_implemented, "not_implemented returns err")
	assert_eq(not_implemented.unwrap_err(), "Method not implemented.",
		"not_implemented has stable diagnostic")
	return


func _test_option_randomized_pipeline_matches_model() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x0F710
	var option: StdOption = StdOption.none()
	var expected_some: bool = false
	var expected: Variant = null
	for step: int in range(10000):
		var operation: int = rng.randi_range(0, 9)
		if operation == 0:
			expected = _random_value(rng)
			expected_some = true
			option = StdOption.some(expected)
		elif operation == 1:
			expected = null
			expected_some = false
			option = StdOption.none()
		elif operation == 2:
			option = option.map(func(value: Variant) -> int:
				return 999 if value == null else int(value) + 1)
			if expected_some:
				expected = 999 if expected == null else int(expected) + 1
				pass
		elif operation == 3:
			option = option.filter(func(value: Variant) -> bool:
				return value != null and int(value) % 2 == 0)
			if expected_some:
				expected_some = expected != null and int(expected) % 2 == 0
				if not expected_some:
					expected = null
					pass
				pass
		elif operation == 4:
			var fallback: int = rng.randi_range(-100, 100)
			option = option.or_else(func() -> StdOption: return StdOption.some(fallback))
			if not expected_some:
				expected_some = true
				expected = fallback
				pass
		elif operation == 5:
			option = option.and_then(func(value: Variant) -> StdOption:
				if value == null or int(value) < 0:
					return StdOption.none()
				return StdOption.some(int(value) * 2))
			if expected_some:
				if expected == null or int(expected) < 0:
					expected_some = false
					expected = null
				else:
					expected = int(expected) * 2
					pass
				pass
		elif operation == 6:
			var other_some: bool = rng.randi_range(0, 1) == 1
			var other_value: int = rng.randi_range(-100, 100)
			var other: StdOption = StdOption.some(other_value) if other_some else StdOption.none()
			option = option.xor_opt(other)
			if expected_some == other_some:
				expected_some = false
				expected = null
			elif other_some:
				expected_some = true
				expected = other_value
				pass
		elif operation == 7:
			option = option.ok_or("missing").get_ok()
		elif operation == 8:
			var actual: Variant = option.map_or_else(
				func() -> Variant: return "none",
				func(value: Variant) -> Variant: return value)
			assert_eq(actual, expected if expected_some else "none", "option map_or_else matches model")
		else:
			option = StdOption.some(option).flatten()
		assert_true(is_instance_valid(option), "option stress always returns a live wrapper")
		assert_eq(option.is_some(), expected_some, "option stress side matches model")
		assert_eq(option.is_none(), not expected_some, "option stress opposite side matches model")
		if expected_some:
			assert_eq(option.unwrap(), expected, "option stress payload matches model")
		pass
	return


func _test_result_randomized_pipeline_matches_model() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x2E517
	var result: StdResult = StdResult.ok(0)
	var expected_ok: bool = true
	var expected: Variant = 0
	for step: int in range(10000):
		var operation: int = rng.randi_range(0, 9)
		if operation == 0:
			expected = _random_value(rng)
			expected_ok = true
			result = StdResult.ok(expected)
		elif operation == 1:
			expected = _random_value(rng)
			expected_ok = false
			result = StdResult.err(expected)
		elif operation == 2:
			result = result.map(func(value: Variant) -> int:
				return 999 if value == null else int(value) + 1)
			if expected_ok:
				expected = 999 if expected == null else int(expected) + 1
				pass
		elif operation == 3:
			result = result.map_err(func(error: Variant) -> int:
				return -999 if error == null else -int(error))
			if not expected_ok:
				expected = -999 if expected == null else -int(expected)
				pass
		elif operation == 4:
			result = result.and_then(func(value: Variant) -> StdResult:
				if value == null or int(value) < 0:
					return StdResult.err(-1)
				return StdResult.ok(int(value) * 2))
			if expected_ok:
				if expected == null or int(expected) < 0:
					expected_ok = false
					expected = -1
				else:
					expected = int(expected) * 2
					pass
				pass
		elif operation == 5:
			result = result.or_else(func(_error: Variant) -> StdResult: return StdResult.ok(77))
			if not expected_ok:
				expected_ok = true
				expected = 77
				pass
		elif operation == 6:
			result = StdResult.ok(result).flatten()
		elif operation == 7:
			if expected_ok:
				result = result.get_ok().ok_or("missing")
			else:
				result = result.get_err().ok_or("missing")
				expected_ok = true
				pass
		elif operation == 8:
			var actual: Variant = result.map_or_else(
				func(error: Variant) -> Variant: return ["err", error],
				func(value: Variant) -> Variant: return ["ok", value])
			var model: Array = ["ok", expected] if expected_ok else ["err", expected]
			assert_eq(actual, model, "result map_or_else matches model")
		else:
			var observed: Array[Variant] = []
			result.inspect(func(value: Variant) -> void: observed.push_back(value))
			result.inspect_err(func(error: Variant) -> void: observed.push_back(error))
			assert_eq(observed, [expected], "exactly one result inspector runs")
		assert_true(is_instance_valid(result), "result stress always returns a live wrapper")
		assert_eq(result.is_ok(), expected_ok, "result stress side matches model")
		assert_eq(result.is_err(), not expected_ok, "result stress opposite side matches model")
		assert_eq(result.unwrap_or(null), expected if expected_ok else null,
			"result stress ok projection matches model")
		if not expected_ok:
			assert_eq(result.unwrap_err(), expected, "result stress error payload matches model")
		pass
	return


func _random_value(rng: RandomNumberGenerator) -> Variant:
	if rng.randi_range(0, 4) == 0:
		return null
	return rng.randi_range(-100, 100)
