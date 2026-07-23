# Std Audio

[← StdLib](../StdLib.md)

`StdAudio` is a pooled audio autoload for global, 2D, and 3D streams. Recipes
hold reusable stream configuration; playback calls provide transient positions
and return handles.

```gdscript
var result: StdResult = StdAudio.play_2d_id(&"sfx_hit", enemy.global_position)
if result.is_err():
	push_warning(result.unwrap_err())
```

The StdAudio subplugin registers the root `StdAudio` autoload. Keep the returned
`StdAudioHandle` when a sound needs explicit stopping, or ignore it for
fire-and-forget playback. Non-looping streams release their pool slots
automatically; looping streams remain active until explicitly stopped.

## Recipes

### `StdAudioRecipe`

A global audio recipe:

```gdscript
@export var id: StringName
@export var stream: AudioStream
@export var bus: StringName = &"Master"
@export var volume_db: float = 0.0
```

An id is required for registration but not direct playback. A stream and an
existing, non-empty bus are always required. `volume_db` is passed directly to
Godot's stream player and must be finite.

### `StdAudioRecipe2D`

Extends `StdAudioRecipe` with:

```gdscript
@export var max_distance: float = 1000.0
```

Call `play_2d` or `play_2d_id` with a position. `max_distance` must be finite
and greater than zero.

### `StdAudioRecipe3D`

Extends `StdAudioRecipe` with the same positive `max_distance` property. Call
`play_3d` or `play_3d_id` with a 3D position.

Positions are playback state, not recipe state. One registered recipe can
therefore play at any number of locations without being copied or mutated.

## Registry

```gdscript
func register(recipe: StdAudioRecipe) -> StdResult
func register_all(recipes: Array[StdAudioRecipe]) -> StdResult
func fetch(id: StringName) -> StdOption
func revoke(id: StringName) -> StdOption
```

`register` validates and stores a recipe, replacing an existing recipe with
the same id. Its ok value is the recipe.

`register_all` validates the whole input before changing the registry. Existing
registry entries are replaced, duplicate ids inside the input err, and its ok
value is the number stored. A null recipe, empty id, or invalid recipe leaves
the registry unchanged.

`fetch` and `revoke` return `StdOption.none()` when the id is absent.

Register reusable recipes before calling an `_id` playback method:

```gdscript
var recipe: StdAudioRecipe = preload("res://audio/sfx_hit.tres")
var registered: StdResult = StdAudio.register(recipe)
if registered.is_err():
	push_warning(registered.unwrap_err())
```

## Playback

Every successful playback returns a `StdAudioHandle` as the `StdResult` ok
value. Direct playback does not require a recipe id or registry entry.

### Global

```gdscript
func play(recipe: StdAudioRecipe) -> StdResult
func play_id(id: StringName) -> StdResult
```

These methods reject positional recipes. Use their dimension-specific
counterparts instead.

### 2D

```gdscript
func play_2d(recipe: StdAudioRecipe2D, position: Vector2) -> StdResult
func play_2d_id(id: StringName, position: Vector2) -> StdResult
```

### 3D

```gdscript
func play_3d(recipe: StdAudioRecipe3D, position: Vector3) -> StdResult
func play_3d_id(id: StringName, position: Vector3) -> StdResult
```

Playback errs when:

- `StdAudio` is not inside the scene tree.
- The recipe, stream, bus, position, or numeric configuration is invalid.
- The recipe type does not match the playback method.
- An id is not registered.
- The selected pool is exhausted.

## Handles and stopping

```gdscript
signal finished

func stop() -> StdResult
func is_active() -> bool
```

`finished` is emitted only when playback ends naturally. `stop()` is
synchronous, releases the pool slot, and does not emit `finished`.
After either kind of completion, `is_active()` returns `false` and another
`stop()` call errs.

```gdscript
var music: StdResult = StdAudio.play_id(&"music")
if music.is_ok():
	var handle: StdAudioHandle = music.unwrap()
	var _stopped: StdResult = handle.stop()
```

Stopping all playback:

```gdscript
func stop_all() -> int
```

The return value is the number stopped. All affected handles become inactive
without emitting `finished`.

## Pool configuration

```gdscript
const DEFAULT_GLOBAL_POOL_SIZE: int = 16
const DEFAULT_2D_POOL_SIZE: int = 32
const DEFAULT_3D_POOL_SIZE: int = 32

func configure_pools(
	global_capacity: int = 16,
	capacity_2d: int = 32,
	capacity_3d: int = 32,
) -> StdResult
```

Call `configure_pools` before the first successful playback. Capacities must
be non-negative; zero disables that category. Capacities remain fixed after
playback begins. Invalid playback attempts do not lock the configuration.


## See also

- [StdReturns](StdReturns.md) — `StdResult` and `StdOption`.
- [StdCollections](StdCollections.md) — the underlying object pools.
