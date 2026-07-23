class_name StdEffectPlayer
extends Node
## Pooled playback engine for [code]StdEffectRecipeInterface[/code]s.
##
## Owns private pools of [AnimatedSprite2D]s, [GPUParticles2D]s, and
## shader runners. Managed playback returns an opaque [code]StdEffectHandle[/code];
## pooled nodes remain private children of this engine.


const DEFAULT_SPRITE_POOL_SIZE: int = 16
const DEFAULT_PARTICLE_POOL_SIZE: int = 16
const DEFAULT_SHADER_POOL_SIZE: int = 8

var _sprite_pool_size: int = DEFAULT_SPRITE_POOL_SIZE
var _particle_pool_size: int = DEFAULT_PARTICLE_POOL_SIZE
var _shader_pool_size: int = DEFAULT_SHADER_POOL_SIZE

var _sprite_pool: StdObjectPool
var _particle_pool: StdObjectPool
var _shader_pool: StdObjectPool

# Active pooled nodes and managed handles keyed by pooled node id.
var _active_nodes: Dictionary[int, Node] = {}
var _handles: Dictionary[int, StdEffectHandle] = {}
# Active shader ownership in both directions for O(1) overlap checks
# and cleanup without retaining target references.
var _shader_targets: Dictionary[int, int] = {}
var _runner_targets: Dictionary[int, int] = {}


#region Engine Methods
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop_all()
	return
#endregion Engine Methods


#region Public API
## Sets the fixed pool capacities. Call before the first valid
## playback; pools build lazily on first acquisition. Zero disables
## an effect kind. Errs without changing any size when a value is
## negative or the pools have already been built.
func configure_pools(
		sprite_size: int = DEFAULT_SPRITE_POOL_SIZE,
		particle_size: int = DEFAULT_PARTICLE_POOL_SIZE,
		shader_size: int = DEFAULT_SHADER_POOL_SIZE,
) -> StdResult:
	if _pools_are_built():
		return StdResult.err("effect pools are already built; configure them before first playback")
	if sprite_size < 0 or particle_size < 0 or shader_size < 0:
		return StdResult.err("effect pool capacities cannot be negative")
	_sprite_pool_size = sprite_size
	_particle_pool_size = particle_size
	_shader_pool_size = shader_size
	return StdResult.ok(true)


## Plays a managed sprite recipe. The ok value is an opaque
## [code]StdEffectHandle[/code]. Non-looping animations finish and release
## naturally; looping animations remain active until stopped.
func play(recipe: StdEffectRecipeInterface, pos: Vector2 = Vector2.ZERO) -> StdResult:
	if recipe == null: return StdResult.err("recipe is null")
	match recipe.kind():
		StdEffectRecipeInterface.Kind.SHADER:
			return StdResult.err("recipe '%s' is a shader effect, use play_on()" % _id_of(recipe))
		StdEffectRecipeInterface.Kind.PARTICLE:
			return StdResult.err(
					"recipe '%s' is a particle burst and one-shot, use play_oneshot()" % _id_of(recipe))
		_:
			pass
	if recipe is not StdSpriteEffectRecipe:
		return StdResult.err("recipe '%s' is not a StdSpriteEffectRecipe" % _id_of(recipe))
	var sprite_recipe: StdSpriteEffectRecipe = recipe
	if sprite_recipe.one_shot:
		return StdResult.err("recipe '%s' is one_shot, use play_oneshot()" % _id_of(recipe))
	var valid: StdResult = _validate_sprite(sprite_recipe)
	if valid.is_err(): return valid
	var played: StdResult = _acquire_and_play_sprite(sprite_recipe, pos)
	if played.is_err(): return played
	return StdResult.ok(_make_handle(played.unwrap()))


