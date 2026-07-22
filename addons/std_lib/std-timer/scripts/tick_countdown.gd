class_name StdTickCountdown
extends RefCounted
## A countdown measured in simulation ticks
##
## Counts a fixed number of ticks and reports the exact tick it
## expires on — despawn timers, buffs, cooldowns for any game stepped
## by a [code]StdTickClock[/code]. Pure state, no nodes; drive it from your tick
## handler.
## [codeblock]
## var bomb_timer: StdTickCountdown = StdTickCountdown.new()
## var _rv: StdResult = bomb_timer.start(20)
## # each simulation tick:
## if bomb_timer.tick():
## 	_despawn_bomb()
## [/codeblock]


var _remaining: int = 0
var _running: bool = false
var _expired: bool = false


#region Public API
## Starts (or restarts) the countdown at [param ticks]. Errs when
## [param ticks] is not positive. On success the ok value is the tick
## count.
func start(ticks: int) -> StdResult:
	if ticks <= 0:
		return StdResult.err("countdown ticks must be positive, got %d" % ticks)
	_remaining = ticks
	_running = true
	_expired = false
	return StdResult.ok(ticks)


## Advances one tick. Returns [code]true[/code] only on the expiring
## tick — the one that takes the countdown to zero; idle and
## already-expired ticks return [code]false[/code].
func tick() -> bool:
	if not _running:
		return false
	_remaining -= 1
	if _remaining <= 0:
		_remaining = 0
		_running = false
		_expired = true
		return true
	return false


## True while the countdown is mid-count.
func is_running() -> bool:
	return _running


## Returns [code]true[/code] only after the countdown reaches zero naturally.
## A fresh, running, or cancelled countdown returns [code]false[/code].
func is_expired() -> bool:
	return _expired


## Ticks left; 0 when idle, cancelled, or expired.
func remaining() -> int:
	return _remaining


## Cancels the countdown and clears its remaining ticks without expiring it.
func cancel() -> void:
	_running = false
	_remaining = 0
	_expired = false
	return
#endregion Public API
