extends StdTest
## Tests for the std-fsm machines.
##
## Machines are constructed directly because the headless runner does not add
## suites to the scene tree. Every fallible operation is checked explicitly.



class RecordingState extends StdFSMState:
	var calls: Array[String] = []
	var next_frame: StdFSMState
	var next_physics: StdFSMState
	var next_input: StdFSMState
	var enter_transition: StdFSMState
	var transition_results: Array[StdResult] = []

	func enter() -> void:
		calls.append("%s:enter" % state_name)
		if enter_transition != null:
			transition_results.append(machine.change_state(enter_transition))
		return

	func exit() -> void:
		calls.append("%s:exit" % state_name)
		return

	func process_frame(_delta: float) -> StdFSMState:
		calls.append("%s:frame" % state_name)
		return next_frame

	func process_physics(_delta: float) -> StdFSMState:
		calls.append("%s:physics" % state_name)
		return next_physics

	func process_input(_event: InputEvent) -> StdFSMState:
		calls.append("%s:input" % state_name)
		return next_input


func _test_init_builds_stable_registry_and_wires_states() -> void:
	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle", &"run"], calls, parent)
	var idle: RecordingState = _state(machine, &"idle")
	var states: Dictionary[StringName, StdFSMState] = machine.get_states()
	assert_eq(states.keys(), [&"idle", &"run"], "init registers states by StringName")
	assert_eq(idle.machine, machine, "init wires the state machine")
	assert_eq(idle.target, parent, "init wires the controlled target")
	assert_eq(machine.target, parent, "machine exposes the resolved target")
	assert_eq(machine.current_state, idle, "init selects the starting state")
	assert_eq(machine.last_state, null, "initial selection has no last state")
	assert_eq(calls, ["idle:enter"], "initial selection enters exactly once")
	states.erase(&"run")
	assert_true(machine.state(&"run").is_some(), "mutating get_states result cannot mutate the registry")
	var property_copy: Dictionary[StringName, StdFSMState] = machine.state_list
	property_copy.clear()
	assert_eq(machine.state_list.size(), 2, "state_list also returns a copy")
	_teardown(machine, parent)
	return


func _test_ready_initializes_from_the_scene_tree() -> void:
	var parent: Node = Node.new()
	var machine: StdFSMachine = StdFSMachine.new()
	var idle: RecordingState = _add_state(machine, &"idle", [])
	machine.starting_state = idle
	machine.process_enabled = false
	machine.physics_enabled = false
	machine.input_enabled = false
	parent.add_child(machine)

	var _added: Node = add_to_tree(parent)
	assert_eq(machine.target, parent, "_ready defaults the controlled target to the machine parent")
	assert_eq(machine.current_state, idle, "_ready selects the configured starting state")
	assert_eq(idle.machine, machine, "_ready wires the state to its machine")
	assert_eq(idle.target, parent, "_ready wires the resolved target into the state")
	return


func _test_init_validation_is_atomic() -> void:
	var parent: Node = Node.new()
	var machine: StdFSMachine = StdFSMachine.new()
	var unnamed: RecordingState = RecordingState.new()
	machine.add_child(unnamed)
	machine.starting_state = unnamed
	assert_err(machine.init(parent), "empty state names are rejected")
	assert_eq(unnamed.machine, null, "failed init does not partially wire states")
	assert_eq(machine.current_state, null, "failed init selects no state")
	unnamed.state_name = &"idle"
	assert_ok(machine.init(parent), "the same machine can initialize after correction")
	assert_err(machine.init(parent), "an initialized machine cannot initialize twice")
	_teardown(machine, parent)
	return