## Plays a one-shot sprite or particle recipe fire-and-forget. Its
## pooled node releases naturally and the ok value is [code]true[/code].
func play_oneshot(recipe: StdEffectRecipeInterface, pos: Vector2 = Vector2.ZERO) -> StdResult:
	if recipe == null: return StdResult.err("recipe is null")
	match recipe.kind():
		StdEffectRecipeInterface.Kind.SHADER:
			return StdResult.err("recipe '%s' is a shader effect, use play_on()" % _id_of(recipe))
		StdEffectRecipeInterface.Kind.PARTICLE:
			if recipe is not StdParticleEffectRecipe:
				return StdResult.err("recipe '%s' is not a StdParticleEffectRecipe" % _id_of(recipe))
			var particle_recipe: StdParticleEffectRecipe = recipe
			var particle_valid: StdResult = _validate_particle(particle_recipe)
			if particle_valid.is_err(): return particle_valid
			var burst: StdResult = _acquire_and_burst(particle_recipe, pos)
			if burst.is_err(): return burst
			return StdResult.ok(true)
		_:
			pass
	if recipe is not StdSpriteEffectRecipe:
		return StdResult.err("recipe '%s' is not a StdSpriteEffectRecipe" % _id_of(recipe))
	var sprite_recipe: StdSpriteEffectRecipe = recipe
	if not sprite_recipe.one_shot:
		return StdResult.err("recipe '%s' is not one_shot" % _id_of(recipe))
	if sprite_recipe.is_looping():
		return StdResult.err(
				"recipe '%s' has a looping animation and would never release its sprite" % _id_of(recipe))
	var sprite_valid: StdResult = _validate_sprite(sprite_recipe)
	if sprite_valid.is_err(): return sprite_valid
	var played: StdResult = _acquire_and_play_sprite(sprite_recipe, pos)
	if played.is_err(): return played
	return StdResult.ok(true)


## Runs a shader recipe on [param target]. The ok value is an opaque
## [code]StdEffectHandle[/code]. A target may own only one active StdEffects shader;
## overlapping playback errs without disturbing the first effect.
func play_on(recipe: StdEffectRecipeInterface, target: CanvasItem) -> StdResult:
	if recipe == null: return StdResult.err("recipe is null")
	if recipe.kind() != StdEffectRecipeInterface.Kind.SHADER or recipe is not StdShaderEffectRecipe:
		return StdResult.err(
				"recipe '%s' is not a shader effect, use play() or play_oneshot()" % _id_of(recipe))
	var shader_recipe: StdShaderEffectRecipe = recipe
	var valid: StdResult = _validate_shader(shader_recipe)
	if valid.is_err(): return valid
	if not StdNode.is_alive(target): return StdResult.err("target is null or freed")

	var target_id: int = target.get_instance_id()
	if _shader_targets.has(target_id):
		return StdResult.err("target already has an active StdEffects shader effect")

	_ensure_pools()
	var acquired: StdResult = _acquire(_shader_pool, "shader")
	if acquired.is_err(): return acquired
	var runner: StdShaderEffectRunner = acquired.unwrap()
	_activate(runner)
	var runner_id: int = runner.get_instance_id()
	_shader_targets[target_id] = runner_id
	_runner_targets[runner_id] = target_id
	var handle: StdEffectHandle = _make_handle(runner)

	var begun: StdResult = runner.begin(shader_recipe, target)
	if begun.is_err():
		var _released: StdResult = _release_node(runner, false)
		return begun
	return StdResult.ok(handle)


## Stops a managed [code]StdEffectHandle[/code] and releases its pooled node. Errs
## when the handle is null, foreign, or already inactive.
func stop(handle: StdEffectHandle) -> StdResult:
	if handle == null: return StdResult.err("effect handle is null")
	if not handle.is_active(): return StdResult.err("effect playback is no longer active")
	if not _handles.has(handle._node_id) or _handles[handle._node_id] != handle:
		return StdResult.err("effect handle is not managed by this StdEffectPlayer")
	var node_value: Variant = instance_from_id(handle._node_id)
	if node_value is not Node:
		_handles.erase(handle._node_id)
		handle._invalidate(false)
		return StdResult.err("managed effect node no longer exists")
	return _release_node(node_value, false)


## Stops every active one-shot and managed effect. Managed handles
## are invalidated without emitting [code]StdEffectHandle.finished[/code].
func stop_all() -> void:
	if not _pools_are_built(): return
	var active: Array[Node] = []
	active.assign(_active_nodes.values())
	for node: Node in active:
		var _rv: StdResult = _release_node(node, false)
		pass
	return
#endregion Public API


#region Signal Handlers
func _on_sprite_finished(sprite: AnimatedSprite2D) -> void:
	if not _active_nodes.has(sprite.get_instance_id()): return
	var _rv: StdResult = _release_node(sprite, true).inspect_err(
			func(e: Variant) -> void: push_warning("StdEffects auto-release failed: %s" % e))
	return


