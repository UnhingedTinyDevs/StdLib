class_name StdParticleEffectRecipe
extends "res://addons/std_lib/std-effects/resources/effect_recipe.gd"
## A particle burst played on a pooled [GPUParticles2D].
##
## The process material is required. The texture is optional, and the default
## white quad is used when it is null.


## Material that controls particle motion.
@export var process_material: Material
## Optional particle texture.
@export var texture: Texture2D
## Number of particles emitted.
@export_range(1, 512) var amount: int = 24
## Lifetime of each particle in seconds.
@export_range(0.05, 10.0, 0.05) var lifetime: float = 0.6
## How abruptly the particles are emitted.
@export_range(0.0, 1.0, 0.05) var explosiveness: float = 1.0
## Color modulation applied to the emitter.
@export var modulate: Color = Color.WHITE
## Effects draw above the board by default.
@export var z_index: int = 100