func _test_init_rejects_bad_registry_and_starting_state() -> void:
	var parent: Node = Node.new()
	var empty_machine: StdFSMachine = StdFSMachine.new()
	assert_err(empty_machine.init(parent), "a machine needs a state child")
	empty_machine.free()

	var duplicate_machine: StdFSMachine = StdFSMachine.new()
	var first: RecordingState = _add_state(duplicate_machine, &"same", [])
	var _second: RecordingState = _add_state(duplicate_machine, &"same", [])
	duplicate_machine.starting_state = first
	assert_err(duplicate_machine.init(parent), "duplicate state names are rejected")
	duplicate_machine.free()

	var foreign_machine: StdFSMachine = StdFSMachine.new()
	var child: RecordingState = _add_state(foreign_machine, &"idle", [])
	var foreign: StdFSMState = StdFSMState.new()
	foreign.state_name = &"foreign"
	foreign_machine.starting_state = foreign
	assert_err(foreign_machine.init(parent), "starting_state must be a registered direct child")
	assert_eq(child.machine, null, "foreign start rejection remains atomic")
	foreign.free()
	foreign_machine.free()
	parent.free()
	return


func _test_init_requires_valid_target() -> void:
	var machine: StdFSMachine = StdFSMachine.new()
	var idle: RecordingState = _add_state(machine, &"idle", [])
	machine.starting_state = idle
	assert_err(machine.init(null), "plain machines reject null targets")
	machine.free()

	var plain: Node = Node.new()
	var machine2d: StdFSMachine2D = StdFSMachine2D.new()
	var idle2d: RecordingState = _add_state(machine2d, &"idle", [])
	machine2d.starting_state = idle2d
	assert_err(machine2d.init(plain), "2D machines reject plain Node targets")
	machine2d.free()

	var machine3d: StdFSMachine3D = StdFSMachine3D.new()
	var idle3d: RecordingState = _add_state(machine3d, &"idle", [])
	machine3d.starting_state = idle3d
	assert_err(machine3d.init(plain), "3D machines reject plain Node targets")
	machine3d.free()
	plain.free()
	return


func _test_lookup_and_named_transition() -> void:
	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle", &"run"], calls, parent)
	assert_true(machine.state(&"run").is_some(), "state finds a registered name")
	assert_true(machine.state(&"missing").is_none(), "state returns none for an unknown name")
	assert_true(machine.is_in(&"idle"), "is_in identifies the initial state")
	assert_ok(machine.change_state_to(&"run"), "change_state_to transitions by name")
	assert_true(machine.is_in(&"run"), "named transition updates current state")
	assert_eq(machine.last_state, _state(machine, &"idle"), "named transition records last state")
	assert_err(machine.change_state_to(&"missing"), "unknown named transitions return an error")
	_teardown(machine, parent)
	return


func _test_transition_lifecycle_result_and_signal() -> void:
	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachine = StdFSMachine.new()
	var idle: RecordingState = _add_state(machine, &"idle", calls)
	var run: RecordingState = _add_state(machine, &"run", calls)
	var transitions: Array[Array] = []
	var _connected: int = machine.state_changed.connect(
		func(previous: StdFSMState, current: StdFSMState) -> void:
			transitions.append([previous, current])
	)
	machine.starting_state = idle
	assert_ok(machine.init(parent), "init succeeds")
	assert_eq(transitions, [[null, idle]], "initial selection emits from null")
	assert_ok(machine.change_state(run), "registered transition succeeds")
	assert_eq(calls, ["idle:enter", "idle:exit", "run:enter"], "exit precedes enter")
	assert_eq(transitions.back(), [idle, run], "transition signal reports both states")
	var transition_count: int = transitions.size()
	assert_ok(machine.change_state(run), "same-state transition is a successful no-op")
	assert_eq(calls, ["idle:enter", "idle:exit", "run:enter"], "same-state transition repeats no hooks")
	assert_eq(transitions.size(), transition_count, "same-state transition emits no signal")
	_teardown(machine, parent)
	return


