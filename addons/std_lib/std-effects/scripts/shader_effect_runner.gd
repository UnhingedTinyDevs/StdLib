class_name StdShaderEffectRunner
extends Node
## Runs one [code]StdShaderEffectRecipe[/code] on a target [CanvasItem]
##
## Applies a [ShaderMaterial] built from the recipe to the target,
## tweens the recipe's animated uniform over its duration, then
## restores the target's original material and emits [signal finished].
## This is an internal pooled node; callers receive [code]StdEffectHandle[/code]
## rather than the runner itself. Outside the tree the material is
## applied but no tween advances, matching other engine playback
## nodes; callers can still stop the returned handle synchronously.

## Emitted when the effect completes on its own (tween done, or
## immediately when headless) and the target's original material has
## been restored. [method cancel] restores silently without emitting.

signal finished

var _target: CanvasItem
var _original_material: Material
var _applied_material: ShaderMaterial
var _tween: Tween
var _active: bool = false


#region Public API
## Starts the effect: stashes the target's current material, applies a
## new [ShaderMaterial] from the recipe, and tweens the animated
## uniform. Errs when already active, the recipe is null or has no
## shader, or the target is null or freed. On success the ok value is
## [code]true[/code]. Outside the tree the material is applied but no
## tween is created.
func begin(recipe: StdShaderEffectRecipe, target: CanvasItem) -> StdResult:
	if _active:
		return StdResult.err("runner is already active")
	if recipe == null:
		return StdResult.err("recipe is null")
	var shader_opt: StdOption = recipe.shader()
	if shader_opt.is_none():
		return StdResult.err("recipe '%s' has no shader" % recipe.id().unwrap_or(&"<no id>"))
	if not StdNode.is_alive(target):
		return StdResult.err("target is null or freed")

	_target = target
	_original_material = target.material
	_active = true

	_applied_material = ShaderMaterial.new()
	_applied_material.shader = shader_opt.unwrap()
	var params: Dictionary = recipe.params()
	for param: StringName in params:
		_applied_material.set_shader_parameter(param, params[param])
	_applied_material.set_shader_parameter(recipe.tween_param(), recipe.tween_from())
	target.material = _applied_material

	if not is_inside_tree():
		# Headless tests and direct off-tree use cannot advance a Tween.
		# Keep the managed effect active until its handle is stopped.
		return StdResult.ok(true)

	var set_param: Callable = func(value: float) -> void:
		_applied_material.set_shader_parameter(recipe.tween_param(), value)
	_tween = create_tween()
	var _step: Tweener = _tween.tween_method(
			set_param, recipe.tween_from(), recipe.tween_to(),
			recipe.duration().unwrap_or(0.4))
	var _e: int = _tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)
	return StdResult.ok(true)


## Cancels a running effect early: kills the tween and restores the
## target's original material (when the target is still alive).
## Silent — [signal finished] is not emitted, so the pool release
## driven by [code]StdEffectPlayer.stop[/code] stays the only release.
## Safe to call when idle.
func cancel() -> void:
	if not _active: return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_finish(false)
	return


## True while an effect is running on a target.
func is_active() -> bool:
	return _active


## Clears all references. Used as the pool reset hook; cancels first
## when still active.
func reset() -> void:
	cancel()
	_target = null
	_original_material = null
	_applied_material = null
	return
#endregion Public API


#region Signal Handlers
func _on_tween_finished() -> void:
	_tween = null
	_finish(true)
	return
#endregion Signal Handlers


#region Private Helpers
# Restores only when the target still owns the material this runner
# applied. A newer external material assignment always wins.
func _finish(emit: bool) -> void:
	if not _active: return
	_active = false
	if StdNode.is_alive(_target) and _target.material == _applied_material:
		_target.material = _original_material
	if emit:
		finished.emit()
	return
#endregion Private Helpers
