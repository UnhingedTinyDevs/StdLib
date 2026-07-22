# StdResult

[← StdReturns](../StdReturns.md)

**Inherits:** `StdReturn` → `RefCounted`

An explicit success or failure value.

## Description

`StdResult` is `OK(value)` or `ERR(error)`. The error may be any Variant, though descriptive strings are the
std-lib convention. Use state queries and recoverable extractors for expected failures; reserve `unwrap()` and
`expect()` for invariants that must hold.

Short-circuited combinators return the original instance and do not validate or call an unused Callable.

## Example usage

```gdscript
var result: StdResult = load_profile()
if result.is_err():
	push_warning(result.unwrap_err())
	return
var profile: Dictionary = result.unwrap() as Dictionary
```

## Signals

This class defines no signals.

## Enumerations

This class inherits `StdReturn.Returns`; callers do not set tags directly.

## Properties

This class exposes no public properties.

## Methods

| Return type | Method |
|---|---|
| `StdResult` | `ok(value: Variant)` static |
| `StdResult` | `err(error: Variant)` static |
| `StdResult` | `not_implemented()` static |
| `bool` | `is_ok()` |
| `bool` | `is_err()` |
| `bool` | `is_ok_and(cb: Callable)` |
| `bool` | `is_err_and(cb: Callable)` |
| `Variant` | `expect(msg: String)` |
| `Variant` | `unwrap()` |
| `Variant` | `unwrap_or(default: Variant)` |
| `Variant` | `unwrap_or_else(cb: Callable)` |
| `Variant` | `unwrap_err()` |
| `Variant` | `expect_err(msg: String)` |
| `StdOption` | `get_ok()` |
| `StdOption` | `get_err()` |
| `StdResult` | `map(cb: Callable)` |
| `Variant` | `map_or(default: Variant, cb: Callable)` |
| `Variant` | `map_or_else(default_cb: Callable, cb: Callable)` |
| `StdResult` | `inspect(cb: Callable)` |
| `StdResult` | `map_err(cb: Callable)` |
| `StdResult` | `inspect_err(cb: Callable)` |
| `StdResult` | `warn(prefix: String = "")` |
| `StdResult` | `and_res(res: StdResult)` |
| `StdResult` | `and_then(cb: Callable)` |
| `StdResult` | `or_res(res: StdResult)` |
| `StdResult` | `or_else(cb: Callable)` |
| `StdResult` | `flatten()` |

## Method descriptions

### `ok(value: Variant) -> StdResult` static

Creates a successful Result containing `value`, including when it is `null` or otherwise falsy.

### `err(error: Variant) -> StdResult` static

Creates a failed Result containing any Variant error, including `null`.

### `not_implemented() -> StdResult` static

Returns `err("Method not implemented.")` with a stable diagnostic.

### `is_ok() -> bool`, `is_err() -> bool`

Return whether this Result is successful or failed.

### `is_ok_and(cb: Callable) -> bool`

Returns `true` only for `OK` whose payload satisfies `cb(value)`. `ERR` returns `false` without inspecting the
callable.

### `is_err_and(cb: Callable) -> bool`

Returns `true` only for `ERR` whose error satisfies `cb(error)`. `OK` returns `false` without inspecting the
callable.

### `expect(msg: String) -> Variant`

Returns the payload for `OK`. `ERR` fails with `msg`.

### `unwrap() -> Variant`

Returns the payload for `OK`. `ERR` fails with a diagnostic that includes the error.

### `unwrap_or(default: Variant) -> Variant`

Returns the payload for `OK`, otherwise the eager `default`.

### `unwrap_or_else(cb: Callable) -> Variant`

Returns the payload for `OK` without inspecting `cb`; `ERR` returns `cb.call(error)`.

### `unwrap_err() -> Variant`

Returns the error for `ERR`. `OK` is an invariant failure.

### `expect_err(msg: String) -> Variant`

Returns the error for `ERR`. `OK` fails with `msg`.

### `get_ok() -> StdOption`, `get_err() -> StdOption`

Project one side into Option. `get_ok()` returns `some(value)` for `OK`; `get_err()` returns `some(error)` for
`ERR`. The opposite side becomes `none()`. Null payloads remain `some(null)`.

### `map(cb: Callable) -> StdResult`

Returns `ok(cb(value))` for `OK`. `ERR` returns itself unchanged.

### `map_or(default: Variant, cb: Callable) -> Variant`

Returns `cb(value)` for `OK`, otherwise the eager `default`.

### `map_or_else(default_cb: Callable, cb: Callable) -> Variant`

Calls `cb(value)` for `OK` or `default_cb(error)` for `ERR`. Only the selected Callable is inspected or invoked.

### `inspect(cb: Callable) -> StdResult`

Calls `cb(value)` for `OK` and returns this Result unchanged. `ERR` is a no-op.

### `map_err(cb: Callable) -> StdResult`

Returns `err(cb(error))` for `ERR`. `OK` returns itself unchanged.

### `inspect_err(cb: Callable) -> StdResult`

Calls `cb(error)` for `ERR` and returns this Result unchanged. `OK` is a no-op.

### `warn(prefix: String = "") -> StdResult`

Logs an `ERR` through `push_warning()` and returns this Result unchanged. A non-empty prefix is formatted as
`"prefix: error"`. `OK` passes through silently. Use this for failures worth reporting but not handling.

### `and_res(res: StdResult) -> StdResult`

Returns eager `res` for `OK`; `ERR` returns itself. The operand must be non-null.

### `and_then(cb: Callable) -> StdResult`

For `OK`, calls `cb(value)`, which must return `StdResult`. `ERR` returns itself without inspecting the callable.

### `or_res(res: StdResult) -> StdResult`

Returns this Result for `OK`; `ERR` returns eager `res`. The operand must be non-null.

### `or_else(cb: Callable) -> StdResult`

Returns this Result for `OK`; for `ERR`, calls `cb(error)`, which must return `StdResult`.

### `flatten() -> StdResult`

Removes one nesting level: `ok(ok(value))` becomes `ok(value)`, `ok(err(error))` becomes `err(error)`, and outer
`ERR` returns itself. An `OK` payload that is not `StdResult` is an invariant violation.

## Invariant failures

Selected invalid callables, wrong wrapper return types, invalid flattening, null wrapper operands, and
wrong-side extraction assert in debug and crash release builds. If an assertion is manually resumed in the
editor, deterministic fallbacks prevent an opposite-side payload from leaking:

| Method | Resumed-debug fallback |
|---|---|
| Predicates | `false` on a selected invalid callable |
| `map`, `inspect`, `map_err`, `inspect_err`, `or_else` | Original Result |
| `map_or` | Supplied default |
| `map_or_else`, `unwrap_or_else`, wrong-side extraction | `null` |
| Invalid `and_then`, `and_res`, or `flatten` | `err(diagnostic)` |
| Invalid `or_res` | Original Result |

## Testing

```sh
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-returns
```
