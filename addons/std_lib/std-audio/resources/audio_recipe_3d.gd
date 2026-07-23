class_name StdAudioRecipe3D
extends "res://addons/std_lib/std-audio/resources/audio_recipe.gd"
## Configuration for one positional 3D audio stream.
##
## The playback position is supplied to [code]StdAudio.play_3d[/code] or
## [code]StdAudio.play_3d_id[/code], so one recipe can be reused anywhere.


## Maximum distance at which the sound remains audible.
@export_range(0.001, 100000.0, 0.1, "or_greater") var max_distance: float = 1000.0
