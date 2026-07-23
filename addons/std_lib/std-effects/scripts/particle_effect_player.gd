extends RefCounted
## Internal pooled playback for [StdParticleEffectRecipe].


class _Playback:
	extends RefCounted

	var particles: GPUParticles2D
	var handle: StdEffectHandle


var _owner: Node
var _pool: StdObjectPool
var _playbacks: Dictionary[int, _Playback] = {}
var _started: bool = false


func _init(owner: Node, capacity: int) -> void:
	_owner = owner
	configure(capacity)
	return


#region StdEffects API
func has_started() -> bool:
	return _started


func configure(capacity: int) -> void:
	_pool = StdObjectPool.new(_new_particles, capacity, 0, _reset_particles)
	return


func validate(recipe: StdParticleEffectRecipe) -> StdResult:
	if recipe == null: return StdResult.err("particle effect recipe is null")
	var label: StringName = _label(recipe)
	if recipe.process_material == null:
		return StdResult.err("particle effect recipe '%s' has no process material" % label)
	if recipe.amount <= 0:
		return StdResult.err("particle effect recipe '%s' amount must be positive" % label)
	if not is_finite(recipe.lifetime) or recipe.lifetime <= 0.0:
		return StdResult.err("particle effect recipe '%s' lifetime must be positive" % label)
	if not is_finite(recipe.explosiveness):
		return StdResult.err("particle effect recipe '%s' explosiveness must be finite" % label)
	if recipe.explosiveness < 0.0 or recipe.explosiveness > 1.0:
		return StdResult.err(
				"particle effect recipe '%s' explosiveness must be between 0 and 1" % label)
	return StdResult.ok(true)


func play(
		recipe: StdParticleEffectRecipe,
		position: Vector2 = Vector2.ZERO,
) -> StdResult:
	if not _owner.is_inside_tree(): return StdResult.err("StdEffects must be inside the scene tree")
	if not position.is_finite(): return StdResult.err("particle effect position must be finite")
	var valid: StdResult = validate(recipe)
	if valid.is_err(): return valid

	var acquired: StdResult = _acquire()
	if acquired.is_err(): return acquired
	var particles: GPUParticles2D = acquired.unwrap()
	particles.process_material = recipe.process_material
	particles.texture = recipe.texture
	particles.amount = recipe.amount
	particles.lifetime = recipe.lifetime
	particles.explosiveness = recipe.explosiveness
	particles.modulate = recipe.modulate
	particles.z_index = recipe.z_index
	particles.position = position
	particles.show()

	_owner.add_child(particles)
	var playback_id: int = particles.get_instance_id()
	var playback: _Playback = _Playback.new()
	playback.particles = particles
	playback.handle = StdEffectHandle.new(self, playback_id)
	_playbacks[playback_id] = playback
	_started = true
	particles.restart()
	return StdResult.ok(playback.handle)


func stop_all() -> int:
	var ids: Array[int] = []
	ids.assign(_playbacks.keys())
	var stopped: int = 0
	for playback_id: int in ids:
		var released: StdResult = _release(playback_id, false)
		if released.is_ok():
			stopped += 1
		pass
	return stopped
#endregion StdEffects API


#region Signal Handlers
func _on_finished(particles: GPUParticles2D) -> void:
	var playback_id: int = particles.get_instance_id()
	if not _playbacks.has(playback_id): return
	var released: StdResult = _release(playback_id, true)
	if released.is_err():
		push_warning("StdEffects particle auto-release failed: %s" % released.unwrap_err())
	return
#endregion Signal Handlers


#region Private Helpers
func _acquire() -> StdResult:
	var acquired: StdResult = _pool.acquire()
	if acquired.is_ok(): return acquired
	if _pool.is_exhausted():
		return StdResult.err(
				"particle effect pool exhausted (%d/%d active)"
				% [_pool.active_count(), _pool.capacity()])
	return StdResult.err("particle effect unavailable: %s" % acquired.unwrap_err())


func _release(playback_id: int, natural_finish: bool) -> StdResult:
	var playback: _Playback = _playbacks.get(playback_id)
	if playback == null: return StdResult.err("effect playback is no longer active")
	var released: StdResult = _pool.release(playback.particles)
	if released.is_err(): return released
	_playbacks.erase(playback_id)
	playback.handle._invalidate(natural_finish)
	return StdResult.ok(true)


# Called only by StdEffectHandle.
func _stop_from_handle(handle: StdEffectHandle) -> StdResult:
	if handle == null or not handle.is_active():
		return StdResult.err("effect playback is no longer active")
	var playback: _Playback = _playbacks.get(handle._playback_id)
	if playback == null or playback.handle != handle:
		return StdResult.err("effect handle is not owned by StdEffects")
	return _release(handle._playback_id, false)


func _new_particles() -> Node:
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.hide()
	var error: Error = particles.finished.connect(_on_finished.bind(particles))
	if error != OK:
		push_error("StdEffects could not connect a particle completion signal")
		particles.free()
		return null
	return particles


func _reset_particles(node: Node) -> void:
	var particles: GPUParticles2D = node
	particles.emitting = false
	particles.process_material = null
	particles.texture = null
	particles.hide()
	return


func _label(recipe: StdEffectRecipe) -> StringName:
	return recipe.id if recipe.id != &"" else &"<unregistered>"
#endregion Private Helpers
