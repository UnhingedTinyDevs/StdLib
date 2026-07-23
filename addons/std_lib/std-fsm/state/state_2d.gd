class_name StdFSMState2D
extends "res://addons/std_lib/std-fsm/state/state.gd"
## A [StdFSMState] that controls a [Node2D].
##
## Identical to [StdFSMState] but exposes [member body] as a [Node2D] for
## autocomplete and static typing. Use with [StdFSMachine2D].

#region Public Members
## The controlled node, typed as [Node2D]. Backed by the machine-assigned parent.
var body: Node2D:
	get: return _target as Node2D
#endregion Public Members
