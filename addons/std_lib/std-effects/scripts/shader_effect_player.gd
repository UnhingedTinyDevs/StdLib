extends RefCounted
## Internal tween and material lifecycle for [StdShaderEffectRecipe].


class _Playback:
	extends RefCounted

	var handle: StdEffectHandle
	var target: WeakRef
	var original_material: Material
	var applied_material: ShaderMaterial
	var tween: Tween


var _owner: Node
var _playbacks: Dictionary[int, _Playback] = {}


func _init(owner: Node) -> void:
	_owner = owner
	return


#region StdEffects API
func validate(recipe: StdShaderEffectRecipe) -> StdResult:
	if recipe == null: return StdResult.err("shader effect recipe is null")
	var label: StringName = _label(recipe)
	if recipe.shader == null:
		return StdResult.err("shader effect recipe '%s' has no shader" % label)
	if recipe.tween_param == &"":
		return StdResult.err("shader effect recipe '%s' has no tween parameter" % label)
	if not is_finite(recipe.tween_from) or not is_finite(recipe.tween_to):
		return StdResult.err("shader effect recipe '%s' tween values must be finite" % label)
	if not is_finite(recipe.duration) or recipe.duration <= 0.0:
		return StdResult.err("shader effect recipe '%s' duration must be positive" % label)
	return StdResult.ok(true)


func play(recipe: StdShaderEffectRecipe, target: CanvasItem) -> StdResult:
	if not _owner.is_inside_tree(): return StdResult.err("StdEffects must be inside the scene tree")
	var valid: StdResult = validate(recipe)
	if valid.is_err(): return valid
	if not StdNode.is_alive(target):
		return StdResult.err("shader target is null, freed, or queued for deletion")

	var playback_id: int = target.get_instance_id()
	if _playbacks.has(playback_id):
		return StdResult.err("target already has an active StdEffects shader effect")

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = recipe.shader
	for param: StringName in recipe.params:
		material.set_shader_parameter(param, recipe.params[param])
		pass
	var tween_param: StringName = recipe.tween_param
	material.set_shader_parameter(tween_param, recipe.tween_from)

	var playback: _Playback = _Playback.new()
	playback.handle = StdEffectHandle.new(self, playback_id)
	playback.target = weakref(target)
	playback.original_material = target.material
	playback.applied_material = material
	target.material = material

	var set_param: Callable = func(value: float) -> void:
		material.set_shader_parameter(tween_param, value)
		return
	playback.tween = _owner.create_tween()
	var _step: Tweener = playback.tween.tween_method(
			set_param, recipe.tween_from, recipe.tween_to, recipe.duration)
	var error: Error = playback.tween.finished.connect(
			_on_finished.bind(playback_id), CONNECT_ONE_SHOT)
	if error != OK:
		playback.tween.kill()
		_restore(playback)
		return StdResult.err("could not connect shader completion: %s" % error_string(error))

	_playbacks[playback_id] = playback
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
func _on_finished(playback_id: int) -> void:
	if not _playbacks.has(playback_id): return
	var released: StdResult = _release(playback_id, true)
	if released.is_err():
		push_warning("StdEffects shader auto-release failed: %s" % released.unwrap_err())
	return
#endregion Signal Handlers


#region Private Helpers
func _release(playback_id: int, natural_finish: bool) -> StdResult:
	var playback: _Playback = _playbacks.get(playback_id)
	if playback == null: return StdResult.err("effect playback is no longer active")
	_playbacks.erase(playback_id)
	if not natural_finish and playback.tween != null and playback.tween.is_valid():
		playback.tween.kill()
	_restore(playback)
	playback.handle._invalidate(natural_finish)
	return StdResult.ok(true)


func _restore(playback: _Playback) -> void:
	var target_value: Variant = playback.target.get_ref()
	if target_value is not CanvasItem or not StdNode.is_alive(target_value): return
	var target: CanvasItem = target_value
	if target.material == playback.applied_material:
		target.material = playback.original_material
	return


# Called only by StdEffectHandle.
func _stop_from_handle(handle: StdEffectHandle) -> StdResult:
	if handle == null or not handle.is_active():
		return StdResult.err("effect playback is no longer active")
	var playback: _Playback = _playbacks.get(handle._playback_id)
	if playback == null or playback.handle != handle:
		return StdResult.err("effect handle is not owned by StdEffects")
	return _release(handle._playback_id, false)


func _label(recipe: StdEffectRecipe) -> StringName:
	return recipe.id if recipe.id != &"" else &"<unregistered>"
#endregion Private Helpers
