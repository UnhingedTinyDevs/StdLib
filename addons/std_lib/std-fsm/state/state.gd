class_name StdFSMState
extends "res://addons/std_lib/std-fsm/state/state_interface.gd"
## Basic concrete state with empty default behavior.
##
## Override the methods you need. [method enter] and [method exit] default to
## no-ops; the [code]process_*[/code] methods default to returning [code]null[/code]
## (no transition). Use [member StdFSMStateInterface.target] for the controlled
## node, or [StdFSMState2D]/[StdFSMState3D] when you want a typed body accessor.


#region Public API
## What happens immediately when a state is entered.
func enter() -> void:
	return


## What happens right before a state is exited.
func exit() -> void:
	return


## Handles the state's input logic. Return the next [StdFSMState] to transition, or null.
func process_input(_event: InputEvent) -> StdFSMState:
	return null


## Runs every frame. Return the next [StdFSMState] to transition, or null.
func process_frame(_delta: float) -> StdFSMState:
	return null


## Runs every physics step. Return the next [StdFSMState] to transition, or null.
func process_physics(_delta: float) -> StdFSMState:
	return null
#endregion Public API
