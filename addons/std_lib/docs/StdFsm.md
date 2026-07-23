# Std FSM

[← StdLib](../../../README.md)

## Description

A node-based finite state machine. Add a machine to a scene, make its states
direct children, and select a starting state. The machine drives itself through
Godot's frame, physics, and unhandled-input callbacks; the owning scene does not
need to forward them.

States transition by returning their successor:

```gdscript
extends StdFSMState2D

const GRAVITY: float = 980.0

func process_physics(delta: float) -> StdFSMState:
	var actor: CharacterBody2D = body as CharacterBody2D
	if actor == null:
		return null
	actor.velocity.y += GRAVITY * delta
	actor.move_and_slide()
	if actor.is_on_floor():
		return machine.state(&"idle").unwrap() as StdFSMState
	return null
```

The module depends on [StdReturns](StdReturns.md): lookup returns `StdOption`,
and every fallible operation returns `StdResult`.

| Type | Role |
|---|---|
| `StdFSMachine` | Concrete machine for any `Node` target. |
| `StdFSMachine2D` / `StdFSMachine3D` | Concrete machines with dimension-typed `body` access. |
| `StdFSMState` | Concrete state with no-op defaults; extend this for ordinary states. |
| `StdFSMState2D` / `StdFSMState3D` | States with dimension-typed `body` access. |
| `StdFSMachineInterface` / `StdFSMStateInterface` | Abstract extension contracts; do not instantiate. |

All types are globally registered `class_name` classes. Machines and states are
nodes instantiated per scene; this module adds no autoload.

## Scene setup

The states must be direct children of the machine and have unique, non-empty
`state_name` values:

```text
Player (CharacterBody2D)
└── StateMachine (StdFSMachine2D)
    ├── Idle (StdFSMState2D, state_name = "idle")
    ├── Run  (StdFSMState2D, state_name = "run")
    └── Jump (StdFSMState2D, state_name = "jump")
```

Set `starting_state` to one of those children. `target` is optional and defaults
to the machine's parent. On `_ready`, the machine validates the complete setup,
wires every state, and enters the starting state. Invalid setup produces a
warning and leaves the machine safely uninitialized.

Choose the machine and state types that match the controlled node:

| Controlled node | Machine | States |
|---|---|---|
| any `Node` | `StdFSMachine` | `StdFSMState` |
| `Node2D` | `StdFSMachine2D` | `StdFSMState2D` |
| `Node3D` | `StdFSMachine3D` | `StdFSMState3D` |

The dimensional machines reject targets of the wrong type. Their states expose
the controlled node through typed `body` properties. Every state, including a
plain `StdFSMState`, can also access it through `target`.

`body` is typed only to the dimension (`Node2D` or `Node3D`). Cast it to a
narrower game type, such as `CharacterBody2D`, before calling APIs that do not
exist on the base dimensional node.

## Lifecycle and dispatch

The active state receives three callbacks:

```gdscript
func process_frame(delta: float) -> StdFSMState
func process_physics(delta: float) -> StdFSMState
func process_input(event: InputEvent) -> StdFSMState
```

Return another registered state to transition or `null` to remain in the current
state. A successful transition runs `exit()` on the old state, updates
`last_state` and `current_state`, runs `enter()` on the new state, and emits
`state_changed`. Returning the current state is a successful no-op and does not
repeat lifecycle hooks.

The machine calls these state methods from `_process`, `_physics_process`, and
`_unhandled_input`. Each channel has its own flag in addition to the master
`enabled` flag:

```gdscript
machine.process_enabled = false
machine.physics_enabled = true
machine.input_enabled = true
```

Disabling the machine exits the current state. Re-enabling enters that same
state again. The three channel flags retain their values throughout the cycle.

## Machine API

### Configuration and state

```gdscript
@export var starting_state: StdFSMState
@export var target: Node

var current_state: StdFSMState                       # read-only
var last_state: StdFSMState                          # read-only
var state_list: Dictionary[StringName, StdFSMState]  # read-only copy
var enabled: bool
var process_enabled: bool
var physics_enabled: bool
var input_enabled: bool
```

`starting_state` is initialization configuration. The Inspector value of
`target` is used during initialization. Assigning `target` after initialization
validates and applies the change through `retarget()`; call `retarget()` directly
when the caller needs to handle its result. An invalid assignment warns and
leaves the existing target unchanged. `state_list` and `get_states()` return
copies, so callers cannot mutate the internal registry.

### Initialization

```gdscript
func init(target_node: Node) -> StdResult
```

Called automatically from `_ready`. Manual initialization is useful for nodes
constructed outside the scene tree, including tests. It returns an error when:

- the target is null, freed, or incompatible with a dimensional machine;
- there are no state children;
- a state name is empty or duplicated; or
- a state child still belongs to another initialized machine; or
- `starting_state` is not a direct registered child.

Validation is atomic: failure wires no states and selects no current state. A
successfully initialized machine cannot be initialized again; use `retarget()`
or `refresh_states()` for runtime changes.

```gdscript
var result: StdResult = machine.init(player)
if result.is_err():
	push_error(result.unwrap_err())
```

### Lookup and transitions

