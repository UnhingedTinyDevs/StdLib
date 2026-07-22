# Std Timer

[← StdLib](../StdLib.md)

A fixed-step clock and a countdown measured in those fixed steps.

- `StdTickClock` converts elapsed seconds into simulation ticks.
- `StdTickCountdown` consumes ticks until a duration expires.

```gdscript
var clock: StdTickClock = StdTickClock.new()
var cooldown: StdTickCountdown = StdTickCountdown.new()

clock.ticked.connect(func(_tick: int) -> void:
	if cooldown.tick():
		_weapon_ready()
)
add_child(clock)

var _clock_started: StdResult = clock.start()
var _cooldown_started: StdResult = cooldown.start(20)
```

## Concepts

### Fixed simulation ticks

`StdTickClock` accumulates frame `delta` and emits one `ticked` signal for each
complete tick interval. At 4 ticks per second, `advance(0.5)` emits two ticks.
Partial intervals remain accumulated for the next call.

`stop()` pauses the clock without discarding its tick count or partial interval.
`reset()` stops it and clears both.

### Tick countdowns

`StdTickCountdown` contains no real-time logic. Call `tick()` from a clock signal
or another fixed-step loop. `tick()` returns `true` exactly once, on the step
that reaches zero.

Expiration and cancellation are distinct states. A fresh or cancelled countdown
is not expired; only one that naturally reaches zero is expired.

## API

### `StdTickClock`

A `Node`. Add it to the scene tree for automatic processing, or call `advance()`
directly for a manually driven simulation.

#### `ticked`

```gdscript
signal ticked(tick: int)
```

Emitted once per completed interval. `tick` increases from 1 until `reset()`.

#### Constants

```gdscript
const DEFAULT_TICKS_PER_SECOND: float = 4.0
const MAX_TICKS_PER_ADVANCE: int = 240
```

The maximum prevents one delayed frame from producing an unbounded tick loop.

#### Properties

```gdscript
@export_range(0.1, 60.0, 0.1) var ticks_per_second: float = DEFAULT_TICKS_PER_SECOND
@export var autostart: bool = false
```

`ticks_per_second` controls the current rate. Use `set_speed()` for validated
runtime changes. When `autostart` is `true`, the clock starts in `_ready()`.

#### `start`

```gdscript
func start() -> StdResult
```

Starts or resumes the clock. Returns an error when the rate is invalid or the
clock is already running.

#### `stop`

```gdscript
func stop() -> void
```

Pauses the clock. Its tick count and partial interval are retained.

#### `reset`

```gdscript
func reset() -> void
```

Stops the clock and clears its tick count and accumulated time.

#### `is_running` and `tick_count`

```gdscript
func is_running() -> bool
func tick_count() -> int
```

Return the running state and the number of ticks emitted since the last reset.

#### `set_speed`

```gdscript
func set_speed(tps: float) -> StdResult
```

Sets a finite, positive tick rate. A rate changed from a `ticked` handler applies
to the next interval processed by the same `advance()` call.

#### `advance`

```gdscript
func advance(delta: float) -> int
```

Accumulates `delta` seconds, emits elapsed ticks, and returns how many fired.
Returns 0 while stopped or for a negative or non-finite delta.

At most `MAX_TICKS_PER_ADVANCE` ticks fire in one call. When more are pending,
the clock warns and drops the remaining accumulated time.

```gdscript
var fired: int = clock.advance(0.5) # 2 ticks at 4 TPS
```

### `StdTickCountdown`

A `RefCounted` duration measured only in ticks.

#### `start`

```gdscript
func start(ticks: int) -> StdResult
```

Starts or restarts the countdown. `ticks` must be positive. Restarting clears a
previous expiration.

#### `tick`

```gdscript
func tick() -> bool
```

Consumes one tick while running. Returns `true` only when that tick reaches zero;
later calls return `false` until the countdown is restarted.

#### State queries

```gdscript
func is_running() -> bool
func is_expired() -> bool
func remaining() -> int
```

`is_expired()` is true only after natural completion. `remaining()` is zero for
fresh, cancelled, and expired countdowns.

#### `cancel`

```gdscript
func cancel() -> void
```

Stops the countdown, clears its remaining ticks, and leaves it unexpired.

## Gotchas

### `stop()` and `reset()` are different

Clock `stop()` is a pause. A later `start()` resumes with the existing tick count
and partial interval. Use `reset()` when the next start must begin from zero.

### Direct rate assignment bypasses validation

The exported `ticks_per_second` property remains writable for editor use. Runtime
code should call `set_speed()`. If direct assignment leaves an invalid rate, the
next `advance()` warns and stops the clock.

### The runaway cap drops time

When one `advance()` would exceed 240 ticks, the excess accumulated time is
discarded. This protects the game from a runaway loop; it is not suitable for a
simulation that must process every missed tick regardless of delay.

## Testing

```sh
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- addons/std_lib/std-timer/tests
```

See [StdTests](StdTests.md) for the runner.

## See also

- [StdReturns](StdReturns.md) — the `StdResult` returned by validated operations.
- [StdInput](StdInput.md) — buffered input that can be consumed on fixed ticks.
