# Std Effects

[← StdLib](../StdLib.md)

`StdEffects` is a pooled visual-effect autoload for sprite animations, particle
bursts, and temporary shader effects. Recipes hold reusable configuration;
playback calls provide transient positions or targets and return handles.

```gdscript
var result: StdResult = StdEffects.play_particles_id(
		&"fx_explosion",
		enemy.global_position,
)
if result.is_err():
	push_warning(result.unwrap_err())
```

Keep the returned `StdEffectHandle` when an effect needs explicit stopping, or
ignore it for fire-and-forget playback. Non-looping sprites, particle bursts,
and shaders release themselves naturally. Looping sprites remain active until
explicitly stopped.

## Architecture

`StdEffects` is the only public service. It owns the recipe registry and routes
each concrete playback call to one private implementation:

- `sprite_effect_player.gd` owns sprite validation, pooling, and completion.
- `particle_effect_player.gd` owns particle validation, pooling, and completion.
- `shader_effect_player.gd` owns tweens, target ownership, and material cleanup.

These implementation scripts have no `class_name` and are not part of the
public API. Each `StdEffectHandle` stops through the private player that created
it, while `StdEffects.stop_all()` coordinates all three players.

## Recipes

Every recipe extends `StdEffectRecipe`:

```gdscript
@export var id: StringName
```

An id is required for registration but not for direct playback.

### `StdSpriteEffectRecipe`

```gdscript
@export var frames: SpriteFrames
@export var animation: StringName = &"default"
@export_range(0.1, 10.0, 0.1) var speed_scale: float = 1.0
@export var scale: Vector2 = Vector2.ONE
@export var modulate: Color = Color.WHITE
@export var z_index: int = 100
```

`frames` must contain the selected animation with at least one frame. Both the
animation speed and `speed_scale` must be finite and positive.

### `StdParticleEffectRecipe`

```gdscript
@export var process_material: Material
@export var texture: Texture2D
@export_range(1, 512) var amount: int = 24
@export_range(0.05, 10.0, 0.05) var lifetime: float = 0.6
@export_range(0.0, 1.0, 0.05) var explosiveness: float = 1.0
@export var modulate: Color = Color.WHITE
@export var z_index: int = 100
```

The process material is required; the texture is optional. Amount and lifetime
must be positive, and explosiveness must be finite and between zero and one.

### `StdShaderEffectRecipe`

```gdscript
@export var shader: Shader
@export var params: Dictionary[StringName, Variant] = {}
@export var tween_param: StringName = &"progress"
@export var tween_from: float = 0.0
@export var tween_to: float = 1.0
@export_range(0.01, 30.0, 0.01) var duration: float = 0.4
```

The shader and tween parameter are required. Tween values must be finite, and
duration must be finite and positive.

## Registry

```gdscript
func register(recipe: StdEffectRecipe) -> StdResult
func register_all(recipes: Array[StdEffectRecipe]) -> StdResult
func fetch(id: StringName) -> StdOption
func revoke(id: StringName) -> StdOption
```

`register` validates and stores a recipe, replacing an existing recipe with the
same id. Its ok value is the registered recipe.

`register_all` validates its entire input before changing the registry. Existing
registry entries are replaced, duplicate ids inside the input return an error,
and the ok value is the number stored.

`fetch` and `revoke` return `StdOption.none()` when the id is absent.

```gdscript
const EFFECTS: Array[StdEffectRecipe] = [
	preload("res://effects/hitSpark.tres"),
	preload("res://effects/hitFlash.tres"),
]

func _ready() -> void:
	var registered: StdResult = StdEffects.register_all(EFFECTS)
	if registered.is_err():
		push_warning(registered.unwrap_err())
```

## Playback

Every successful playback returns a `StdEffectHandle`.

### Sprites

```gdscript
func play_sprite(
	recipe: StdSpriteEffectRecipe,
	position: Vector2 = Vector2.ZERO,
) -> StdResult

func play_sprite_id(
	id: StringName,
	position: Vector2 = Vector2.ZERO,
) -> StdResult
```

Non-looping animations release naturally. A looping animation stays active until
its handle is stopped or `stop_all()` is called.

### Particles

```gdscript
func play_particles(
	recipe: StdParticleEffectRecipe,
	position: Vector2 = Vector2.ZERO,
) -> StdResult

func play_particles_id(
	id: StringName,
	position: Vector2 = Vector2.ZERO,
) -> StdResult
```

Particle effects release when their emitter finishes. Retaining the handle
allows a burst to be stopped early.

### Shaders

```gdscript
func play_shader(
	recipe: StdShaderEffectRecipe,
	target: CanvasItem,
) -> StdResult

func play_shader_id(
	id: StringName,
	target: CanvasItem,
) -> StdResult
```

A shader effect saves the target's material, applies a `ShaderMaterial`, and
restores the saved material when the effect finishes or stops.

Only one `StdEffects` shader may own a target at a time. Restoration occurs only
when the target still owns the material applied by `StdEffects`; a newer
material assigned by game code is preserved.

Playback returns an error when:

- `StdEffects` is outside the scene tree.
- A recipe, position, target, or required asset is invalid.
- An `_id` method finds no recipe or the wrong recipe type.
- A sprite or particle pool is exhausted.
- A target already has an active `StdEffects` shader.

## Handles and stopping

```gdscript
signal finished

func stop() -> StdResult
func is_active() -> bool
```

`finished` emits only when playback completes naturally. `stop()` is
synchronous and does not emit `finished`. After either kind of completion,
`is_active()` returns `false`, and another `stop()` call returns an error.

```gdscript
var aura: StdResult = StdEffects.play_sprite_id(&"fx_aura", global_position)
if aura.is_ok():
	var handle: StdEffectHandle = aura.unwrap()
	var stopped: StdResult = handle.stop()
	if stopped.is_err():
		push_warning(stopped.unwrap_err())
```

Stopping all effects:

```gdscript
func stop_all() -> int
```

The return value is the number stopped. All affected handles become inactive
without emitting `finished`.

## Pool configuration

```gdscript
const DEFAULT_SPRITE_POOL_SIZE: int = 16
const DEFAULT_PARTICLE_POOL_SIZE: int = 16

func configure_pools(
	sprite_capacity: int = 16,
	particle_capacity: int = 16,
) -> StdResult
```

Call `configure_pools` before the first successful sprite or particle playback.
Capacities must be non-negative; zero disables that effect type. Invalid or
exhausted playback attempts do not lock configuration.

Shaders do not use a wrapper-node pool. Godot owns their tween, while
`StdEffects` retains only the material state needed for restoration.

## Testing

```sh
godot --headless \
	-s addons/std_lib/std-tests/scripts/std_test_runner.gd \
	--path . -- addons/std_lib/std-effects
```

## See also

- [StdReturns](StdReturns.md) — `StdResult` and `StdOption`.
- [StdCollections](StdCollections.md) — the sprite and particle object pools.
- [StdNode](StdNode.md) — shader-target liveness checks.
- [StdAudio](StdAudio.md) — the matching pooled playback and handle design.