func _on_particles_finished(particles: GPUParticles2D) -> void:
	if not _active_nodes.has(particles.get_instance_id()): return
	var _rv: StdResult = _release_node(particles, true).inspect_err(
			func(e: Variant) -> void: push_warning("StdEffects auto-release failed: %s" % e))
	return


func _on_runner_finished(runner: StdShaderEffectRunner) -> void:
	if not _active_nodes.has(runner.get_instance_id()): return
	var _rv: StdResult = _release_node(runner, true).inspect_err(
			func(e: Variant) -> void: push_warning("StdEffects auto-release failed: %s" % e))
	return
#endregion Signal Handlers


#region Private Helpers
func _pools_are_built() -> bool:
	return _sprite_pool != null or _particle_pool != null or _shader_pool != null


func _ensure_pools() -> void:
	if _pools_are_built(): return
	_sprite_pool = StdObjectPool.new(_make_sprite, _sprite_pool_size, 0, _reset_sprite)
	_particle_pool = StdObjectPool.new(_make_particles, _particle_pool_size, 0, _reset_particles)
	_shader_pool = StdObjectPool.new(_make_runner, _shader_pool_size, 0, _reset_runner)
	return


func _validate_sprite(recipe: StdSpriteEffectRecipe) -> StdResult:
	var frames_opt: StdOption = recipe.frames()
	if frames_opt.is_none(): return StdResult.err("recipe '%s' has no frames" % _id_of(recipe))
	if recipe.animation() == &"":
		return StdResult.err("recipe '%s' has no animation name" % _id_of(recipe))
	var frames: SpriteFrames = frames_opt.unwrap()
	if not frames.has_animation(recipe.animation()):
		return StdResult.err(
				"recipe '%s' frames have no animation '%s'" % [_id_of(recipe), recipe.animation()])
	if frames.get_frame_count(recipe.animation()) <= 0:
		return StdResult.err("recipe '%s' animation has no frames" % _id_of(recipe))
	var speed_scale: float = recipe.speed_scale()
	var animation_speed: float = frames.get_animation_speed(recipe.animation())
	if not is_finite(speed_scale) or not is_finite(animation_speed):
		return StdResult.err("recipe '%s' animation speed must be finite" % _id_of(recipe))
	if speed_scale <= 0.0 or animation_speed <= 0.0:
		return StdResult.err("recipe '%s' animation speed must be positive" % _id_of(recipe))
	return StdResult.ok(true)


func _validate_particle(recipe: StdParticleEffectRecipe) -> StdResult:
	if recipe.process_material().is_none():
		return StdResult.err("recipe '%s' has no process material" % _id_of(recipe))
	if recipe.amount() <= 0:
		return StdResult.err("recipe '%s' particle amount must be positive" % _id_of(recipe))
	if not is_finite(recipe.lifetime()) or recipe.lifetime() <= 0.0:
		return StdResult.err("recipe '%s' particle lifetime must be positive" % _id_of(recipe))
	if not is_finite(recipe.explosiveness()):
		return StdResult.err("recipe '%s' explosiveness must be finite" % _id_of(recipe))
	if recipe.explosiveness() < 0.0 or recipe.explosiveness() > 1.0:
		return StdResult.err("recipe '%s' explosiveness must be between 0 and 1" % _id_of(recipe))
	return StdResult.ok(true)


func _validate_shader(recipe: StdShaderEffectRecipe) -> StdResult:
	if recipe.shader().is_none(): return StdResult.err("recipe '%s' has no shader" % _id_of(recipe))
	if recipe.tween_param() == &"":
		return StdResult.err("recipe '%s' has no tween parameter" % _id_of(recipe))
	var duration: float = recipe.duration().unwrap_or(0.0)
	if not is_finite(duration) or duration <= 0.0:
		return StdResult.err("recipe '%s' duration must be positive" % _id_of(recipe))
	return StdResult.ok(true)


func _acquire_and_play_sprite(recipe: StdSpriteEffectRecipe, pos: Vector2) -> StdResult:
	_ensure_pools()
	var acquired: StdResult = _acquire(_sprite_pool, "sprite")
	if acquired.is_err(): return acquired
	var sprite: AnimatedSprite2D = acquired.unwrap()
	_activate(sprite)
	sprite.sprite_frames = recipe.frames().unwrap()
	sprite.animation = recipe.animation()
	sprite.frame = 0
	sprite.speed_scale = recipe.speed_scale()
	sprite.scale = recipe.effect_scale()
	sprite.modulate = recipe.modulate()
	sprite.z_index = recipe.z_index()
	sprite.position = pos
	sprite.show()
	if sprite.is_inside_tree():
		sprite.play(recipe.animation())
	return StdResult.ok(sprite)


