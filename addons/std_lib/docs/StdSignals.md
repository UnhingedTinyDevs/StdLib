# Std Signals

[← StdLib](../StdLib.md)

`StdSignals` provides three idempotent wrappers around Godot signal connections.
Each method returns a `StdResult`:

- `ok(true)` — the connection was added or removed.
- `ok(false)` — the requested state already existed.
- `err(message)` — an endpoint was invalid or Godot rejected the connection.

`StdSignals` is a static utility class and should not be instantiated.
The `_sig` suffix distinguishes its connection helpers from the native
`Object.connect` and `Object.disconnect` methods inherited by every GDScript
class. Godot does not allow those inherited names to be exposed as these static
methods. `connect_once` does not conflict with a native method and therefore
does not need the suffix.

## `connect_sig`

```gdscript
static func connect_sig(sig: Signal, cb: Callable, flags: int = 0) -> StdResult
```

Connects the callback when it is not already connected. Flags are passed
directly to Godot when creating a connection. An existing connection returns
`ok(false)` and is left unchanged, even when it was created with different
flags.

```gdscript
var result: StdResult = StdSignals.connect_sig(button.pressed, _on_pressed)
```

## `disconnect_sig`

```gdscript
static func disconnect_sig(sig: Signal, cb: Callable) -> StdResult
```

Disconnects the callback when it is connected. A missing connection returns
`ok(false)`.

```gdscript
var result: StdResult = StdSignals.disconnect_sig(button.pressed, _on_pressed)
```

## `connect_once`

```gdscript
static func connect_once(
	sig: Signal,
	cb: Callable,
	flags: int = 0,
) -> StdResult
```

Calls `connect_sig` with `Object.CONNECT_ONE_SHOT` added to the supplied flags. An
existing connection is left unchanged; `connect_once` does not replace an
ordinary connection with a one-shot connection.

```gdscript
var result: StdResult = StdSignals.connect_once(animation.finished, _advance)
```

## Gotchas

Godot accepts some callback signature mismatches when connecting and reports
them only when the signal emits. Use typed callbacks with parameters matching
the signal.

Disconnecting requires the same callable used to connect. Store a lambda in a
variable when it must later be disconnected.

## See also

- [StdReturns](StdReturns.md) — the `StdResult` returned by each operation.
- [StdTests](StdTests.md) — the test framework used by StdLib.
