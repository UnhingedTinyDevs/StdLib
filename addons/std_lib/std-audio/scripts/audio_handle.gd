class_name StdAudioHandle
extends RefCounted
## An opaque handle for one managed [code]StdAudioPlayer[/code] playback.
##
## Stop the playback with [method stop] or pass this handle to
## [code]StdAudioPlayer.stop[/code]. The handle becomes inactive after it is
## stopped, after [code]StdAudioPlayer.stop_all[/code], or when a non-looping
## stream finishes naturally.

## Emitted only when the stream finishes naturally. An explicit
## [method stop] is synchronous and does not emit this signal.

signal finished

var _owner: WeakRef
var _player_id: int
var _active: bool = true


func _init(owner: Node, player_id: int) -> void:
	_owner = weakref(owner)
	_player_id = player_id
	return


#region Public API
## Stops this playback and releases its pool slot. Errs when the
## playback already stopped, finished naturally, or its [code]StdAudioPlayer[/code]
## no longer exists.
func stop() -> StdResult:
	if not is_active(): return StdResult.err("audio playback is no longer active")
	var owner: Variant = _owner.get_ref()
	if owner is not StdAudioPlayer:
		_active = false
		return StdResult.err("audio player is no longer available")
	var rv: StdResult = owner.stop(self)
	return rv


## Returns whether this handle still owns an active pooled playback.
func is_active() -> bool:
	return _active and is_instance_valid(_owner.get_ref())
#endregion Public API


#region StdAudioPlayer API
# StdAudioPlayer is the sole owner of handle lifecycle transitions.
func _invalidate(natural_finish: bool) -> void:
	if not _active: return
	_active = false
	if natural_finish:
		finished.emit()
	return
#endregion StdAudioPlayer API
