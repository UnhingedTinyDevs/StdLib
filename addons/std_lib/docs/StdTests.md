# Std Tests

[← StdLib](../StdLib.md)

StdTests is the dependency-free framework used to test StdLib. It supports
synchronous and coroutine tests, lifecycle hooks, structured results, engine
diagnostics, scene-tree helpers, and signal assertions while remaining small
enough to ship with the library.

## Writing a suite

Extend `StdTest` and name test functions with the `_test_` prefix:

```gdscript
extends StdTest

func _test_stack_is_lifo() -> void:
	var stack: StdStack = StdStack.new()
	stack.push(1)
	stack.push(2)
	assert_eq(stack.pop().unwrap(), 2, "last value leaves first")
	return
```

Functions run in declaration order, but tests should not depend on that order.
A function that performs no checks fails because a runtime error may otherwise
abort it without producing an assertion failure.

## Lifecycle

Override only the hooks a suite needs:

```gdscript
var subject: Node

func _before_all() -> void:
	# Suite resources survive until after _after_all().
	return

func _before_each() -> void:
	subject = add_to_tree(Node.new())
	return

func _after_each() -> void:
	# Per-test nodes and monitors are cleaned automatically after this hook.
	return

func _after_all() -> void:
	return
```

Hooks and test functions may wait for signals or other coroutines. The runner
awaits synchronous values immediately and resumes coroutines when they finish.

## Assertions

Every assertion takes a descriptive `name` that identifies a failed behavior.

### Values and comparisons

```gdscript
assert_true(value, name)
assert_false(value, name)
assert_eq(actual, expected, name)
assert_ne(actual, expected, name)
assert_lt(actual, expected, name)
assert_lte(actual, expected, name)
assert_gt(actual, expected, name)
assert_gte(actual, expected, name)
assert_approx_eq(actual, expected, tolerance, name)
assert_null(value, name)
assert_not_null(value, name)
```

Ordering assertions accept integers and floats. `assert_approx_eq` uses the
supplied absolute tolerance.

### StdResult and StdOption

```gdscript
assert_some(option, name)
assert_none(option, name)
assert_ok(result, name)
assert_err(result, name)
```

Failed return assertions include the contained value when one is available.

### Collections

```gdscript
assert_empty(value, name)
assert_not_empty(value, name)
assert_has(collection, item, name)
assert_not_has(collection, item, name)
```

These support strings, arrays, dictionaries, packed arrays, and valid objects
that implement `is_empty()` or `has()`.

### Deprecated names

`check`, `check_eq`, `check_ok`, and `check_err` forward to their corresponding
`assert_*` methods for compatibility. New and migrated tests should use the
assertion API.

## Signals

Monitor a first-class `Signal` before triggering the operation:

```gdscript
signal completed(label: String, amount: int)

func _test_completion_signal() -> void:
	var monitor: StdTestSignalMonitor = monitor_signal(completed)
	completed.emit("saved", 3)

	assert_emitted(monitor, "completion is emitted")
	assert_emitted_count(monitor, 1, "completion is emitted once")
	assert_emitted_with(monitor, ["saved", 3], "completion retains arguments")
	return
```

Each monitor records all emission argument arrays. Per-test monitors disconnect
after `_after_each()`; monitors created in `_before_all()` disconnect after
`_after_all()`.

## Scene tree and frames

`StdTest` receives the runner's `SceneTree` through an internal context:

```gdscript
func _test_node_processes() -> void:
	var node: Node = add_to_tree(MyNode.new())
	await process_wait(2)
	await physics_wait()
	assert_true(node.did_process, "node receives process frames")
	return
```

`add_to_tree(node)` adds the node to the tree root and transfers cleanup
ownership to the framework. `remove_from_tree(node)` detaches it but leaves that
cleanup ownership intact. Passing an already-parented node is a framework
failure.

Frame counts must be at least one. Both wait helpers must be called with
`await`.

## Engine diagnostics

Unexpected warnings, engine errors, script errors, and shader errors fail the
active function. Intentional diagnostics are checks:

```gdscript
func _test_invalid_size_warns() -> void:
	expect_warning("size must be positive", "invalid size warns")
	Thing.new(-1)
	return

func _test_missing_resource_errors() -> void:
	expect_error("resource was not found", "missing resource errors")
	load_required_resource("res://missing.tres")
	return
```

Each expectation consumes one diagnostic of the matching category. Matching
prefers complete text and then falls back to substring matching.

Godot does not expose separate switches for its built-in diagnostic logger and
custom `Logger` callbacks. StdTests handles this with two Godot processes. The
public runner redirects an internal worker's output. The worker keeps engine
diagnostics enabled so `StdTestLogger` can evaluate them, while the launcher
buffers the worker's stderr.

After a passing run, every buffered diagnostic was expected and stderr is
discarded. After a failing run, raw diagnostics and backtraces are replayed
after the structured results. Pass `--show-engine-errors` to stream stderr
immediately when investigating a test. This flag changes only display behavior;
diagnostic validation remains enabled.

## Results

Each function prints immediately after it completes:

```text
PASS _test_stack_is_lifo (1 checks, 0.041 ms)
FAIL _test_invalid_capacity (2 passed, 1 failed)
  - capacity clamps: got -1, expected 1
```

Every suite then prints function and check totals. The runner ends with totals
for all suites, functions, and checks.

Result data is represented by:

- `StdTestFailure` — one assertion, expectation, diagnostic, or framework failure.
- `StdTestCaseResult` — counts and failures for one `_test_*` function.
- `StdTestSuiteResult` — test-function and lifecycle totals for one script.
- `StdTestContext` — runner services and cleanup ownership.
- `StdTestSignalMonitor` — recorded emissions for one `Signal`.
- `StdTestLogger` / `StdTestLogEntry` — thread-safe engine diagnostic capture.

## Running

Run every `test_*.gd` script under the project:

```text
godot4.6 --headless \
	-s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path .
```

`std_test_runner.gd` is the public launcher. It starts the internal
`std_test_worker.gd` in another Godot process so expected diagnostics can be
validated without cluttering successful output. Do not invoke the worker
directly unless debugging the framework itself.

Suite headings, passing functions, failures, and totals are colored when the
launcher writes to an interactive terminal. Redirected and piped output stays
plain, so log files do not contain ANSI escape codes. Pass `--color=always` or
`--color=never` to override detection; `--color=auto` restores the default.
Setting the `NO_COLOR` environment variable also disables automatic color.

Everything after Godot's `--` separator is a runner option, test file, or test
directory:

```text
# One module
godot4.6 --headless \
	-s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- addons/std_lib/std-returns/tests

# Two selected suites
godot4.6 --headless \
	-s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- \
	addons/std_lib/std-returns/tests/test_std_returns.gd \
	addons/std_lib/std-collections/tests/test_std_stack.gd
```

Paths are project-relative unless they start with `res://`. Directories are
searched recursively for `test_*.gd` files and duplicate suites are removed. An
explicitly selected GDScript suite may use another filename, which is useful for
framework fixtures.

To stream engine warnings and errors during the run:

```text
godot4.6 --headless \
	-s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- --show-engine-errors addons/std_lib/std-collections/tests
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Every discovered suite passed. |
| `1` | A suite failed, no suites were found, or a path did not resolve. |
| `2` | The runner received an unknown option. |

## See also

- [StdReturns](StdReturns.md) — values used by the return assertions.
- [StdSignals](StdSignals.md) — result-returning signal connection helpers.
- [StdLib](../StdLib.md) — module index.
