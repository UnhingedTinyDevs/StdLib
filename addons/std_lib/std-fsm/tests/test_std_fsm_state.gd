extends StdTest
## Tests for the std-fsm states.
##
## Proves the concrete state is safe to subclass selectively: every unoverridden
## callback has defined no-op behavior.



func _test_default_state_is_noop() -> void:
	var state: StdFSMState = StdFSMState.new()
	state.enter()
	state.exit()
	assert_eq(state.process_frame(0.1), null, "process_frame defaults to no transition")
	assert_eq(state.process_physics(0.1), null, "process_physics defaults to no transition")
	assert_eq(state.process_input(InputEventKey.new()), null, "process_input defaults to no transition")
	state.free()
	return
