@abstract
class_name StdFSMachineInterface
extends Node
## Shared plumbing for a node-based finite state machine.
##
## Holds the current/last state, the controlled [member target] node, and the
## enable flags. The machine drives itself through the engine callbacks
## ([method _process], [method _physics_process], [method _unhandled_input]) so
## owners do not have to forward anything. Subclasses implement the dispatch
## policy via the abstract [code]process_*[/code] methods (see [StdFSMachine]).

## Emitted after the machine selects a different state and completes its
## lifecycle callbacks. [param previous] is null for the initial selection.
signal state_changed(previous: StdFSMState, current: StdFSMState)

#region Exports
## The state the machine will start in.
@export var starting_state: StdFSMState
## The node the states control. Defaults to [method Node.get_parent] when left null.
##
## Assignments after initialization are validated and applied through [method retarget].
## Use [method retarget] directly when the caller needs the returned [StdResult].
@export var target: Node:
	get: return _target_node
	set(value):
		if not _initialized:
			_target_node = value
			return
		var _result: StdResult = retarget(value).warn("StdFSMachine")
		return
#endregion Exports

#region Private Members
var _target_node: Node
var _current_state: StdFSMState
var _last_state: StdFSMState
var _state_list: Dictionary[StringName, StdFSMState] = {}
var _initialized: bool = false
var _transitioning: bool = false
var _enabled: bool = true
var _physics_enabled: bool = true
var _process_enabled: bool = true
var _input_enabled: bool = true
#endregion Private Members

#region Public Members
## The current state the machine is in.
var current_state: StdFSMState:
	get: return _current_state

## The last state the machine was in.
var last_state: StdFSMState:
	get: return _last_state

## Whether the machine is enabled. Disabling halts all processing.
var enabled: bool:
	get: return _enabled
	set(v): enable(v)

## Whether the machine's physics process is enabled.
var physics_enabled: bool:
	get: return _physics_enabled
	set(v): _physics_enabled = v

## Whether the machine's frame process is enabled.
var process_enabled: bool:
	get: return _process_enabled
	set(v): _process_enabled = v

## Whether the machine's input process is enabled.
var input_enabled: bool:
	get: return _input_enabled
	set(v): _input_enabled = v

## A copy of the initialized state registry, keyed by [member StdFSMStateInterface.state_name].
var state_list: Dictionary[StringName, StdFSMState]:
	get: return get_states()
#endregion Public Members

#region Engine Methods
func _ready() -> void:
	if _initialized:
		return
	var _result: StdResult = init(target if target else get_parent()).warn("StdFSMachine")
	return


func _process(delta: float) -> void:
	if _initialized and _enabled and _process_enabled:
		process_frame(delta)
	return


func _physics_process(delta: float) -> void:
	if _initialized and _enabled and _physics_enabled:
		process_physics(delta)
	return


func _unhandled_input(event: InputEvent) -> void:
	if _initialized and _enabled and _input_enabled:
		process_input(event)
	return
#endregion Engine Methods

#region Public API
## Wires the child states to this machine, assigns the controlled [param target_node],
## and selects [member starting_state]. Called automatically from [method _ready].
## Errs for invalid targets, state names, or starting states. On success the ok
## value is this machine.
func init(target_node: Node) -> StdResult:
	if _initialized:
		return StdResult.err("StdFSMachine is already initialized; use retarget() or refresh_states()")
	var valid_target: StdResult = _validate_target(target_node)
	if valid_target.is_err(): return valid_target
	var collected: StdResult = _collect_states()
	if collected.is_err(): return collected
	var states: Dictionary[StringName, StdFSMState] = collected.unwrap()
	if starting_state == null:
		return StdResult.err("StdFSMachine needs a starting_state")
	if not _has_state(states, starting_state):
		return StdResult.err("starting_state must be a direct registered StdFSMState child")

	_target_node = target_node
	_state_list = states
	_wire_states(_state_list)
	_initialized = true
	_select_state(starting_state, _enabled)
	return StdResult.ok(self)


## Changes to [param next_state]. Errs when the machine cannot transition. A
## transition to the current state succeeds without repeating lifecycle calls.
## On success the ok value is [param next_state].
func change_state(next_state: StdFSMState) -> StdResult:
	if not _initialized:
		return StdResult.err("StdFSMachine is not initialized")
	if _transitioning:
		return StdResult.err("StdFSMachine cannot change state during a lifecycle callback")
	if not enabled:
		return StdResult.err("StdFSMachine is disabled")
	if next_state == null or not is_instance_valid(next_state):
		return StdResult.err("next state is null or freed")
	if not _has_state(_state_list, next_state):
		return StdResult.err("state '%s' is not registered with this StdFSMachine" % next_state.state_name)
	if next_state == _current_state:
		return StdResult.ok(next_state)
	_select_state(next_state, true)
	return StdResult.ok(next_state)


## Looks up [param key] and changes to that state. Errs when the name is not
## registered or the machine cannot transition.
func change_state_to(key: StringName) -> StdResult:
	if not _initialized:
		return StdResult.err("StdFSMachine is not initialized")
	var found: StdOption = state(key)
	if found.is_none():
		return StdResult.err("state '%s' is not registered with this StdFSMachine" % key)
	return change_state(found.unwrap())


