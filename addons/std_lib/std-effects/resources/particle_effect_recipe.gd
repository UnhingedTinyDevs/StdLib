class_name StdParticleEffectRecipe
extends "res://addons/std_lib/std-effects/resources/effect_recipe_interface.gd"
## A one-shot particle burst played on a pooled [GPUParticles2D]
##
## Describes a burst of particles at a world position. The
## [member _process_material] (a [ParticleProcessMaterial]) drives the
## motion and is required to play — the analogue of an [code]StdAudioRecipe[/code]
## without a stream. The texture is optional; when null the default
## white quad is used. Particle recipes are inherently one-shot and
## only play through [code]StdEffects.play_oneshot[/code].


@export var _id: StringName
@export var _process_material: Material
@export var _texture: Texture2D
@export_range(1, 512) var _amount: int = 24
@export_range(0.05, 10.0, 0.05) var _lifetime: float = 0.6
@export_range(0.0, 1.0, 0.05) var _explosiveness: float = 1.0
@export var _modulate: Color = Color.WHITE
## Effects draw above the board by default.
@export var _z_index: int = 100


func id() -> StdOption:
	if _id == &"": return StdOption.none()
	return StdOption.some(_id)


func process_material() -> StdOption:
	if _process_material == null: return StdOption.none()
	return StdOption.some(_process_material)


func texture() -> StdOption:
	if _texture == null: return StdOption.none()
	return StdOption.some(_texture)


func amount() -> int:
	return _amount


func lifetime() -> float:
	return _lifetime


func explosiveness() -> float:
	return _explosiveness


func modulate() -> Color:
	return _modulate


func z_index() -> int:
	return _z_index


## Bursts last one particle lifetime.
func duration() -> StdOption:
	return StdOption.some(_lifetime)


func kind() -> StdEffectRecipeInterface.Kind:
	return StdEffectRecipeInterface.Kind.PARTICLE
