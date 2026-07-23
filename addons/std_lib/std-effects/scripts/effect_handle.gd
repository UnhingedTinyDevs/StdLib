class_name StdEffectHandle
extends RefCounted
## An opaque handle for one managed [code]StdEffectPlayer[/code] playback.
##
## Stop the effect with [method stop] or pass this handle to
## [code]StdEffectPlayer.stop[/code]. The handle becomes inactive after it is
## stopped, after [code]StdEffectPlayer.stop_all[/code], or when the effect
## finishes naturally.

## Emitted only when the effect finishes naturally. An explicit
## [method stop] is synchronous and does not emit this signal.

signal finished

var _owner: WeakRef
var _node_id: int
var _active: bool = true


func _init(owner: Node, node_id: int) -> void:
	_owner = weakref(owner)
	_node_id = node_id
	return


#region Public API
## Stops this effect and releases its pool slot. Errs when the effect
## already stopped, finished naturally, or its [code]StdEffectPlayer[/code] no
## longer exists.
func stop() -> StdResult:
	if not is_active(): return StdResult.err("effect playback is no longer active")
	var owner: Variant = _owner.get_ref()
	if owner is not StdEffectPlayer:
		_active = false
		return StdResult.err("effect player is no longer available")
	return owner.stop(self)


## Returns whether this handle still owns an active pooled effect.
func is_active() -> bool:
	return _active and is_instance_valid(_owner.get_ref())
#endregion Public API


#region StdEffectPlayer API
# StdEffectPlayer is the sole owner of handle lifecycle transitions.
func _invalidate(natural_finish: bool) -> void:
	if not _active: return
	_active = false
	if natural_finish:
		finished.emit()
	return
#endregion StdEffectPlayer API
