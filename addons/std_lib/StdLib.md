# StdLib

*A standard library for the unhinged tiny dev.*

StdLib currently ships four verified Godot 4.6 modules: return values,
collections, signal helpers, and the testing framework used to validate them.
Additional modules will be added after they have been reviewed.

```gdscript
var stack: StdStack = StdStack.new()
stack.push(StdResult.ok(42))

var result: StdResult = stack.pop().unwrap()
print(result.unwrap())
```

## Installation

Copy `addons/std_lib/` into a Godot project and enable **StdLib** under
*Project → Project Settings → Plugins*.

The parent plugin enables these module subplugins in dependency order:

1. `std-returns`
2. `std-collections`
3. `std-signals`
4. `std-tests`

These modules expose global `class_name` types and do not register autoloads.
Disabling the parent plugin disables the four module subplugins in reverse
order.

## Modules

- **[StdReturns](docs/StdReturns.md)** — `StdResult`, `StdOption`, and their shared
  return-value contract.
- **[StdCollections](docs/StdCollections.md)** — stacks, queues, heaps, sets,
  trees, linked lists, bags, and object pools built around `StdOption` and
  `StdResult`.
- **[StdSignals](docs/StdSignals.md)** — idempotent, result-returning helpers for
  connecting and disconnecting Godot signals.
- **[StdTests](docs/StdTests.md)** — synchronous and coroutine tests, lifecycle
  hooks, structured assertions, engine diagnostics, and a headless GDScript
  runner.

## Running tests

Run the selected modules with the Godot-only test runner:

```text
godot4.6 --headless \
	-s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- \
	addons/std_lib/std-returns \
	addons/std_lib/std-collections \
	addons/std_lib/std-signals \
	addons/std_lib/std-tests
```

The process exits with `0` when every suite passes and a nonzero status when a
suite fails or the runner receives invalid input.
