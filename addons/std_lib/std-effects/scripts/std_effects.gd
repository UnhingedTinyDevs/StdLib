extends Node
## StdEffects service facade for the std-effects module
##
## Owned by the [code]StdLib[/code] autoload and available as
## [code]StdEffects[/code] when the plugin is enabled. Thin facade over an [code]StdEffectPlayer[/code] (pooled
## playback) and an [code]StdEffectBook[/code] (recipe registry) instanced as
## children. Play a recipe directly with [method play],
## [method play_oneshot], or [method play_on], or register it once and
## play it anywhere by id with the [code]*_id[/code] variants.
## [codeblock]
## var rv: StdResult = StdEffects.play_oneshot(burst_recipe, position)
## if rv.is_err(): push_warning(rv.unwrap_err())
## [/codeblock]


var _player: StdEffectPlayer
var _book: StdEffectBook


#region Engine Methods
# Children are created in _init so the facade works before entering
# the tree (headless tests instance this script directly).
func _init() -> void:
	_player = StdEffectPlayer.new()
	_player.name = "StdEffectPlayer"
	add_child(_player)
	_book = StdEffectBook.new()
	_book.name = "StdEffectBook"
	add_child(_book)
	return
#endregion Engine Methods


#region Public API
## Sets the fixed sprite, particle, and shader pool capacities before
## first valid playback. See [code]StdEffectPlayer.configure_pools[/code].
func configure_pools(
		sprite_size: int = StdEffectPlayer.DEFAULT_SPRITE_POOL_SIZE,
		particle_size: int = StdEffectPlayer.DEFAULT_PARTICLE_POOL_SIZE,
		shader_size: int = StdEffectPlayer.DEFAULT_SHADER_POOL_SIZE,
) -> StdResult:
	return _player.configure_pools(sprite_size, particle_size, shader_size)


## Plays a managed (non one-shot) sprite recipe at [param pos]. On
## success the ok value is an [code]StdEffectHandle[/code] for [method stop].
## See [code]StdEffectPlayer.play[/code].
func play(recipe: StdEffectRecipeInterface, pos: Vector2 = Vector2.ZERO) -> StdResult:
	return _player.play(recipe, pos)


## Plays a one-shot sprite or particle recipe fire-and-forget: no
## handle is returned and the pooled node releases itself when the
## effect finishes. See [code]StdEffectPlayer.play_oneshot[/code].
func play_oneshot(recipe: StdEffectRecipeInterface, pos: Vector2 = Vector2.ZERO) -> StdResult:
	return _player.play_oneshot(recipe, pos)


## Runs a shader recipe on [param target], restoring its original
## material afterwards. The ok value is an [code]StdEffectHandle[/code]. See
## [code]StdEffectPlayer.play_on[/code].
func play_on(recipe: StdEffectRecipeInterface, target: CanvasItem) -> StdResult:
	return _player.play_on(recipe, target)


## Plays the managed recipe registered under [param id]. Errs when no
## recipe is registered with that id, otherwise behaves like
## [method play].
func play_id(id: StringName, pos: Vector2 = Vector2.ZERO) -> StdResult:
	var fetched: StdOption = _book.fetch(id)
	if fetched.is_none():
		return StdResult.err("no recipe registered with id '%s'" % id)
	return _player.play(fetched.unwrap(), pos)


## Plays the one-shot recipe registered under [param id]. Errs when no
## recipe is registered with that id, otherwise behaves like
## [method play_oneshot].
func play_oneshot_id(id: StringName, pos: Vector2 = Vector2.ZERO) -> StdResult:
	var fetched: StdOption = _book.fetch(id)
	if fetched.is_none():
		return StdResult.err("no recipe registered with id '%s'" % id)
	return _player.play_oneshot(fetched.unwrap(), pos)


## Runs the shader recipe registered under [param id] on
## [param target]. Errs when no recipe is registered with that id,
## otherwise behaves like [method play_on].
func play_on_id(id: StringName, target: CanvasItem) -> StdResult:
	var fetched: StdOption = _book.fetch(id)
	if fetched.is_none():
		return StdResult.err("no recipe registered with id '%s'" % id)
	return _player.play_on(fetched.unwrap(), target)


## Registers a recipe for the [code]*_id[/code] variants. See
## [code]StdEffectBook.register[/code].
func register(recipe: StdEffectRecipeInterface) -> StdResult:
	return _book.register(recipe)


## Registers every recipe in [param recipes] that is not already registered,
## and reports how many were added. The [code]StdAudio.register_all[/code] of effects —
## see there for why skipping duplicates is the whole point.
##
## Errs on the first recipe that fails to register, naming it.
## [codeblock]
## var _rv: StdResult = StdEffects.register_all(EFFECT_RECIPES).warn("python")
## [/codeblock]
func register_all(recipes: Array[StdEffectRecipeInterface]) -> StdResult:
	var added: int = 0
	for recipe: StdEffectRecipeInterface in recipes:
		if recipe == null:
			return StdResult.err("register_all stopped at <null>: recipe is null")
		var id: StdOption = recipe.id()
		if id.is_some_and(func(value: StringName) -> bool: return fetch(value).is_some()):
			continue
		var rv: StdResult = register(recipe)
		if rv.is_err():
			return rv.map_err(func(e: Variant) -> Variant:
					return "register_all stopped at %s: %s" % [id.unwrap_or(&"<no id>"), e])
		added += 1
	return StdResult.ok(added)


## Fetches a registered recipe by id. See [code]StdEffectBook.fetch[/code].
func fetch(id: StringName) -> StdOption:
	return _book.fetch(id)


## Removes and returns a registered recipe. See
## [code]StdEffectBook.revoke[/code].
func revoke(id: StringName) -> StdOption:
	return _book.revoke(id)


## Stops a handle returned by [method play] or [method play_on] and
## returns its private node to its pool. Calling
## [code]StdEffectHandle.stop[/code] is equivalent.
func stop(handle: StdEffectHandle) -> StdResult:
	return _player.stop(handle)


## Stops every active pooled effect. See
## [code]StdEffectPlayer.stop_all[/code].
func stop_all() -> void:
	_player.stop_all()
	return
#endregion Public API
