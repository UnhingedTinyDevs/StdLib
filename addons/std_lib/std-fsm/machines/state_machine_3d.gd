class_name StdFSMachine3D
extends "res://addons/std_lib/std-fsm/machines/state_machine.gd"
## A [code]StdFSMachine[/code] whose controlled node is a [Node3D].
##
## Identical to [code]StdFSMachine[/code] but exposes [member body] as a typed [Node3D].
## Pair with [code]StdFSMState3D[/code] children.


#region Public Members
## The controlled node, typed as [Node3D].
var body: Node3D:
	get: return _target_node as Node3D
#endregion Public Members

#region Private Helpers
func _validate_target(target_node: Node) -> StdResult:
	var valid_target: StdResult = super(target_node)
	if valid_target.is_err():
		return valid_target
	if target_node is not Node3D:
		return StdResult.err("StdFSMachine3D target must be a Node3D")
	return StdResult.ok(target_node)
#endregion Private Helpers
