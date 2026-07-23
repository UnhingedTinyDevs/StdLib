# Std Random

[← StdLib](../../../README.md)

Named deterministic random streams behind one session seed, plus helpers for
common game draws.

```gdscript
StdRandom.set_seed(42)
var combat: StdRandomStream = StdRandom.stream(&"combat")
var loot: StdBag = StdBag.from_array(
	[&"common", &"common", &"rare"],
	StdRandom.stream(&"loot"),
)

if combat.chance(0.35):
	_spawn_bomb()
var drop: StdOption = loot.sample()
```

`StdRandom` is a root autoload registered by the StdRandom subplugin. It owns
the session seed and caches streams by name. `StdRandomStream` extends Godot's
`RandomNumberGenerator`, so it can be passed directly to any API that accepts
one, including `StdBag`.

## Concepts

### Name streams by subsystem

A single shared generator is reproducible, but fragile: one new loot draw shifts
every later spawn, AI, and combat draw. Named streams isolate those sequences.

```gdscript
var loot: StdRandomStream = StdRandom.stream(&"loot")
var spawns: StdRandomStream = StdRandom.stream(&"spawns")
```

Both are derived from the session seed and full stream name. Lookup order does
not matter, and extra `loot` draws do not advance `spawns`. Repeated lookup of
the same name returns the same advancing object.

Use stable names that describe ownership. If two systems use the same name, they
intentionally share a sequence and their draw counts affect each other.

### Pass streams explicitly

Random-accepting std-lib APIs require a generator. Pass the stream that owns the
decision:

```gdscript
var spawn: StdOption = grid.random_free_cell(occupied, StdRandom.stream(&"spawns"))
var pieces: StdBag = StdBag.from_array(tetrominoes, StdRandom.stream(&"pieces"))
var next_piece: StdOption = pieces.sample()
```

There is no `null` fallback that silently creates an entropy-backed generator.

### The edges of `chance` are exact

`chance(0.0)` is always false and `chance(1.0)` always true; neither advances
the stream. Values in between consume one draw. Out-of-range values are clamped
with a warning, and `NAN` warns and returns false without drawing.

## API

### `StdRandom`

```gdscript
func set_seed(value: int) -> void
func randomize_seed() -> void
func get_seed() -> int
func stream(name: StringName) -> StdRandomStream
```

`set_seed` establishes the session seed and restarts every cached stream **in
place**, so references already held by game systems remain valid. `randomize_seed`
chooses a new session seed from entropy and performs the same reset. `get_seed`
returns the session seed, not any stream's derived seed.

`stream` returns the cached stream for its exact name, creating it on first use.
Any `StringName`, including `&""`, is a valid explicit key, though descriptive
non-empty names are easier to audit.

### `StdRandomStream`

`StdRandomStream` inherits Godot's normal generator API:

```gdscript
func randi() -> int
func randf() -> float
func randfn(mean: float = 0.0, deviation: float = 1.0) -> float
func randi_range(from: int, to: int) -> int
func randf_range(from: float, to: float) -> float

var seed: int
var state: int
```

The range methods use Godot's native behavior directly; they do not return
`StdResult`.

It adds these game-oriented helpers:

```gdscript
func gaussian(mean: float = 0.0, deviation: float = 1.0) -> float
func chance(probability: float) -> bool
func pick(items: Array) -> StdOption
func shuffle(items: Array) -> void
func roll(notation: String) -> StdResult
```

- `gaussian` is a descriptive alias for `randfn`.
- `pick` returns a uniformly random element or `none` for an empty array.
- `shuffle` performs an in-place Fisher-Yates shuffle on this stream.
- `roll` accepts dice notation such as `"3d6+2"`, `"d20"`, and `"2d8-1"`.
  It errs on malformed notation or zero dice/sides.

### Saving one stream's position

Godot's `state` property restores an exact point in a stream. Set the session
seed first so each stream has the correct derived seed, then restore its state.

StdSave writes JSON, whose numbers roundtrip as floats. A 64-bit RNG seed or
state can lose precision as a JSON number, so encode both as decimal strings:

```gdscript
var loot: StdRandomStream = StdRandom.stream(&"loot")
var data: Dictionary = {
	"random_seed": str(StdRandom.get_seed()),
	"loot_state": str(loot.state),
}

# After loading:
StdRandom.set_seed(int(data["random_seed"]))
var restored_loot: StdRandomStream = StdRandom.stream(&"loot")
restored_loot.state = int(data["loot_state"])
```

State storage is deliberately per stream; the game decides which subsystem
positions belong in its save format.

## Gotchas

### Godot's global RNG is separate, not unseedable

Godot's global `randi`, `randf_range`, `Array.shuffle`, and similar APIs share a
global RNG, and that RNG can be made reproducible with the global `seed()`
function. It is still a **different stream** from every `StdRandom` named stream.
Using a global draw inside a named subsystem escapes that subsystem's saved state
and isolation. Call methods on the owning `StdRandomStream` instead.

### One stream still shifts after an extra draw

Names isolate subsystems, not draws within a subsystem. Adding or removing a
draw from `&"loot"` changes later `&"loot"` results. Split responsibilities into
more specific stable names when they must evolve independently.

### Streams are mutable references

`stream()` returns the actual cached generator because other APIs require one.
Calling `randomize()` or assigning its `seed` detaches that object from the
session-derived sequence until the next `StdRandom.set_seed`. Assign `state` only
to restore a value previously read from that same derived stream.

### Reproducibility is version-bound

Godot documents its underlying PRNG algorithm as an implementation detail. Do
not promise identical sequences after an engine upgrade without replay tests.

### Shared streams are not a threading primitive

Do not draw from the same stream concurrently. Use separate stable stream names
for independent worker responsibilities, and keep any gameplay-relevant ordering
deterministic.

### The service is available with the plugin

The StdLib plugin registers the `StdRandom` autoload. In a project where the
plugin is not enabled, that service does not resolve.

## Testing

```
godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-random
```

See [StdTests](StdTests.md) for the runner.

## See also

- [StdReturns](StdReturns.md) — the `StdResult` and `StdOption` values used here.
- [StdCollections](StdCollections.md) — `StdBag` for occurrence-weighted random sampling and removal.
- [StdGrid](StdGrid.md) — random-cell APIs that require an owning stream.
