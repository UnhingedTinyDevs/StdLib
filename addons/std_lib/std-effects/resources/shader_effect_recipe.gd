class_name StdShaderEffectRecipe
extends "res://addons/std_lib/std-effects/resources/effect_recipe_interface.gd"
## A temporary shader applied to an existing [CanvasItem]
##
## Describes a [Shader] to overlay on a target node for a fixed
## duration: static uniforms set once ([member _params]) plus one
## uniform tweened from [member _tween_from] to [member _tween_to]
## over [member _duration]. The target's original material is restored
## when the effect finishes or is stopped. Plays only through
## [code]StdEffects.play_on(recipe, target)[/code].


@export var _id: StringName
@export var _shader: Shader
## Static shader uniforms applied once when the effect starts.
@export var _params: Dictionary[StringName, Variant] = {}
## The uniform animated over the effect's duration.
@export var _tween_param: StringName = &"progress"
@export var _tween_from: float = 0.0
@export var _tween_to: float = 1.0
@export_range(0.01, 30.0, 0.01) var _duration: float = 0.4


func id() -> StdOption:
	if _id == &"": return StdOption.none()
	return StdOption.some(_id)


func shader() -> StdOption:
	if _shader == null: return StdOption.none()
	return StdOption.some(_shader)


func params() -> Dictionary:
	return _params


func tween_param() -> StringName:
	return _tween_param


func tween_from() -> float:
	return _tween_from


func tween_to() -> float:
	return _tween_to


func duration() -> StdOption:
	return StdOption.some(_duration)


func kind() -> StdEffectRecipeInterface.Kind:
	return StdEffectRecipeInterface.Kind.SHADER
