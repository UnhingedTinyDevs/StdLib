class_name StdSpriteEffectRecipe
extends "res://addons/std_lib/std-effects/resources/effect_recipe.gd"
## A flipbook animation played on a pooled [AnimatedSprite2D].
##
## Non-looping animations release their pooled sprite when they finish.
## Looping animations remain active until their [StdEffectHandle] is stopped.


## Frames containing the animation to play.
@export var frames: SpriteFrames
## Animation selected from [member frames].
@export var animation: StringName = &"default"
## Playback-speed multiplier.
@export_range(0.1, 10.0, 0.1) var speed_scale: float = 1.0
## Scale applied to the pooled sprite.
@export var scale: Vector2 = Vector2.ONE
## Color modulation applied to the pooled sprite.
@export var modulate: Color = Color.WHITE
## Effects draw above the board by default.
@export var z_index: int = 100
