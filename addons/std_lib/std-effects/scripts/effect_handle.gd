class_name StdEffectHandle
extends RefCounted
## An opaque handle for one [code]StdEffects[/code] playback.
##
## The handle becomes inactive after [method stop], [code]StdEffects.stop_all[/code],
## or natural completion.

## Emitted only when the effect finishes naturally. An explicit
## [method stop] is synchronous and does not emit this signal.

signal finished

var _owner: WeakRef
var _playback_id: int
var _active: bool = true


func _init(owner: Object, playback_id: int) -> void:
	_owner = weakref(owner)
	_playback_id = playback_id
	return


#region Public API
## Stops this effect and releases its pool slot. Errs when the effect
## already stopped, finished naturally, or [code]StdEffects[/code] no longer
## exists.
func stop() -> StdResult:
	if not is_active(): return StdResult.err("effect playback is no longer active")
	var owner: Variant = _owner.get_ref()
	if owner is not Object or not owner.has_method(&"_stop_from_handle"):
		_active = false
		return StdResult.err("effect playback owner is no longer available")
	var result: Variant = owner.call(&"_stop_from_handle", self)
	if result is StdResult: return result
	_active = false
	return StdResult.err("effect playback owner returned an invalid stop result")


## Returns whether this handle still owns an active pooled effect.
func is_active() -> bool:
	return _active and is_instance_valid(_owner.get_ref())
#endregion Public API


#region Effect Player API
# The internal player that created the handle owns lifecycle transitions.
func _invalidate(natural_finish: bool) -> void:
	if not _active: return
	_active = false
	if natural_finish:
		finished.emit()
	return
#endregion Effect Player API
