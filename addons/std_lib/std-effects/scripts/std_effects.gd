extends Node
## Pooled visual-effect service for sprites, particles, and shaders.
##
## Register reusable [StdEffectRecipe] resources by id or play concrete recipes
## directly. Every successful playback returns a [StdEffectHandle]. Ignore the
## handle for fire-and-forget behavior or retain it for explicit stopping.


## Default number of simultaneous sprite animations.
const DEFAULT_SPRITE_POOL_SIZE: int = 16
## Default number of simultaneous particle bursts.
const DEFAULT_PARTICLE_POOL_SIZE: int = 16

const SpriteEffectPlayer = preload("sprite_effect_player.gd")
const ParticleEffectPlayer = preload("particle_effect_player.gd")
const ShaderEffectPlayer = preload("shader_effect_player.gd")


var _recipes: Dictionary[StringName, StdEffectRecipe] = {}
var _sprites: SpriteEffectPlayer
var _particles: ParticleEffectPlayer
var _shaders: ShaderEffectPlayer


#region Engine Methods
func _init() -> void:
	_sprites = SpriteEffectPlayer.new(self, DEFAULT_SPRITE_POOL_SIZE)
	_particles = ParticleEffectPlayer.new(self, DEFAULT_PARTICLE_POOL_SIZE)
	_shaders = ShaderEffectPlayer.new(self)
	return


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop_all()
	return
#endregion Engine Methods


#region Public API
## Sets the fixed sprite and particle pool capacities. Call before the first
## successful pooled playback. Zero disables that effect type.
func configure_pools(
		sprite_capacity: int = DEFAULT_SPRITE_POOL_SIZE,
		particle_capacity: int = DEFAULT_PARTICLE_POOL_SIZE,
) -> StdResult:
	if _sprites.has_started() or _particles.has_started():
		return StdResult.err("effect pool capacities cannot change after pooled playback starts")
	if sprite_capacity < 0 or particle_capacity < 0:
		return StdResult.err("effect pool capacities cannot be negative")
	_sprites.configure(sprite_capacity)
	_particles.configure(particle_capacity)
	return StdResult.ok(true)


## Validates and registers [param recipe] by [member StdEffectRecipe.id].
## An existing recipe with the same id is replaced.
func register(recipe: StdEffectRecipe) -> StdResult:
	var valid: StdResult = _validate_registration(recipe)
	if valid.is_err(): return valid
	_recipes[recipe.id] = recipe
	return StdResult.ok(recipe)


## Atomically validates and registers every recipe. Existing registry entries
## are replaced. Duplicate ids within [param recipes] return an error.
func register_all(recipes: Array[StdEffectRecipe]) -> StdResult:
	var pending: Dictionary[StringName, StdEffectRecipe] = {}
	for recipe: StdEffectRecipe in recipes:
		var valid: StdResult = _validate_registration(recipe)
		if valid.is_err(): return valid
		if pending.has(recipe.id):
			return StdResult.err("register_all contains duplicate id '%s'" % recipe.id)
		pending[recipe.id] = recipe
		pass
	for id: StringName in pending:
		_recipes[id] = pending[id]
		pass
	return StdResult.ok(pending.size())


## Returns the recipe registered under [param id], or [StdOption] none.
func fetch(id: StringName) -> StdOption:
	var recipe: StdEffectRecipe = _recipes.get(id)
	if recipe == null: return StdOption.none()
	return StdOption.some(recipe)


## Removes and returns the recipe registered under [param id], or
## [StdOption] none.
func revoke(id: StringName) -> StdOption:
	var recipe: StdEffectRecipe = _recipes.get(id)
	if recipe == null: return StdOption.none()
	_recipes.erase(id)
	return StdOption.some(recipe)


## Plays a sprite recipe at [param position]. The ok value is a
## [StdEffectHandle]. Non-looping animations release naturally.
func play_sprite(
		recipe: StdSpriteEffectRecipe,
		position: Vector2 = Vector2.ZERO,
) -> StdResult:
	return _sprites.play(recipe, position)


## Fetches and plays the sprite recipe registered under [param id].
func play_sprite_id(
		id: StringName,
		position: Vector2 = Vector2.ZERO,
) -> StdResult:
	var fetched: StdOption = fetch(id)
	if fetched.is_none():
		return StdResult.err("no effect recipe registered with id '%s'" % id)
	var value: Variant = fetched.unwrap()
	if value is not StdSpriteEffectRecipe:
		return StdResult.err("effect recipe '%s' is not a sprite recipe" % id)
	return _sprites.play(value, position)


## Plays a particle recipe at [param position]. The ok value is a
## [StdEffectHandle], which can be used to stop the burst early.
func play_particles(
		recipe: StdParticleEffectRecipe,
		position: Vector2 = Vector2.ZERO,
) -> StdResult:
	return _particles.play(recipe, position)


## Fetches and plays the particle recipe registered under [param id].
func play_particles_id(
		id: StringName,
		position: Vector2 = Vector2.ZERO,
) -> StdResult:
	var fetched: StdOption = fetch(id)
	if fetched.is_none():
		return StdResult.err("no effect recipe registered with id '%s'" % id)
	var value: Variant = fetched.unwrap()
	if value is not StdParticleEffectRecipe:
		return StdResult.err("effect recipe '%s' is not a particle recipe" % id)
	return _particles.play(value, position)


## Applies a shader recipe to [param target]. The ok value is a
## [StdEffectHandle]. Only one StdEffects shader may own a target at a time.
func play_shader(recipe: StdShaderEffectRecipe, target: CanvasItem) -> StdResult:
	return _shaders.play(recipe, target)


## Fetches and plays the shader recipe registered under [param id].
func play_shader_id(id: StringName, target: CanvasItem) -> StdResult:
	var fetched: StdOption = fetch(id)
	if fetched.is_none():
		return StdResult.err("no effect recipe registered with id '%s'" % id)
	var value: Variant = fetched.unwrap()
	if value is not StdShaderEffectRecipe:
		return StdResult.err("effect recipe '%s' is not a shader recipe" % id)
	return _shaders.play(value, target)


## Stops every active effect and returns the number stopped. Handles are
## invalidated without emitting [signal StdEffectHandle.finished].
func stop_all() -> int:
	var stopped: int = _sprites.stop_all()
	stopped += _particles.stop_all()
	stopped += _shaders.stop_all()
	return stopped
#endregion Public API


#region Private Helpers
func _validate_registration(recipe: StdEffectRecipe) -> StdResult:
	if recipe == null: return StdResult.err("effect recipe is null")
	if recipe.id == &"": return StdResult.err("effect recipe has no id")
	if recipe is StdSpriteEffectRecipe: return _sprites.validate(recipe)
	if recipe is StdParticleEffectRecipe: return _particles.validate(recipe)
	if recipe is StdShaderEffectRecipe: return _shaders.validate(recipe)
	return StdResult.err("unsupported effect recipe type: %s" % recipe)
#endregion Private Helpers
