@abstract
class_name StdEffectRecipeInterface
extends Resource
## Data that describes what functions are available on effect resources

## What kind of visual effect the recipe describes

enum Kind { SPRITE, PARTICLE, SHADER }

@abstract func id() -> StdOption
@abstract func kind() -> StdEffectRecipeInterface.Kind
@abstract func duration() -> StdOption