func _acquire_and_burst(recipe: StdParticleEffectRecipe, pos: Vector2) -> StdResult:
	_ensure_pools()
	var acquired: StdResult = _acquire(_particle_pool, "particle")
	if acquired.is_err(): return acquired
	var particles: GPUParticles2D = acquired.unwrap()
	_activate(particles)
	particles.process_material = recipe.process_material().unwrap()
	particles.texture = recipe.texture().unwrap_or(null)
	particles.amount = recipe.amount()
	particles.lifetime = recipe.lifetime()
	particles.explosiveness = recipe.explosiveness()
	particles.modulate = recipe.modulate()
	particles.z_index = recipe.z_index()
	particles.position = pos
	particles.one_shot = true
	particles.show()
	if particles.is_inside_tree():
		particles.restart()
	return StdResult.ok(particles)


func _acquire(pool: StdObjectPool, kind: String) -> StdResult:
	var acquired: StdResult = pool.acquire()
	if acquired.is_ok(): return acquired
	if pool.is_exhausted():
		return StdResult.err(
				"%s effect pool exhausted (%d/%d active); call configure_pools() before first playback"
				% [kind, pool.active_count(), pool.capacity()])
	return StdResult.err("%s effect unavailable: %s" % [kind, acquired.unwrap_err()])


func _activate(node: Node) -> void:
	if node.get_parent() == null:
		add_child(node)
	_active_nodes[node.get_instance_id()] = node
	return


func _make_handle(node: Node) -> StdEffectHandle:
	var id: int = node.get_instance_id()
	var handle: StdEffectHandle = StdEffectHandle.new(self, id)
	_handles[id] = handle
	return handle


func _release_node(node: Node, natural_finish: bool) -> StdResult:
	var id: int = node.get_instance_id()
	if not _active_nodes.has(id): return StdResult.err("effect playback is no longer active")
	var pool: StdObjectPool = _pool_for_node(node)
	if pool == null: return StdResult.err("not a pooled effect node: %s" % node)
	var released: StdResult = pool.release(node)
	if released.is_err(): return released
	_active_nodes.erase(id)
	_forget_shader_target(id)
	var value: Variant = true
	if _handles.has(id):
		var handle: StdEffectHandle = _handles[id]
		_handles.erase(id)
		handle._invalidate(natural_finish)
		value = handle
	return StdResult.ok(value)


func _forget_shader_target(runner_id: int) -> void:
	if not _runner_targets.has(runner_id): return
	var target_id: int = _runner_targets[runner_id]
	_runner_targets.erase(runner_id)
	if _shader_targets.get(target_id, 0) == runner_id:
		_shader_targets.erase(target_id)
	return


func _pool_for_node(node: Node) -> StdObjectPool:
	if node is AnimatedSprite2D: return _sprite_pool
	if node is GPUParticles2D: return _particle_pool
	if node is StdShaderEffectRunner: return _shader_pool
	return null


func _make_sprite() -> Node:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.hide()
	_adopt(sprite)
	var _e: int = sprite.animation_finished.connect(_on_sprite_finished.bind(sprite))
	return sprite


func _make_particles() -> Node:
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.hide()
	_adopt(particles)
	var _e: int = particles.finished.connect(_on_particles_finished.bind(particles))
	return particles


func _make_runner() -> Node:
	var runner: StdShaderEffectRunner = StdShaderEffectRunner.new()
	_adopt(runner)
	var _e: int = runner.finished.connect(_on_runner_finished.bind(runner))
	return runner


func _adopt(node: Node) -> void:
	add_child(node)
	return


func _reset_sprite(node: Node) -> void:
	var sprite: AnimatedSprite2D = node
	sprite.stop()
	sprite.sprite_frames = null
	sprite.hide()
	return


func _reset_particles(node: Node) -> void:
	var particles: GPUParticles2D = node
	particles.emitting = false
	particles.process_material = null
	particles.texture = null
	particles.hide()
	return


func _reset_runner(node: Node) -> void:
	var runner: StdShaderEffectRunner = node
	runner.reset()
	return


func _id_of(recipe: StdEffectRecipeInterface) -> StringName:
	return recipe.id().unwrap_or(&"<no id>")
#endregion Private Helpers
