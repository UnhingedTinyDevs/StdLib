@abstract
class_name StdAudioRecipeInterface
extends Resource
## Data that describes what functions are available on Audio Resources

## What type of audio is it

enum Type { MUSIC, SFX, DIALOG, OTHER }
## What dimension is the audio played in
enum Dimension { GLOBAL, D2, D3 }

@abstract func id() -> StdOption
@abstract func stream() -> StdOption
@abstract func bus() -> StdOption
@abstract func volume() -> StdOption
@abstract func type() -> StdAudioRecipeInterface.Type
@abstract func dim() -> StdAudioRecipeInterface.Dimension
