# Testing Suite Requirements

StdTests is a lightweight, dependency-free test framework used internally by
StdLib. Projects that need doubles, parameterized tests, editor tooling, JUnit
export, or other advanced features should use a larger framework such as GUT.

## Test execution

- [x] Every suite extends `StdTest`.
- [x] Test functions begin with `_test_` and run in declaration order.
- [x] Suites are discovered recursively from `test_*.gd` files.
- [x] One or more files or directories can limit discovery.
- [x] Synchronous and coroutine test functions are supported.
- [x] Every function result is printed as soon as that function completes.
- [x] Passing runs hide expected engine diagnostics without disabling their
	  validation.
- [x] Failing runs replay raw engine diagnostics and backtraces after the
	  structured results.
- [x] A test function that performs no checks fails.
- [x] An unexpected engine warning, engine error, script error, or shader error
	  fails the function that emitted it.
- [x] Results include suite, function, and check pass/fail counts.
- [x] A failing result includes its test function and assertion name.
- [x] Interactive terminal output colors suite headings, passes, failures, and
	  totals while redirected and piped output remains plain.
- [x] `--color=auto`, `--color=always`, and `--color=never` control ANSI color.
- [x] Exit code `0` means every suite passed; `1` means a suite failed; `2`
	  means the runner received an invalid option.

## Diagnostics

- [x] `expect_warning(text, name)` consumes and passes for one matching warning.
- [x] `expect_error(text, name)` consumes and passes for one matching engine,
	  script, or shader error.
- [x] Diagnostics are captured with `StdTestLogger` and attributed to the active
	  lifecycle hook or test function.
- [x] `--show-engine-errors` streams diagnostics immediately for debugging.

The public runner launches an internal Godot worker with redirected stdout and
stderr. The worker keeps engine diagnostics enabled for `StdTestLogger`. The
launcher streams normal results and buffers stderr, discarding it after a
passing run or replaying it after a failure. This process boundary avoids the
engine limitation where disabling stderr also disables custom `Logger`
callbacks.

## Lifecycle and isolation

- [x] `_before_all()` runs once before the suite.
- [x] `_before_each()` runs before every test function.
- [x] `_after_each()` runs after every test function.
- [x] `_after_all()` runs once after the suite.
- [x] All lifecycle hooks may be synchronous or use `await`.
- [x] Nodes and signal monitors created during one test are cleaned after it.
- [x] Resources created in `_before_all()` survive the tests and are cleaned
	  after `_after_all()`.

## Assertions

### Boolean and comparison

- [x] `assert_true(value, name)`
- [x] `assert_false(value, name)`
- [x] `assert_eq(actual, expected, name)`
- [x] `assert_ne(actual, expected, name)`
- [x] `assert_lt(actual, expected, name)`
- [x] `assert_lte(actual, expected, name)`
- [x] `assert_gt(actual, expected, name)`
- [x] `assert_gte(actual, expected, name)`
- [x] `assert_approx_eq(actual, expected, tolerance, name)`
- [x] `assert_null(value, name)`
- [x] `assert_not_null(value, name)`

Ordering assertions accept numeric values. Unsupported values record framework
failures instead of causing engine errors.

### StdReturn

- [x] `assert_some(option, name)`
- [x] `assert_none(option, name)`
- [x] `assert_ok(result, name)`
- [x] `assert_err(result, name)`

### Collections

- [x] `assert_empty(value, name)`
- [x] `assert_not_empty(value, name)`
- [x] `assert_has(collection, item, name)`
- [x] `assert_not_has(collection, item, name)`

Collection assertions support Godot arrays, dictionaries, strings, packed
arrays, and valid objects that implement `is_empty()` or `has()`.

### Signals

- [x] `monitor_signal(signal)`
- [x] `assert_emitted(monitor, name)`
- [x] `assert_emitted_count(monitor, expected, name)`
- [x] `assert_emitted_with(monitor, expected_args, name)`

Signal monitors record every argument list and disconnect automatically during
cleanup.

## Engine interaction

- [x] `await process_wait(frames = 1)`
- [x] `await physics_wait(frames = 1)`
- [x] `add_to_tree(node)`
- [x] `remove_from_tree(node)`

`add_to_tree()` gives the framework cleanup ownership. `remove_from_tree()`
detaches the node without relinquishing that ownership.

## Compatibility

The old `check`, `check_eq`, `check_ok`, and `check_err` calls remain as
deprecated forwarding methods. StdLib's suites use the new assertion API.