func _test_invalid_transitions_return_errors() -> void:
	var uninitialized: StdFSMachine = StdFSMachine.new()
	var loose: StdFSMState = StdFSMState.new()
	loose.state_name = &"loose"
	assert_err(uninitialized.change_state(loose), "uninitialized transitions return an error")
	uninitialized.free()

	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle", &"run"], calls, parent)
	assert_err(machine.change_state(null), "null transitions return an error")
	assert_err(machine.change_state(loose), "foreign transitions return an error")
	var idle: RecordingState = _state(machine, &"idle")
	idle.next_frame = loose
	expect_warning(
		"state 'loose' is not registered with this StdFSMachine",
		"an invalid state returned by a callback warns",
	)
	machine.process_frame(0.016)
	assert_eq(machine.current_state, idle, "an invalid returned transition preserves current state")
	idle.next_frame = null
	machine.enable(false)
	assert_err(machine.change_state(_state(machine, &"run")), "disabled transitions return an error")
	assert_eq(machine.current_state, _state(machine, &"idle"), "invalid transitions preserve current state")
	var freed: RecordingState = _state(machine, &"run")
	freed.free()
	assert_true(machine.state(&"run").is_none(), "lookup treats a freed registered state as unavailable")
	assert_err(machine.change_state_to(&"run"), "named transition to a freed state returns an error")
	assert_ok(machine.refresh_states(), "refresh safely removes a freed non-current state")
	assert_eq(machine.state_list.size(), 1, "refreshed registry contains only live states")
	loose.free()
	_teardown(machine, parent)
	return


func _test_reentrant_transition_is_rejected() -> void:
	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle", &"run"], calls, parent)
	var idle: RecordingState = _state(machine, &"idle")
	var run: RecordingState = _state(machine, &"run")
	run.enter_transition = idle
	assert_ok(machine.change_state(run), "outer transition succeeds")
	assert_eq(run.transition_results.size(), 1, "enter attempted its nested transition")
	assert_err(run.transition_results[0], "nested lifecycle transition is rejected")
	assert_eq(machine.current_state, run, "nested transition cannot corrupt current state")
	assert_eq(calls, ["idle:enter", "idle:exit", "run:enter"], "nested transition runs no extra hooks")
	_teardown(machine, parent)
	return


func _test_process_methods_forward_and_transition() -> void:
	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle", &"run"], calls, parent)
	var idle: RecordingState = _state(machine, &"idle")
	machine.process_frame(0.016)
	machine.process_physics(0.016)
	machine.process_input(InputEventKey.new())
	assert_eq(
		calls,
		["idle:enter", "idle:frame", "idle:physics", "idle:input"],
		"process methods forward to the current state",
	)
	idle.next_frame = _state(machine, &"run")
	machine.process_frame(0.016)
	assert_true(machine.is_in(&"run"), "a returned state triggers a transition")
	assert_eq(calls.slice(-2), ["idle:exit", "run:enter"], "returned transition runs lifecycle hooks")
	var run: RecordingState = _state(machine, &"run")
	run.next_physics = idle
	machine.process_physics(0.016)
	assert_true(machine.is_in(&"idle"), "a state returned from physics triggers a transition")
	idle.next_input = run
	machine.process_input(InputEventKey.new())
	assert_true(machine.is_in(&"run"), "a state returned from input triggers a transition")
	_teardown(machine, parent)
	return


func _test_engine_callbacks_are_safely_gated() -> void:
	var uninitialized: StdFSMachine = StdFSMachine.new()
	uninitialized._process(0.016)
	uninitialized._physics_process(0.016)
	uninitialized._unhandled_input(InputEventKey.new())
	assert_eq(uninitialized.current_state, null, "callbacks are safe before initialization")
	uninitialized.free()

	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle"], calls, parent)
	calls.clear()
	machine.process_enabled = false
	machine._process(0.016)
	machine._physics_process(0.016)
	machine._unhandled_input(InputEventKey.new())
	assert_eq(calls, ["idle:physics", "idle:input"], "each callback obeys its channel flag")
	calls.clear()
	machine.process_enabled = true
	machine.physics_enabled = false
	machine.input_enabled = false
	machine._process(0.016)
	machine._physics_process(0.016)
	machine._unhandled_input(InputEventKey.new())
	assert_eq(calls, ["idle:frame"], "physics and input flags gate their own callbacks")
	machine.enable(false)
	calls.clear()
	machine._process(0.016)
	machine._physics_process(0.016)
	machine._unhandled_input(InputEventKey.new())
	assert_eq(calls, [], "master disable gates every callback")
	_teardown(machine, parent)
	return


