# StdLib

*A standard library for the unhinged tiny dev.*

StdLib currently ships twelve verified Godot 4.6 modules: return values,
collections, grid math, finite state machines, algorithms, fixed-step timers,
signal helpers, node-tree helpers, deterministic random streams, pooled audio,
visual effects, and the testing framework used to validate them. Additional
modules will be added after they have been reviewed.

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
3. `std-grid`
4. `std-fsm`
5. `std-algorithms`
6. `std-timer`
7. `std-signals`
8. `std-node`
9. `std-random`
10. `std-audio`
11. `std-effects`
12. `std-tests`

Most modules expose global `class_name` types. `std-random`, `std-audio`, and
`std-effects` additionally register the root `StdRandom`, `StdAudio`, and
`StdEffects` autoloads. Disabling the parent plugin disables the twelve module
subplugins in reverse order.

## Modules

- **[StdReturns](addons/std_lib/docs/StdReturns.md)** — `StdResult`, `StdOption`, and their shared
  return-value contract.
- **[StdCollections](addons/std_lib/docs/StdCollections.md)** — stacks, queues, heaps, sets,
  trees, linked lists, bags, and object pools built around `StdOption` and
  `StdResult`.
- **[Std Grid](addons/std_lib/docs/StdGrid.md)** — rectangular board geometry, strict movement,
  optional edge wrapping, exclusive portals, deterministic placement, and a
  checkerboard renderer.
- **[Std FSM](addons/std_lib/docs/StdFsm.md)** — node-based finite state machines with
  validated transitions, lifecycle hooks, named lookup, and 2D/3D target
  accessors.
- **[StdAlgorithms](addons/std_lib/docs/StdAlgorithms.md)** — BFS, DFS, Dijkstra, iterative
  deepening search, topological sorting, stable array sorting, and reusable
  comparison callables.
- **[StdTimer](addons/std_lib/docs/StdTimer.md)** — a fixed-step simulation clock and a
  tick-denominated countdown with distinct completion and cancellation states.
- **[StdSignals](addons/std_lib/docs/StdSignals.md)** — idempotent, result-returning helpers for
  connecting and disconnecting Godot signals.
- **[StdNode](addons/std_lib/docs/StdNode.md)** — typed child and ancestor queries, child
  cleanup, and checks for nodes pending deletion.
- **[StdRandom](addons/std_lib/docs/StdRandom.md)** — named deterministic random streams,
  probability helpers, seeded selection and shuffling, and dice notation.
- **[StdAudio](addons/std_lib/docs/StdAudio.md)** — pooled global, 2D, and 3D audio playback
  using reusable recipes and explicit lifecycle handles.
- **[StdEffects](addons/std_lib/docs/StdEffects.md)** — pooled sprites and particles plus
  temporary shader effects, all driven by reusable recipes and handles.
- **[StdTests](addons/std_lib/docs/StdTests.md)** — synchronous and coroutine tests, lifecycle
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
	addons/std_lib/std-grid \
	addons/std_lib/std-fsm \
	addons/std_lib/std-algorithms \
	addons/std_lib/std-timer \
	addons/std_lib/std-signals \
	addons/std_lib/std-node \
	addons/std_lib/std-random \
	addons/std_lib/std-audio \
	addons/std_lib/std-effects \
	addons/std_lib/std-tests
```

The process exits with `0` when every suite passes and a nonzero status when a
suite fails or the runner receives invalid input.
