class_name StdAudioRecipe
extends "res://addons/std_lib/std-audio/resources/audio_recipe_interface.gd"
## Basic implementation of [code]StdAudioRecipeInterface[/code]


@export var _id: StringName
@export var _stream: AudioStream
@export var _bus: StringName
@export_range(0.0, 100.0, 0.1) var _volume: float = 50.0
@export var one_shot: bool = false
@export var _type: StdAudioRecipeInterface.Type = StdAudioRecipeInterface.Type.OTHER
@export var _dim: StdAudioRecipeInterface.Dimension = StdAudioRecipeInterface.Dimension.GLOBAL


func id() -> StdOption:
	if _id == &"": return StdOption.none()
	return StdOption.some(_id)


func bus() -> StdOption:
	if _bus == &"": return StdOption.none()
	return StdOption.some(_bus)


func stream() -> StdOption:
	if _stream == null: return StdOption.none()
	return StdOption.some(_stream)


## Returns the configured 0–100 volume. Zero is a present value and
## means silence; new recipes default to 50.
func volume() -> StdOption:
	return StdOption.some(_volume)


## True when the configured stream is set to loop. Derived from the
## stream itself ([code]loop[/code] on Ogg/MP3, [code]loop_mode[/code]
## on WAV), never a stored flag, so it cannot drift from the stream's
## import settings.
func is_looping() -> bool:
	if _stream == null: return false
	var loop: Variant = _stream.get("loop")
	if loop is bool: return loop
	var mode: Variant = _stream.get("loop_mode")
	if mode is int: return mode != AudioStreamWAV.LOOP_DISABLED
	return false


func type() -> StdAudioRecipeInterface.Type:
	return _type


func dim() -> StdAudioRecipeInterface.Dimension:
	return _dim