func _test_disable_reenable_balances_lifecycle_and_preserves_flags() -> void:
	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle"], calls, parent)
	machine.process_enabled = false
	machine.physics_enabled = true
	machine.input_enabled = false
	machine.enable(false)
	assert_eq(calls, ["idle:enter", "idle:exit"], "disable exits the active state")
	assert_eq(machine.process_enabled, false, "disable preserves frame preference")
	assert_eq(machine.physics_enabled, true, "disable preserves physics preference")
	assert_eq(machine.input_enabled, false, "disable preserves input preference")
	machine.enable(true)
	assert_eq(calls, ["idle:enter", "idle:exit", "idle:enter"], "re-enable re-enters current state")
	assert_eq(machine.process_enabled, false, "re-enable preserves frame preference")
	assert_eq(machine.physics_enabled, true, "re-enable preserves physics preference")
	assert_eq(machine.input_enabled, false, "re-enable preserves input preference")
	_teardown(machine, parent)
	return


func _test_refresh_is_explicit_and_atomic() -> void:
	var calls: Array[String] = []
	var parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle", &"run"], calls, parent)
	var run: RecordingState = _state(machine, &"run")
	run.state_name = &"sprint"
	assert_true(machine.state(&"run").is_some(), "registry keeps the initialized name before refresh")
	assert_true(machine.state(&"sprint").is_none(), "renamed state is hidden before refresh")
	assert_ok(machine.refresh_states(), "refresh accepts a valid renamed state")
	assert_true(machine.state(&"run").is_none(), "refresh removes the old name")
	assert_eq(machine.state(&"sprint").unwrap(), run, "refresh registers the new name")

	var extra: RecordingState = _add_state(machine, &"extra", calls)
	assert_true(machine.state(&"extra").is_none(), "new children are hidden before refresh")
	assert_ok(machine.refresh_states(), "refresh registers a new child")
	assert_eq(extra.machine, machine, "refresh wires newly registered states")
	assert_eq(extra.target, parent, "refresh wires the target into new states")
	extra.state_name = &"sprint"
	assert_err(machine.refresh_states(), "duplicate refresh is rejected")
	assert_eq(machine.state(&"extra").unwrap(), extra, "failed refresh preserves the old registry")
	extra.state_name = &"extra"

	var idle: RecordingState = _state(machine, &"idle")
	machine.remove_child(idle)
	assert_err(machine.refresh_states(), "refresh cannot remove the current state")
	assert_eq(machine.state(&"idle").unwrap(), idle, "failed current removal preserves registry")
	machine.add_child(idle)
	_teardown(machine, parent)
	return


func _test_refresh_enforces_single_machine_ownership() -> void:
	var source_calls: Array[String] = []
	var source_target: Node = Node.new()
	var source: StdFSMachineInterface = _make_machine(
		[&"idle", &"run"], source_calls, source_target
	)
	var moved: RecordingState = _state(source, &"idle")
	assert_ok(source.change_state_to(&"run"), "source leaves the state that will move")

	var destination_target: Node = Node.new()
	var destination: StdFSMachineInterface = _make_machine(
		[&"base"], [], destination_target
	)
	source.remove_child(moved)
	destination.add_child(moved)
	assert_err(destination.refresh_states(), "a second machine cannot steal a registered state")
	assert_eq(moved.machine, source, "failed adoption preserves the original owner")

	assert_ok(source.refresh_states(), "refreshing the source releases a removed non-current state")
	assert_eq(moved.machine, null, "the source clears ownership when it releases the state")
	assert_eq(moved.target, null, "the source clears the released state's target")
	assert_ok(destination.refresh_states(), "an unowned state can be adopted")
	assert_eq(moved.machine, destination, "successful adoption wires the new owner")
	assert_eq(moved.target, destination_target, "successful adoption wires the new target")

	_teardown(source, source_target)
	_teardown(destination, destination_target)
	return


