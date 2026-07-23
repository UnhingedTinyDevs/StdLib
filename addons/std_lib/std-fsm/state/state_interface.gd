@abstract
class_name StdFSMStateInterface
extends Node
## Contract every state must fulfill.
##
## A state belongs to a [StdFSMachineInterface] and controls a [member target] node.
## The dimensional variants [StdFSMState2D] and [StdFSMState3D] expose a typed
## accessor for that node; the base [StdFSMState] keeps it as a plain [Node].


#region Exports
## Key this state is registered under in the machine.
@export var state_name: StringName
#endregion Exports

#region Public Members
## The machine this state belongs to. Assigned by the machine during initialization.
var machine: StdFSMachineInterface:
	get: return _machine

## The node this state controls. Assigned by the machine during initialization.
var target: Node:
	get: return _target
#endregion Public Members

#region Private Members
var _machine: StdFSMachineInterface
var _target: Node
#endregion Private Members

#region Abstract API
## Runs immediately when this state is entered.
@abstract func enter() -> void
## Runs right before this state is exited.
@abstract func exit() -> void
## Handles the state's input logic. Return the next [StdFSMState] to transition, or null.
@abstract func process_input(event: InputEvent) -> StdFSMState
## Runs every frame. Return the next [StdFSMState] to transition, or null.
@abstract func process_frame(delta: float) -> StdFSMState
## Runs every physics step. Return the next [StdFSMState] to transition, or null.
@abstract func process_physics(delta: float) -> StdFSMState
#endregion Abstract API
