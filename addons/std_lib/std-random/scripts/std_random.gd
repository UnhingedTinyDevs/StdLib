extends Node
## Named deterministic random stream registry for the std-random module.
##
## Owned by the [code]StdLib[/code] autoload and available as
## [code]StdRandom[/code] when the plugin is enabled. A session seed deterministically derives independent
## cached [code]StdRandomStream[/code] instances by name. Draws from one stream never
## advance another stream.
## [codeblock]
## StdRandom.set_seed(42)
## var combat: StdRandomStream = StdRandom.stream(&"combat")
## if combat.chance(0.35): _spawn_bomb()
## var loot: StdBag = StdBag.from_array(
##     [&"common", &"common", &"rare"], StdRandom.stream(&"loot")
## )
## var drop: StdOption = loot.sample()
## [/codeblock]


var _seed: int
var _streams: Dictionary[StringName, StdRandomStream] = {}


#region Engine Methods
# The seed is initialized before entering the tree so headless tests can
# instance the facade script directly.
func _init() -> void:
	var entropy: RandomNumberGenerator = RandomNumberGenerator.new()
	entropy.randomize()
	_seed = entropy.seed
	return
#endregion Engine Methods


#region Public API
## Sets the session seed and restarts every cached stream in place.
func set_seed(value: int) -> void:
	_seed = value
	for stream_name: StringName in _streams:
		_streams[stream_name].seed = _derive_seed(value, stream_name)
		pass
	return


## Chooses a new session seed from entropy and restarts cached streams.
func randomize_seed() -> void:
	var entropy: RandomNumberGenerator = RandomNumberGenerator.new()
	entropy.randomize()
	set_seed(entropy.seed)
	return


## The session seed from which every named stream is derived.
func get_seed() -> int:
	return _seed


## The cached stream for [param name]. Its seed depends only on the session
## seed and full name, never on lookup order. Any [StringName], including an
## empty one, is a valid explicit stream key.
func stream(name: StringName) -> StdRandomStream:
	if _streams.has(name):
		return _streams[name]
	var created: StdRandomStream = StdRandomStream.new()
	created.seed = _derive_seed(_seed, name)
	_streams[name] = created
	return created
#endregion Public API


#region Private Helpers
# SHA-256 provides an avalanche before the seed reaches Godot's PCG generator.
static func _derive_seed(value: int, stream_name: StringName) -> int:
	var source: String = "%d:%s" % [value, stream_name]
	return source.sha256_buffer().decode_s64(0)
#endregion Private Helpers