func _test_retarget_balances_lifecycle_and_updates_states() -> void:
	var calls: Array[String] = []
	var first_parent: Node = Node.new()
	var second_parent: Node = Node.new()
	var machine: StdFSMachineInterface = _make_machine([&"idle", &"run"], calls, first_parent)
	machine.target = second_parent
	assert_eq(calls, ["idle:enter", "idle:exit", "idle:enter"], "target assignment balances lifecycle")
	assert_eq(machine.target, second_parent, "target assignment updates the machine target")
	assert_eq(_state(machine, &"idle").target, second_parent, "target assignment updates current state")
	assert_eq(_state(machine, &"run").target, second_parent, "target assignment updates every state")
	machine.enable(false)
	calls.clear()
	assert_ok(machine.retarget(first_parent), "disabled machines can retarget")
	assert_eq(calls, [], "disabled retarget runs no lifecycle hooks")
	machine.free()
	first_parent.free()
	second_parent.free()
	return


func _test_typed_machine_targets() -> void:
	var calls: Array[String] = []
	var body2d: Node2D = Node2D.new()
	var machine2d: StdFSMachine2D = _make_machine(
		[&"idle"], calls, body2d, StdFSMachine2D.new()
	) as StdFSMachine2D
	assert_eq(machine2d.body, body2d, "StdFSMachine2D exposes its typed target")
	assert_eq(_state(machine2d, &"idle").target, body2d, "typed machine wires state target")
	var state2d: StdFSMState2D = StdFSMState2D.new()
	state2d.state_name = &"typed"
	machine2d.add_child(state2d)
	assert_ok(machine2d.refresh_states(), "2D machine registers a typed state")
	assert_eq(state2d.body, body2d, "StdFSMState2D receives the machine's typed target")
	var plain: Node = Node.new()
	assert_err(machine2d.retarget(plain), "StdFSMachine2D rejects a plain Node retarget")
	expect_warning(
		"StdFSMachine2D target must be a Node2D",
		"invalid target assignment warns because it cannot return a result",
	)
	machine2d.target = plain
	assert_eq(machine2d.target, body2d, "invalid target assignment preserves the machine target")
	assert_eq(state2d.target, body2d, "invalid target assignment preserves every state target")
	plain.free()
	_teardown(machine2d, body2d)

	var body3d: Node3D = Node3D.new()
	var machine3d: StdFSMachine3D = _make_machine(
		[&"idle"], [], body3d, StdFSMachine3D.new()
	) as StdFSMachine3D
	assert_eq(machine3d.body, body3d, "StdFSMachine3D exposes its typed target")
	var state3d: StdFSMState3D = StdFSMState3D.new()
	state3d.state_name = &"typed"
	machine3d.add_child(state3d)
	assert_ok(machine3d.refresh_states(), "3D machine registers a typed state")
	assert_eq(state3d.body, body3d, "StdFSMState3D receives the machine's typed target")
	_teardown(machine3d, body3d)
	return


#region Private Helpers
func _add_state(machine: Node, state_name: StringName, calls: Array[String]) -> RecordingState:
	var state: RecordingState = RecordingState.new()
	state.state_name = state_name
	state.calls = calls
	machine.add_child(state)
	return state


func _make_machine(
	names: Array[StringName],
	calls: Array[String],
	parent: Node,
	machine: StdFSMachineInterface = null,
) -> StdFSMachineInterface:
	var built: StdFSMachineInterface = machine if machine != null else StdFSMachine.new()
	var first: RecordingState
	for state_name: StringName in names:
		var state: RecordingState = _add_state(built, state_name, calls)
		if first == null:
			first = state
		pass
	built.starting_state = first
	var initialized: StdResult = built.init(parent)
	initialized.expect("test helper built an invalid StdFSMachine: %s" % initialized.unwrap_or("unknown error"))
	return built


func _state(machine: StdFSMachineInterface, state_name: StringName) -> RecordingState:
	return machine.state(state_name).unwrap() as RecordingState


func _teardown(machine: Node, parent: Node) -> void:
	machine.free()
	parent.free()
	return
#endregion Private Helpers
