class_name StdFSMachine2D
extends "res://addons/std_lib/std-fsm/machines/state_machine.gd"
## A [code]StdFSMachine[/code] whose controlled node is a [Node2D].
##
## Identical to [code]StdFSMachine[/code] but exposes [member body] as a typed [Node2D].
## Pair with [code]StdFSMState2D[/code] children.


#region Public Members
## The controlled node, typed as [Node2D].
var body: Node2D:
	get: return _target_node as Node2D
#endregion Public Members

#region Private Helpers
func _validate_target(target_node: Node) -> StdResult:
	var valid_target: StdResult = super(target_node)
	if valid_target.is_err():
		return valid_target
	if target_node is not Node2D:
		return StdResult.err("StdFSMachine2D target must be a Node2D")
	return StdResult.ok(target_node)
#endregion Private Helpers
