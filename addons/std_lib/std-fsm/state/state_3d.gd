class_name StdFSMState3D
extends "res://addons/std_lib/std-fsm/state/state.gd"
## A [StdFSMState] that controls a [Node3D].
##
## Identical to [StdFSMState] but exposes [member body] as a [Node3D] for
## autocomplete and static typing. Use with [StdFSMachine3D].

#region Public Members
## The controlled node, typed as [Node3D]. Backed by the machine-assigned parent.
var body: Node3D:
	get: return _target as Node3D
#endregion Public Members
