class_name StdFSMachine
extends "res://addons/std_lib/std-fsm/machines/state_machine_interface.gd"
## Default state machine for plain [Node] owners.
##
## Implements the standard dispatch policy: forward each callback to the current
## state and transition to whatever [StdFSMState] it returns. The machine drives
## itself (see [StdFSMachineInterface]); the controlled node defaults to its
## parent or [member StdFSMachineInterface.target]. For dimension-specific
## accessors, use [StdFSMachine2D] or [StdFSMachine3D].


#region Public API
## Forwards a frame to the current state and transitions if it returns a state.
func process_frame(delta: float) -> void:
	if current_state == null:
		return
	var new_state: StdFSMState = current_state.process_frame(delta)
	if new_state:
		var _result: StdResult = change_state(new_state).warn("StdFSMachine")
	return


## Forwards a physics step to the current state and transitions if it returns a state.
func process_physics(delta: float) -> void:
	if current_state == null:
		return
	var new_state: StdFSMState = current_state.process_physics(delta)
	if new_state:
		var _result: StdResult = change_state(new_state).warn("StdFSMachine")
	return


## Forwards input to the current state and transitions if it returns a state.
func process_input(event: InputEvent) -> void:
	if current_state == null:
		return
	var new_state: StdFSMState = current_state.process_input(event)
	if new_state:
		var _result: StdResult = change_state(new_state).warn("StdFSMachine")
	return
#endregion Public API
