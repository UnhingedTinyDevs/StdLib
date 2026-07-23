extends RefCounted
## Internal pooled playback for [StdSpriteEffectRecipe].


class _Playback:
	extends RefCounted

	var sprite: AnimatedSprite2D
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
	_pool = StdObjectPool.new(_new_sprite, capacity, 0, _reset_sprite)
	return


func validate(recipe: StdSpriteEffectRecipe) -> StdResult:
	if recipe == null: return StdResult.err("sprite effect recipe is null")
	var label: StringName = _label(recipe)
	if recipe.frames == null:
		return StdResult.err("sprite effect recipe '%s' has no frames" % label)
	if recipe.animation == &"":
		return StdResult.err("sprite effect recipe '%s' has no animation name" % label)
	if not recipe.frames.has_animation(recipe.animation):
		return StdResult.err(
				"sprite effect recipe '%s' has no animation '%s'" % [label, recipe.animation])
	if recipe.frames.get_frame_count(recipe.animation) <= 0:
		return StdResult.err("sprite effect recipe '%s' animation has no frames" % label)
	var animation_speed: float = recipe.frames.get_animation_speed(recipe.animation)
	if not is_finite(recipe.speed_scale) or not is_finite(animation_speed):
		return StdResult.err("sprite effect recipe '%s' speed must be finite" % label)
	if recipe.speed_scale <= 0.0 or animation_speed <= 0.0:
		return StdResult.err("sprite effect recipe '%s' speed must be positive" % label)
	return StdResult.ok(true)


func play(
		recipe: StdSpriteEffectRecipe,
		position: Vector2 = Vector2.ZERO,
) -> StdResult:
	if not _owner.is_inside_tree(): return StdResult.err("StdEffects must be inside the scene tree")
	if not position.is_finite(): return StdResult.err("sprite effect position must be finite")
	var valid: StdResult = validate(recipe)
	if valid.is_err(): return valid

	var acquired: StdResult = _acquire()
	if acquired.is_err(): return acquired
	var sprite: AnimatedSprite2D = acquired.unwrap()
	sprite.sprite_frames = recipe.frames
	sprite.animation = recipe.animation
	sprite.frame = 0
	sprite.speed_scale = recipe.speed_scale
	sprite.scale = recipe.scale
	sprite.modulate = recipe.modulate
	sprite.z_index = recipe.z_index
	sprite.position = position
	sprite.show()

	_owner.add_child(sprite)
	var playback_id: int = sprite.get_instance_id()
	var playback: _Playback = _Playback.new()
	playback.sprite = sprite
	playback.handle = StdEffectHandle.new(self, playback_id)
	_playbacks[playback_id] = playback
	_started = true
	sprite.play()
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
func _on_finished(sprite: AnimatedSprite2D) -> void:
	var playback_id: int = sprite.get_instance_id()
	if not _playbacks.has(playback_id): return
	var released: StdResult = _release(playback_id, true)
	if released.is_err():
		push_warning("StdEffects sprite auto-release failed: %s" % released.unwrap_err())
	return
#endregion Signal Handlers


#region Private Helpers
func _acquire() -> StdResult:
	var acquired: StdResult = _pool.acquire()
	if acquired.is_ok(): return acquired
	if _pool.is_exhausted():
		return StdResult.err(
				"sprite effect pool exhausted (%d/%d active)"
				% [_pool.active_count(), _pool.capacity()])
	return StdResult.err("sprite effect unavailable: %s" % acquired.unwrap_err())


func _release(playback_id: int, natural_finish: bool) -> StdResult:
	var playback: _Playback = _playbacks.get(playback_id)
	if playback == null: return StdResult.err("effect playback is no longer active")
	var released: StdResult = _pool.release(playback.sprite)
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


func _new_sprite() -> Node:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.hide()
	var error: Error = sprite.animation_finished.connect(_on_finished.bind(sprite))
	if error != OK:
		push_error("StdEffects could not connect a sprite completion signal")
		sprite.free()
		return null
	return sprite


func _reset_sprite(node: Node) -> void:
	var sprite: AnimatedSprite2D = node
	sprite.stop()
	sprite.sprite_frames = null
	sprite.hide()
	return


func _label(recipe: StdEffectRecipe) -> StringName:
	return recipe.id if recipe.id != &"" else &"<unregistered>"
#endregion Private Helpers
