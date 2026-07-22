# StdOption

[← StdReturns](../StdReturns.md)

**Inherits:** `StdReturn` → `RefCounted`

An explicit present or absent value.

## Description

`StdOption` is `SOME(value)` or `NONE`. Use it when absence is expected and is not itself an error. State is
defined by the tag, so `some(null)`, `some(false)`, and `some(0)` are all present.

Transformations create wrappers only when needed. Short-circuited methods return the original instance and do
not validate or call an unused Callable.

## Example usage

```gdscript
func first_enemy() -> StdOption:
	var enemy: Node = get_tree().get_first_node_in_group(&"enemies")
	return StdOption.some(enemy) if enemy != null else StdOption.none()

var enemy: StdOption = first_enemy()
var name: String = enemy.map_or("none", func(node: Node) -> String: return node.name)
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
| `StdOption` | `some(value: Variant)` static |
| `StdOption` | `none()` static |
| `bool` | `is_some()` |
| `bool` | `is_none()` |
| `bool` | `is_some_and(cb: Callable)` |
| `bool` | `is_none_or(cb: Callable)` |
| `StdOption` | `map(cb: Callable)` |
| `Variant` | `map_or(default: Variant, cb: Callable)` |
| `Variant` | `map_or_else(default_cb: Callable, cb: Callable)` |
| `StdOption` | `inspect(cb: Callable)` |
| `StdOption` | `filter(predicate: Callable)` |
| `StdOption` | `and_opt(option: StdOption)` |
| `StdOption` | `and_then(cb: Callable)` |
| `StdOption` | `or_opt(option: StdOption)` |
| `StdOption` | `or_else(cb: Callable)` |
| `StdOption` | `xor_opt(option: StdOption)` |
| `StdOption` | `flatten()` |
| `StdResult` | `ok_or(error: Variant)` |
| `StdResult` | `ok_or_else(cb: Callable)` |
| `Variant` | `expect(msg: String)` |
| `Variant` | `unwrap()` |
| `Variant` | `unwrap_or(default: Variant)` |
| `Variant` | `unwrap_or_else(cb: Callable)` |

## Method descriptions

### `some(value: Variant) -> StdOption` static

Creates a present Option containing `value`, including when `value` is `null` or otherwise falsy.

### `none() -> StdOption` static

Creates an absent Option.

### `is_some() -> bool`, `is_none() -> bool`

Return whether this Option is present or absent.

### `is_some_and(cb: Callable) -> bool`

Returns `true` only for `SOME` whose payload satisfies `cb(value)`. `NONE` returns `false` without inspecting the
callable.

### `is_none_or(cb: Callable) -> bool`

Returns `true` for `NONE`, or the value of `cb(value)` for `SOME`. `NONE` does not inspect the callable.

### `map(cb: Callable) -> StdOption`

Returns `some(cb(value))` for `SOME`. `NONE` returns itself unchanged.

### `map_or(default: Variant, cb: Callable) -> Variant`

Returns `cb(value)` for `SOME`, otherwise the eager `default`.

### `map_or_else(default_cb: Callable, cb: Callable) -> Variant`

Calls `cb(value)` for `SOME` or zero-argument `default_cb()` for `NONE`. Only the selected callable is inspected
or invoked.

### `inspect(cb: Callable) -> StdOption`

Calls `cb(value)` for `SOME` and returns this Option unchanged. `NONE` is a no-op.

### `filter(predicate: Callable) -> StdOption`

Returns this Option when it is `SOME` and accepted, or when it is already `NONE`. A rejected payload returns a
new `NONE`.

### `and_opt(option: StdOption) -> StdOption`

Returns `option` when this Option is `SOME`; otherwise returns this `NONE`. The operand is eager and must be live
and non-null.

### `and_then(cb: Callable) -> StdOption`

For `SOME`, calls `cb(value)`, which must return `StdOption`. `NONE` returns itself without inspecting the
callable.

### `or_opt(option: StdOption) -> StdOption`

Returns this Option when `SOME`; otherwise returns `option`. The operand is eager and must be non-null.

### `or_else(cb: Callable) -> StdOption`

Returns this Option when `SOME`; otherwise calls zero-argument `cb()`, which must return `StdOption`.

### `xor_opt(option: StdOption) -> StdOption`

Returns the one `SOME` when exactly one operand is present. Returns `NONE` when both states match. The operand
must be non-null.

### `flatten() -> StdOption`

Removes one nesting level: `some(some(value))` becomes `some(value)`, `some(none())` becomes `none()`, and outer
`NONE` returns itself. A `SOME` payload that is not `StdOption` is an invariant violation.

### `ok_or(error: Variant) -> StdResult`

Converts `SOME(value)` to `ok(value)` and `NONE` to `err(error)`. The error is eager.

### `ok_or_else(cb: Callable) -> StdResult`

Converts `SOME(value)` to `ok(value)` without inspecting `cb`. For `NONE`, returns `err(cb.call())`.

### `expect(msg: String) -> Variant`

Returns the payload for `SOME`. `NONE` fails with `msg`.

### `unwrap() -> Variant`

Returns the payload for `SOME`. `NONE` fails with a standard diagnostic.

### `unwrap_or(default: Variant) -> Variant`

Returns the payload for `SOME`, otherwise the eager `default`.

### `unwrap_or_else(cb: Callable) -> Variant`

Returns the payload for `SOME` without inspecting `cb`; `NONE` returns zero-argument `cb.call()`.

## Invariant failures

Selected invalid callables, wrong wrapper return types, invalid flattening, null wrapper operands, and
wrong-side extraction assert in debug and crash release builds. If an assertion is manually resumed in the
editor, deterministic fallbacks prevent an opposite-side payload from leaking:

| Method | Resumed-debug fallback |
|---|---|
| Predicates | `false` on a selected invalid callable |
| `map`, `inspect`, `or_else` | Original Option |
| `map_or` | Supplied default |
| `map_or_else`, `unwrap_or_else` | `null` |
| `filter`, `and_then`, invalid `flatten` | `none()` |
| `ok_or_else` | `err(diagnostic)` |
| Invalid eager operands | Method-specific `NONE`/original safe state |

## Testing

```sh
scripts/run-tests -m std-returns
```
