class_name StdEffectRecipe
extends Resource
## Shared data for a reusable visual-effect recipe.
##
## An id is required for registration with [code]StdEffects[/code], but direct
## playback accepts an unregistered recipe with an empty id.


## Registry key used by the [code]*_id[/code] playback methods.
@export var id: StringName
