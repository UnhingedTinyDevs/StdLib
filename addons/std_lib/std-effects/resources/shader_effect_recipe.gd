class_name StdShaderEffectRecipe
extends "res://addons/std_lib/std-effects/resources/effect_recipe.gd"
## A temporary shader applied to an existing [CanvasItem].
##
## Static parameters are set once, then one parameter is tweened over the
## configured duration. The target's original material is restored when the
## effect finishes or is stopped.


## Shader applied to the target.
@export var shader: Shader
## Static shader uniforms applied once when the effect starts.
@export var params: Dictionary[StringName, Variant] = {}
## The uniform animated over the effect's duration.
@export var tween_param: StringName = &"progress"
## Initial value of [member tween_param].
@export var tween_from: float = 0.0
## Final value of [member tween_param].
@export var tween_to: float = 1.0
## Tween duration in seconds.
@export_range(0.01, 30.0, 0.01) var duration: float = 0.4