```gdscript
func state(key: StringName) -> StdOption
func is_in(key: StringName) -> bool
func change_state(next_state: StdFSMState) -> StdResult
func change_state_to(key: StringName) -> StdResult
```

`state()` returns the registered state or `StdOption.none()`. State process methods
usually use it to return a successor. When a missing name is recoverable, inspect
the option instead of unwrapping it:

```gdscript
func process_input(event: InputEvent) -> StdFSMState:
	if not event.is_action_pressed(&"jump"):
		return null
	var jump: StdOption = machine.state(&"jump")
	if jump.is_none():
		return null
	return jump.unwrap() as StdFSMState
```

Use `change_state_to()` for transitions initiated outside a state callback, such
as a damage signal:

```gdscript
var result: StdResult = machine.change_state_to(&"stunned")
if result.is_err():
	push_warning(result.unwrap_err())
```

Transitions return an error when the machine is uninitialized, disabled, already
running a lifecycle callback, or given a null or foreign state. A freed
registered state is unavailable through `state()` and produces an error through
`change_state_to()`. GDScript itself rejects passing a freed object to the typed
`change_state(StdFSMState)` parameter before the method runs. Invalid transitions
do not alter the current or last state.

### Enable and retarget

```gdscript
func enable(value: bool) -> void
func retarget(target_node: Node) -> StdResult
```

`enable()` is equivalent to assigning `enabled`. Repeated assignments are
no-ops. `retarget()` validates the new controlled node and updates every state.
When enabled, it balances the current state's `exit()` and `enter()` around the
target change; when disabled, it runs no lifecycle hooks.

### Fixed registry and refresh

```gdscript
func get_states() -> Dictionary[StringName, StdFSMState]
func refresh_states() -> StdResult
```

The registry is fixed after initialization. Adding/removing state children or
editing `state_name` at runtime has no lookup effect until `refresh_states()` is
called. Refresh validates a candidate registry before committing it. Empty or
duplicate names and removal of the current state return errors while preserving
the previous registry.

A state can be registered with only one machine. To move a non-current state,
remove it from the source, call `source.refresh_states()` to release its
ownership, then add it to the destination and call
`destination.refresh_states()`. Trying to refresh the destination first returns
an error without stealing or partially rewiring the state. Transition away from
a current state before attempting to move it.

### Transition signal

```gdscript
signal state_changed(previous: StdFSMState, current: StdFSMState)
```

Emitted after lifecycle callbacks complete. Initial selection emits with
`previous == null`. Same-state no-ops, enable cycles, and retargets do not emit
because the selected state identity did not change.

## State API

```gdscript
@export var state_name: StringName

var machine: StdFSMachineInterface
var target: Node

func enter() -> void
func exit() -> void
func process_input(event: InputEvent) -> StdFSMState
func process_frame(delta: float) -> StdFSMState
func process_physics(delta: float) -> StdFSMState
```

`machine` and `target` are read-only and are assigned during machine
initialization or refresh. `StdFSMState` supplies no-op lifecycle methods and
returns `null` from each process method. Override only what a state needs.
`StdFSMState2D` and `StdFSMState3D` add their typed `body` properties:

```gdscript
class_name RunState
extends StdFSMState2D

const SPEED: float = 300.0

func process_physics(_delta: float) -> StdFSMState:
	var actor: CharacterBody2D = body as CharacterBody2D
	if actor == null:
		return null
	var direction: float = Input.get_axis(&"left", &"right")
	if is_zero_approx(direction):
		return machine.state(&"idle").unwrap() as StdFSMState
	actor.velocity.x = direction * SPEED
	actor.move_and_slide()
	return null
```

## Usage cautions

### Return from state callbacks; call from external events

Inside `process_*`, return the desired successor. For a transition driven by an
external signal or system, call `change_state()` or `change_state_to()` and
handle its `StdResult`. Lifecycle callbacks cannot start another transition; such a
call returns an error to prevent nested transitions from corrupting state.

### Disabled transitions are rejected

A disabled machine is lifecycle-inactive. Transition calls return an error and
are not queued. Re-enable before requesting the transition if it should happen
immediately.

### Registry changes are explicit

State children and names are treated as stable configuration. If a game truly
changes them at runtime, call `refresh_states()` and handle the result. There is
no automatic tree monitoring or hierarchical-state behavior. Transition away
from a state before removing or freeing it.

### `unwrap()` asserts when lookup fails

`machine.state(&"name").unwrap()` is concise for names guaranteed by a validated
scene. For dynamic names, check the `StdOption` or use `change_state_to()`, whose
missing-name path is a normal `StdResult.err`.

## Testing

```bash
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-fsm
```

The suite covers atomic validation, real scene-tree initialization, target
wiring, every dispatch channel, lifecycle ordering, signals, named and invalid
transitions, disabled behavior, re-entrant transition rejection, registry
refresh, cross-machine ownership, typed variants, and target changes.

See [StdTests](StdTests.md) for the test runner.

## See also

- [StdReturns](StdReturns.md) — `state()` returns `StdOption`; fallible operations
  return `StdResult`.
- [StdEcs](StdEcs.md) — component-store game logic rather than per-entity states.
