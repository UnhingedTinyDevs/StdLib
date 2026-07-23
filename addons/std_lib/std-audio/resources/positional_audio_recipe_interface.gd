@abstract
class_name StdPositionalAudioRecipeInterface
extends "res://addons/std_lib/std-audio/resources/audio_recipe.gd"
## A positional audio recipe.
##
## This is audio that is played locally in the game world
## it should have a position and a radius in which the audio 
## can be heard


@abstract func pos() -> StdOption
@abstract func radius() -> StdOption
