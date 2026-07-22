# StdReturn

[← StdReturns](../StdReturns.md)

**Inherits:** `RefCounted`

Abstract storage and invariant handling for `StdResult` and `StdOption`.

## Description

`StdReturn` stores a private tag and payload for its concrete subclasses. It also centralizes callable validation
and fatal invariant behavior. Application code should use `StdResult` or `StdOption`, never instantiate this
abstract class.

## Signals

This class defines no signals.

## Enumerations

### enum Returns

| Value | Description |
|---|---|
| `OK` | A successful `StdResult`. |
| `ERR` | A failed `StdResult`. |
| `SOME` | A present `StdOption`. |
| `NONE` | An absent `StdOption`. |

Tags are internal construction details. Passing a Result tag to Option or an Option tag to Result is a fatal
invariant violation.

## Properties

This class exposes no supported public properties. `_type` and `_value` are internal-by-convention subclass
state.

## Methods

| Return type | Method |
|---|---|
| `Variant` | `expect(msg: String)` abstract |
| `Variant` | `unwrap()` abstract |
| `Variant` | `unwrap_or(default: Variant)` abstract |
| `Variant` | `unwrap_or_else(cb: Callable)` abstract |

## Method descriptions

### `expect(msg: String) -> Variant`

Implemented by each wrapper to extract its success/presence side or fail with `msg` on the opposite side.

### `unwrap() -> Variant`

Implemented by each wrapper to extract its success/presence side or fail with a standard diagnostic.

### `unwrap_or(default: Variant) -> Variant`

Implemented by each wrapper to return its success/presence payload or an eager default.

### `unwrap_or_else(cb: Callable) -> Variant`

Implemented by each wrapper to return its success/presence payload or lazily call a fallback. Result fallbacks
receive the error; Option fallbacks receive no arguments.
