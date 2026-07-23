# StdReturns

[← StdLib](../../../README.md)

Explicit success, failure, presence, and absence values for GDScript.

## Description

StdReturns is the foundation of std-lib. Fallible operations return [`StdResult`](returns/Result.md); possibly
empty queries return [`StdOption`](returns/Option.md). Callers can inspect, transform, compose, or recover from
those states without using a bare `null`, sentinel integer, or ignored engine error.

| Type | States | Use when |
|---|---|---|
| `StdResult` | `OK` / `ERR` | An operation can succeed or fail. |
| `StdOption` | `SOME` / `NONE` | A value may be present or absent. |
| `StdReturn` | Abstract base | Shared storage and fatal invariant handling; do not construct directly. |

## Example usage

```gdscript
func divide(a: float, b: float) -> StdResult:
	if is_zero_approx(b):
		return StdResult.err("division by zero")
	return StdResult.ok(a / b)

var result: StdResult = divide(10.0, 2.0)
if result.is_err():
	push_warning(result.unwrap_err())
	return
var quotient: float = result.unwrap()
```

```gdscript
var target: StdOption = find_target()
target.inspect(func(node: Node) -> void: node.show())
```

## Null and falsy payloads

Tags, not truthiness, define state. All of these remain wrapped values:

```gdscript
StdOption.some(null).is_some() # true
StdOption.some(false).is_some() # true
StdResult.ok(null).is_ok() # true
StdResult.err(null).is_err() # true
```

`some(null)` is distinct from `none()`, and `ok(null)` is distinct from `err(null)`.

## Factories and properties

Use `StdResult.ok()`, `StdResult.err()`, `StdOption.some()`, and `StdOption.none()`. Direct construction requires
an internal tag and is intentionally treated as a programmer invariant. Wrapper fields are
internal-by-convention and are not supported public API. Payload objects can still be mutable because they are
ordinary Variants.

## Callable contracts and laziness

Callables run only on their documented branch. For example, `StdResult.map()` skips its mapper on `ERR`, and
`StdOption.or_else()` skips its fallback on `SOME`. An invalid callable on a skipped branch is never inspected.

GDScript does not encode callable parameter or return signatures. Callers must provide the arguments and return
types documented by each method. `and_then()`, `or_else()`, and `flatten()` explicitly verify their returned or
nested wrapper type.

## Invariant failures

Wrong-side unwraps, invalid direct tags, selected invalid callables, incorrect wrapper return types, invalid
flattening, and null wrapper operands are programmer errors. They assert in editor/debug builds and crash
release builds so a wrong payload can never silently escape.

Use `unwrap_or()`, `unwrap_or_else()`, `get_ok()`, `get_err()`, `ok_or()`, or ordinary state checks when failure or
absence is expected.

## Class reference

- [`StdResult`](returns/Result.md) — success/failure factories, queries, transformations, recovery, and chaining.
- [`StdOption`](returns/Option.md) — presence queries, transformations, alternatives, filtering, and conversion.
- [`StdReturn`](returns/Return.md) — abstract tags and shared extraction contract.

## Testing

```sh
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-returns
```

The suite covers every branch, falsy/null payloads, laziness and identity, subprocess assertions, a forced
release-build crash, invalid callback return types, invalid operands, and deterministic model-based stress chains.

## See also

- [StdCollections](StdCollections.md) — empty `peek()` and `pop()` operations return `StdOption`.
- [StdSignals](StdSignals.md) — signal connection operations return `StdResult`.
