class_name StdAudioRecipe3D
extends "res://addons/std_lib/std-audio/resources/positional_audio_recipe_interface.gd"

@export_group("Location")
@export var _pos: Vector3
@export var _radius: float = 1000.0


func _init() -> void:
	_dim = StdAudioRecipeInterface.Dimension.D3


## Returns the configured position, including [constant Vector3.ZERO].
func pos() -> StdOption:
	return StdOption.some(_pos)


## Returns the configured radius, including [code]0.0[/code].
func radius() -> StdOption:
	return StdOption.some(_radius)
