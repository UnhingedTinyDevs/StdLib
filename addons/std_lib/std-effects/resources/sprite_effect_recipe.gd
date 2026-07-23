class_name StdSpriteEffectRecipe
extends "res://addons/std_lib/std-effects/resources/effect_recipe_interface.gd"
## A flipbook animation effect played on a pooled [AnimatedSprite2D]
##
## Describes a [SpriteFrames] animation to flash at a world position:
## which animation, how fast, and how it is drawn. One-shot recipes
## ([member one_shot] true, the default) play through
## [code]StdEffects.play_oneshot[/code] and release their pooled sprite
## when the animation finishes; managed recipes play through
## [code]StdEffects.play[/code] and return a handle to stop.


@export var _id: StringName
@export var _frames: SpriteFrames
@export var _animation: StringName = &"default"
@export_range(0.1, 10.0, 0.1) var _speed_scale: float = 1.0
@export var _scale: Vector2 = Vector2.ONE
@export var _modulate: Color = Color.WHITE
## Effects draw above the board by default.
@export var _z_index: int = 100
@export var one_shot: bool = true


func id() -> StdOption:
	if _id == &"": return StdOption.none()
	return StdOption.some(_id)


func frames() -> StdOption:
	if _frames == null: return StdOption.none()
	return StdOption.some(_frames)


func animation() -> StringName:
	return _animation


func speed_scale() -> float:
	return _speed_scale


func effect_scale() -> Vector2:
	return _scale


func modulate() -> Color:
	return _modulate


func z_index() -> int:
	return _z_index


## True when the configured animation is set to loop. Derived from the
## [SpriteFrames] itself, never a stored flag, so it cannot drift from
## the asset. Looping recipes are rejected by
## [code]play_oneshot[/code] (they would never finish and would leak
## their pool slot).
func is_looping() -> bool:
	if _frames == null: return false
	if not _frames.has_animation(_animation): return false
	return _frames.get_animation_loop(_animation)


## Play time of one pass through the animation in seconds: the summed
## relative frame durations divided by
## [code]animation_speed * speed_scale[/code]. Returns
## [code]none[/code] when the frames or animation are missing, or the
## animation has no frames or a non-positive speed.
func duration() -> StdOption:
	if _frames == null: return StdOption.none()
	if not _frames.has_animation(_animation): return StdOption.none()
	var fps: float = _frames.get_animation_speed(_animation) * _speed_scale
	if fps <= 0.0: return StdOption.none()
	var frame_count: int = _frames.get_frame_count(_animation)
	if frame_count <= 0: return StdOption.none()
	var total: float = 0.0
	for i in frame_count:
		total += _frames.get_frame_duration(_animation, i)
	return StdOption.some(total / fps)


func kind() -> StdEffectRecipeInterface.Kind:
	return StdEffectRecipeInterface.Kind.SPRITE