## Enables or disables the machine. Disabling exits the current state and
## enabling enters it again. Per-channel processing flags are preserved.
func enable(v: bool) -> void:
	if _enabled == v:
		return
	if _transitioning:
		push_warning("StdFSMachine cannot change enabled during a lifecycle callback")
		return
	_transitioning = _initialized and _current_state != null
	_enabled = v
	if _transitioning and _enabled:
		_current_state.enter()
	elif _transitioning:
		_current_state.exit()
	_transitioning = false
	return


## Gets a copy of the initialized state registry.
func get_states() -> Dictionary[StringName, StdFSMState]:
	var states: Dictionary[StringName, StdFSMState] = {}
	for key: StringName in _state_list:
		var found: Variant = _state_list[key]
		if not is_instance_valid(found):
			continue
		states[key] = found as StdFSMState
	return states


## Rebuilds the registry from direct child states. The update is atomic: invalid
## names, duplicates, or removal of the current state leave the old registry in
## place. On success the ok value is a copy of the new registry.
func refresh_states() -> StdResult:
	if not _initialized:
		return StdResult.err("StdFSMachine is not initialized")
	if _transitioning:
		return StdResult.err("StdFSMachine cannot refresh states during a lifecycle callback")
	var collected: StdResult = _collect_states()
	if collected.is_err(): return collected
	var states: Dictionary[StringName, StdFSMState] = collected.unwrap()
	if not _has_state(states, _current_state):
		return StdResult.err("refresh would remove the current state")

	for old_value: Variant in _state_list.values():
		if not is_instance_valid(old_value):
			continue
		var old_state: StdFSMState = old_value as StdFSMState
		if not _has_state(states, old_state) and old_state.machine == self:
			old_state._machine = null
			old_state._target = null
			continue
	_state_list = states
	_wire_states(_state_list)
	return StdResult.ok(get_states())


## Changes the node controlled by every state. Active machines balance the
## current state's exit/enter hooks around the target change.
func retarget(target_node: Node) -> StdResult:
	if not _initialized:
		return StdResult.err("StdFSMachine is not initialized")
	if _transitioning:
		return StdResult.err("StdFSMachine cannot retarget during a lifecycle callback")
	var valid_target: StdResult = _validate_target(target_node)
	if valid_target.is_err(): return valid_target
	if target_node == _target_node:
		return StdResult.ok(target_node)

	_transitioning = _enabled and _current_state != null
	if _transitioning:
		_current_state.exit()
	_target_node = target_node
	_wire_states(_state_list)
	if _transitioning:
		_current_state.enter()
	_transitioning = false
	return StdResult.ok(target_node)


## The state registered under [param key] (its [member StdFSMStateInterface.state_name]),
## or [code]none[/code] when the machine has no such state.
func state(key: StringName) -> StdOption:
	var found: Variant = _state_list.get(key)
	if found == null or not is_instance_valid(found):
		return StdOption.none()
	return StdOption.some(found)


## True when the current state is the one registered under [param key].
func is_in(key: StringName) -> bool:
	return state(key).is_some_and(func(found: StdFSMState) -> bool: return current_state == found)
#endregion Public API

#region Private Helpers
func _select_state(next_state: StdFSMState, run_lifecycle: bool) -> void:
	_transitioning = true
	var previous: StdFSMState = _current_state
	if run_lifecycle and _current_state:
		_current_state.exit()
	_last_state = _current_state
	_current_state = next_state
	if run_lifecycle:
		_current_state.enter()
	_transitioning = false
	state_changed.emit(previous, _current_state)
	return


func _collect_states() -> StdResult:
	var states: Dictionary[StringName, StdFSMState] = {}
	for child: Node in get_children():
		if child is not StdFSMState:
			continue
		var child_state: StdFSMState = child as StdFSMState
		var key: StringName = child_state.state_name
		if key.is_empty():
			return StdResult.err("StdFSMState child '%s' has an empty state_name" % child_state.name)
		if states.has(key):
			return StdResult.err("duplicate StdFSMState name '%s'" % key)
		var owner: StdFSMachineInterface = child_state.machine
		if owner != null and is_instance_valid(owner) and owner != self:
			return StdResult.err("StdFSMState child '%s' belongs to another StdFSMachine" % key)
		states[key] = child_state
		continue
	if states.is_empty():
		return StdResult.err("StdFSMachine needs at least one StdFSMState child")
	return StdResult.ok(states)


func _wire_states(states: Dictionary[StringName, StdFSMState]) -> void:
	for child_state: StdFSMState in states.values():
		child_state._machine = self
		child_state._target = _target_node
		continue
	return


func _has_state(states: Dictionary[StringName, StdFSMState], wanted: StdFSMState) -> bool:
	for state_value: Variant in states.values():
		if is_instance_valid(state_value) and state_value == wanted:
			return true
		continue
	return false


## Validates a controlled node. Dimensional machines narrow this contract.
func _validate_target(target_node: Node) -> StdResult:
	if target_node == null or not is_instance_valid(target_node):
		return StdResult.err("StdFSMachine target is null or freed")
	return StdResult.ok(target_node)
#endregion Private Helpers

#region Abstract API
## Dispatches a frame to the current state.
@abstract func process_frame(_delta: float) -> void
## Dispatches a physics step to the current state.
@abstract func process_physics(_delta: float) -> void
## Dispatches input to the current state.
@abstract func process_input(_event: InputEvent) -> void
#endregion Abstract API
