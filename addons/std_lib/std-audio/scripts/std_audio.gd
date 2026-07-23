extends Node
## StdAudio service facade for the std-audio module
##
## Owned by the [code]StdLib[/code] autoload and available as
## [code]StdAudio[/code] when the plugin is enabled. Thin facade over an [code]StdAudioPlayer[/code] (pooled
## playback) and an [code]StdAudioBook[/code] (recipe registry) instanced as
## children. Play a recipe directly with [method play], or register it
## once and play it anywhere by id with [method play_id].
## [codeblock]
## var rv: StdResult = StdAudio.play(recipe)
## if rv.is_err(): push_warning(rv.unwrap_err())
## [/codeblock]


var _player: StdAudioPlayer
var _book: StdAudioBook


#region Engine Methods
# Children are created in _init so the facade works before entering
# the tree (headless tests instance this script directly).
func _init() -> void:
	_player = StdAudioPlayer.new()
	_player.name = "StdAudioPlayer"
	add_child(_player)
	_book = StdAudioBook.new()
	_book.name = "StdAudioBook"
	add_child(_book)
	return
#endregion Engine Methods


#region Public API
## Sets the fixed global, 2D, and 3D pool capacities before first
## playback. See [code]StdAudioPlayer.configure_pools[/code].
func configure_pools(
		global_size: int = StdAudioPlayer.DEFAULT_GLOBAL_POOL_SIZE,
		pool_2d_size: int = StdAudioPlayer.DEFAULT_2D_POOL_SIZE,
		pool_3d_size: int = StdAudioPlayer.DEFAULT_3D_POOL_SIZE,
) -> StdResult:
	return _player.configure_pools(global_size, pool_2d_size, pool_3d_size)


## Plays a managed (non one-shot) recipe on a pooled player. On
## success the ok value is an [code]StdAudioHandle[/code] for [method stop].
## Errs on one_shot recipes, use [method play_oneshot] for those.
## See [code]StdAudioPlayer.play[/code].
func play(recipe: StdAudioRecipe) -> StdResult:
	return _player.play(recipe)


## Plays a one-shot recipe fire-and-forget: no handle is returned and
## the player releases itself when the stream finishes. Errs on non
## one-shot recipes and on looping streams.
## See [code]StdAudioPlayer.play_oneshot[/code].
func play_oneshot(recipe: StdAudioRecipe) -> StdResult:
	return _player.play_oneshot(recipe)


## Plays the managed recipe registered under [param id]. Errs when no
## recipe is registered with that id, otherwise behaves like
## [method play].
func play_id(id: StringName) -> StdResult:
	var fetched: StdOption = _book.fetch(id)
	if fetched.is_none():
		return StdResult.err("no recipe registered with id '%s'" % id)
	return _player.play(fetched.unwrap())


## Plays the one-shot recipe registered under [param id]. Errs when no
## recipe is registered with that id, otherwise behaves like
## [method play_oneshot].
func play_oneshot_id(id: StringName) -> StdResult:
	var fetched: StdOption = _book.fetch(id)
	if fetched.is_none():
		return StdResult.err("no recipe registered with id '%s'" % id)
	return _player.play_oneshot(fetched.unwrap())


## Registers a recipe for [method play_id]. See [code]StdAudioBook.register[/code].
func register(recipe: StdAudioRecipe) -> StdResult:
	return _book.register(recipe)


## Registers every recipe in [param recipes] that is not already registered,
## and reports how many were added.
##
## Skipping what the book already holds is the point: a game registers its
## recipes on load, and reloading its scene (a restart) runs that again. Plain
## [method register] would warn on every duplicate id, so callers all grew the
## same fetch-then-register loop — this is that loop, once.
##
## Errs on the first recipe that fails to register, naming it. A recipe with no
## id is not registrable and counts as a failure.
## [codeblock]
## var _rv: StdResult = StdAudio.register_all(AUDIO_RECIPES).warn("python")
## [/codeblock]
func register_all(recipes: Array[StdAudioRecipe]) -> StdResult:
	var added: int = 0
	for recipe: StdAudioRecipe in recipes:
		var id: StdOption = recipe.id()
		if id.is_some_and(func(value: StringName) -> bool: return fetch(value).is_some()):
			continue
		var rv: StdResult = register(recipe)
		if rv.is_err():
			return rv.map_err(func(e: Variant) -> Variant:
					return "register_all stopped at %s: %s" % [id.unwrap_or(&"<no id>"), e])
		added += 1
	return StdResult.ok(added)


## Fetches a registered recipe by id. See [code]StdAudioBook.fetch[/code].
func fetch(id: StringName) -> StdOption:
	return _book.fetch(id)


## Removes and returns a registered recipe. See [code]StdAudioBook.revoke[/code].
func revoke(id: StringName) -> StdOption:
	return _book.revoke(id)


## Stops a handle returned by [method play] and returns its player to
## the pool. Calling [code]StdAudioHandle.stop[/code] is equivalent.
func stop(handle: StdAudioHandle) -> StdResult:
	return _player.stop(handle)


## Stops every active pooled player. See [code]StdAudioPlayer.stop_all[/code].
func stop_all() -> void:
	_player.stop_all()
	return
#endregion Public API
