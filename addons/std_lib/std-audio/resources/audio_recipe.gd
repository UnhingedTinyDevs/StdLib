class_name StdAudioRecipe
extends Resource
## Configuration for one global audio stream.
##
## The same recipe can be registered with [code]StdAudio[/code] or played
## directly. An [member id] is required only when registering the recipe.


## Registry key. Direct playback does not require an id.
@export var id: StringName
## Stream played by this recipe.
@export var stream: AudioStream
## Audio bus that receives the playback.
@export var bus: StringName = &"Master"
## Volume applied directly to [member AudioStreamPlayer.volume_db].
@export_range(-80.0, 24.0, 0.1, "or_less", "or_greater") var volume_db: float = 0.0
