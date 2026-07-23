class_name StdAudioRecipe2D
extends "res://addons/std_lib/std-audio/resources/positional_audio_recipe_interface.gd"
## An audio recipe for a sound that should be play positionally in 2D


@export_group("Location")
# The location the sound will be played at
@export var _pos: Vector2
# How far from the position can the noise be heard
@export var _radius: float = 1000.0


func _init() -> void:
	_dim = StdAudioRecipeInterface.Dimension.D2


## Returns the configured position, including [constant Vector2.ZERO].
func pos() -> StdOption:
	return StdOption.some(_pos)


## Returns the configured radius, including [code]0.0[/code].
func radius() -> StdOption:
	return StdOption.some(_radius)
