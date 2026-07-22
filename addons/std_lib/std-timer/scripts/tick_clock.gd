class_name StdTickClock
extends Node
## A fixed-tick game clock with adjustable speed
##
## Accumulates frame time and emits [signal ticked] at a fixed rate of
## [member ticks_per_second], so games can step their simulation on
## discrete ticks instead of every frame. Speed can be changed while
## running with [method set_speed].
## The accumulator pump ([method advance]) is public so headless code
## and tests can drive the clock without a running [SceneTree].
## [codeblock]
## var clock: StdTickClock = StdTickClock.new()
## clock.ticked.connect(_on_tick)
## add_child(clock)
## var rv: StdResult = clock.start()
## if rv.is_err(): push_warning(rv.unwrap_err())
## [/codeblock]

## Emitted once per elapsed tick while running. [param tick] is the
## total tick count so far, monotonically increasing until
## [method reset].
signal ticked(tick: int)

## Default tick rate in ticks per second.
const DEFAULT_TICKS_PER_SECOND: float = 4.0
## Most ticks a single [method advance] fires before dropping the rest
## of its accumulated time (guards against runaway loops from huge
## deltas or extreme speeds).
const MAX_TICKS_PER_ADVANCE: int = 240

## Current tick rate in ticks per second. Prefer [method set_speed] at runtime
## because direct assignment does not validate the value.
@export_range(0.1, 60.0, 0.1) var ticks_per_second: float = DEFAULT_TICKS_PER_SECOND
## When true the clock starts itself in [method Node._ready].
@export var autostart: bool = false

var _acc: float = 0.0
var _tick: int = 0
var _running: bool = false


#region Engine Methods
func _ready() -> void:
	set_process(_running)
	if autostart and not _running:
		var _rv: StdResult = start().inspect_err(
				func(e: Variant) -> void: push_warning("StdTickClock autostart failed: %s" % e))
	return


func _process(delta: float) -> void:
	var _fired: int = advance(delta)
	return
#endregion Engine Methods


#region Public API
## Starts the clock from the current tick count. Errs when
## [member ticks_per_second] is not positive or the clock is already
## running. On success the ok value is [code]true[/code].
func start() -> StdResult:
	if not is_finite(ticks_per_second) or ticks_per_second <= 0.0:
		return StdResult.err("ticks_per_second must be finite and positive, got %s" % ticks_per_second)
	if _running:
		return StdResult.err("clock is already running")
	_running = true
	set_process(true)
	return StdResult.ok(true)


## Pauses the clock. The tick count and any partial accumulation are kept;
## [method start] resumes from here.
func pause() -> void:
	_running = false
	set_process(false)
	return


## Stops the clock and zeroes the tick count and accumulator.
func reset() -> void:
	pause()
	_tick = 0
	_acc = 0.0
	return


## True while the clock is running.
func is_running() -> bool:
	return _running


## Total ticks emitted since the last [method reset].
func tick_count() -> int:
	return _tick


## Sets the tick rate. Errs when [param tps] is not positive. Takes
## effect on the next tick. On success the ok value is the new rate.
func set_speed(tps: float) -> StdResult:
	if not is_finite(tps) or tps <= 0.0:
		return StdResult.err("tick rate must be finite and positive, got %s" % tps)
	ticks_per_second = tps
	return StdResult.ok(tps)


## Advances the accumulator by [param delta] seconds and emits
## [signal ticked] once per elapsed tick interval. Returns the number
## of ticks fired (0 when the clock is paused or [param delta] is
## negative). The interval is re-read every iteration, so speed changes
## made inside a tick handler apply to the very next tick; a handler
## calling [method pause] halts the loop immediately. At most
## [constant MAX_TICKS_PER_ADVANCE] ticks fire per call — beyond that
## the remaining accumulated time is dropped with a warning.
## [method _process] delegates here; call it directly to pump the clock
## headless.
## [codeblock]
## var fired: int = clock.advance(0.5)  # 2 ticks at 4 tps
## [/codeblock]
func advance(delta: float) -> int:
	if not _running: return 0
	if not is_finite(delta) or delta < 0.0: return 0
	if not is_finite(ticks_per_second) or ticks_per_second <= 0.0:
		push_warning("StdTickClock paused because ticks_per_second became invalid")
		pause()
		return 0
	
	_acc += delta
	var fired: int = 0
	while _running:
		if not is_finite(ticks_per_second) or ticks_per_second <= 0.0:
			push_warning("StdTickClock paused because ticks_per_second became invalid")
			pause()
			break
		var interval: float = 1.0 / ticks_per_second
		
		#
		if _acc < interval and not is_equal_approx(_acc, interval):
			break
		
		# if we are above the maximum amount of ticks per advanced.
		if fired >= MAX_TICKS_PER_ADVANCE:
			push_warning("StdTickClock dropped %ss of accumulated time after %d ticks in one advance"
					% [_acc, fired])
			_acc = 0.0
			break
		
		_acc = maxf(_acc - interval, 0.0)
		_tick += 1
		fired += 1
		ticked.emit(_tick)
		pass
	
	return fired

#endregion Public API
