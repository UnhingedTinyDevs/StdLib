class_name StdAudioPlayer
extends Node
## Pooled playback engine for [code]StdAudioRecipe[/code]s.
##
## Owns three [code]StdObjectPool[/code]s of stream players (global, 2D, 3D) and
## routes each recipe to a pool by [code]StdAudioRecipeInterface.dim[/code]. Managed
## playback returns an opaque [code]StdAudioHandle[/code]; pooled player nodes stay
## private children of this engine for their whole lifetime.


const DEFAULT_GLOBAL_POOL_SIZE: int = 16
const DEFAULT_2D_POOL_SIZE: int = 32
const DEFAULT_3D_POOL_SIZE: int = 32
## Godot rejects a positional max_distance of zero. This preserves
## zero-radius intent as the smallest valid origin-only distance.
const MIN_POSITIONAL_RADIUS: float = 0.0001

var _global_pool_size: int = DEFAULT_GLOBAL_POOL_SIZE
var _pool_2d_size: int = DEFAULT_2D_POOL_SIZE
var _pool_3d_size: int = DEFAULT_3D_POOL_SIZE

# pool of [AudioStreamPlayer]
var _global_player: StdObjectPool
# pool of [AudioStreamPlayer2D]
var _2d_player: StdObjectPool
# pool of [AudioStreamPlayer3D]
var _3d_player: StdObjectPool
# Active managed handles keyed by their pooled player's instance id.
var _handles: Dictionary[int, StdAudioHandle] = {}


#region Public API
## Sets the fixed pool capacities. Call this before the first valid
## playback; pools are built lazily when playback first acquires a
## player. Zero disables a dimension. Errs without changing any size
## when a value is negative or a pool has already been built.
func configure_pools(
		global_size: int = DEFAULT_GLOBAL_POOL_SIZE,
		pool_2d_size: int = DEFAULT_2D_POOL_SIZE,
		pool_3d_size: int = DEFAULT_3D_POOL_SIZE,
) -> StdResult:
	if _pools_are_built():
		return StdResult.err("audio pools are already built; configure them before first playback")
	if global_size < 0 or pool_2d_size < 0 or pool_3d_size < 0:
		return StdResult.err("audio pool capacities cannot be negative")
	_global_pool_size = global_size
	_pool_2d_size = pool_2d_size
	_pool_3d_size = pool_3d_size
	return StdResult.ok(true)


## Plays a managed (non one-shot) recipe on a pooled player picked by
## [code]StdAudioRecipeInterface.dim[/code]. On success the ok value is an
## [code]StdAudioHandle[/code]. Errs when the recipe is null, is one_shot (use
## [code]StdAudioPlayer.play_oneshot[/code]), has no stream, or its pool is
## exhausted.
func play(recipe: StdAudioRecipe) -> StdResult:
	if recipe == null: return StdResult.err("recipe is null")
	if recipe.one_shot:
		return StdResult.err("recipe '%s' is one_shot, use play_oneshot()"
				% recipe.id().unwrap_or(&"<no id>"))
	var played: StdResult = _acquire_and_play(recipe)
	if played.is_err(): return played
	var player: Node = played.unwrap()
	var handle: StdAudioHandle = StdAudioHandle.new(self, player.get_instance_id())
	_handles[player.get_instance_id()] = handle
	return StdResult.ok(handle)


## Plays a one-shot recipe fire-and-forget. Its pooled player returns
## to the pool when the stream finishes and no handle is returned (ok
## value is [code]true[/code]). Errs on null, managed, looping, empty,
## or exhausted recipes.
func play_oneshot(recipe: StdAudioRecipe) -> StdResult:
	if recipe == null: return StdResult.err("recipe is null")
	if not recipe.one_shot:
		return StdResult.err(
			"recipe '%s' is not one_shot" % recipe.id().unwrap_or(&"<no id>"))
	if recipe.is_looping():
		return StdResult.err(
			"recipe '%s' has a looping stream and would never release its player"
			% recipe.id().unwrap_or(&"<no id>"))
	var played: StdResult = _acquire_and_play(recipe)
	if played.is_err(): return played
	return StdResult.ok(true)


## Stops a managed [code]StdAudioHandle[/code] and returns its player to the pool.
## Errs when the handle is null, belongs to another [code]StdAudioPlayer[/code], or
## is already inactive.
func stop(handle: StdAudioHandle) -> StdResult:
	if handle == null: return StdResult.err("audio handle is null")
	if not handle.is_active(): return StdResult.err("audio playback is no longer active")
	if not _handles.has(handle._player_id) or _handles[handle._player_id] != handle:
		return StdResult.err("audio handle is not managed by this StdAudioPlayer")
	var player_value: Variant = instance_from_id(handle._player_id)
	if player_value is not Node:
		_handles.erase(handle._player_id)
		handle._invalidate(false)
		return StdResult.err("managed audio player no longer exists")
	var player: Node = player_value
	player.stop()
	return _release_player(player, false)


## Stops every active pooled playback and invalidates every managed
## handle. Explicit stops do not emit [code]StdAudioHandle.finished[/code].
func stop_all() -> void:
	if not _pools_are_built(): return
	for child: Node in get_children():
		var pool: StdObjectPool = _pool_for_node(child)
		if pool == null: continue
		child.stop()
		var _rv: StdResult = _release_player(child, false)
	return
#endregion Public API


#region Signal Handlers
# Every naturally finished stream releases. Managed playbacks also
# invalidate and notify their handle; one-shots have no handle.
func _on_player_finished(player: Node) -> void:
	var _rv: StdResult = _release_player(player, true).inspect_err(
			func(e: Variant) -> void: push_warning("StdAudio auto-release failed: %s" % e))
	return
#endregion Signal Handlers


#region Private Helpers
func _pools_are_built() -> bool:
	return _global_player != null or _2d_player != null or _3d_player != null


# Builds all pools atomically on first valid playback.
func _ensure_pools() -> void:
	if _pools_are_built(): return
	_global_player = StdObjectPool.new(_make_global, _global_pool_size, 0, _reset_player)
	_2d_player = StdObjectPool.new(_make_2d, _pool_2d_size, 0, _reset_player)
	_3d_player = StdObjectPool.new(_make_3d, _pool_3d_size, 0, _reset_player)
	return


# Validates, acquires, configures, and starts a pooled player. The ok
# value is private to this engine and is wrapped before managed play
# returns to a caller.
func _acquire_and_play(recipe: StdAudioRecipe) -> StdResult:
	var stream_opt: StdOption = recipe.stream()
	if stream_opt.is_none():
		return StdResult.err("recipe '%s' has no stream" % recipe.id().unwrap_or(&"<no id>"))
	var volume: float = recipe.volume().unwrap_or(0.0)
	if not is_finite(volume):
		return StdResult.err("recipe '%s' volume must be finite" % recipe.id().unwrap_or(&"<no id>"))
	if recipe is StdPositionalAudioRecipeInterface:
		var radius: float = (recipe as StdPositionalAudioRecipeInterface).radius().unwrap_or(0.0)
		if not is_finite(radius):
			return StdResult.err("recipe '%s' radius must be finite" % recipe.id().unwrap_or(&"<no id>"))
	_ensure_pools()
	var pool: StdObjectPool = _pool_for_dim(recipe.dim())
	var acquired: StdResult = pool.acquire()
	if acquired.is_err():
		var dim_name: String = StdAudioRecipeInterface.Dimension.keys()[recipe.dim()]
		if pool.is_exhausted():
			return StdResult.err(
					"%s audio pool exhausted (%d/%d active); call configure_pools() before first playback"
					% [dim_name, pool.active_count(), pool.capacity()])
		return StdResult.err("audio player unavailable for dimension %s: %s"
				% [dim_name, acquired.unwrap_err()])

	var player: Node = acquired.unwrap()
	if player.get_parent() == null:
		add_child(player)
	player.stream = stream_opt.unwrap()
	player.bus = recipe.bus().unwrap_or(&"Master")
	player.volume_linear = clampf(volume, 0.0, 100.0) / 100.0

	if recipe is StdPositionalAudioRecipeInterface:
		var pos_recipe: StdPositionalAudioRecipeInterface = recipe
		if player is AudioStreamPlayer2D:
			player.position = pos_recipe.pos().unwrap()
			player.max_distance = maxf(pos_recipe.radius().unwrap(), MIN_POSITIONAL_RADIUS)
		elif player is AudioStreamPlayer3D:
			player.position = pos_recipe.pos().unwrap()
			player.max_distance = maxf(pos_recipe.radius().unwrap(), MIN_POSITIONAL_RADIUS)
		else:
			pass

	if player.is_inside_tree():
		player.play()
	return StdResult.ok(player)


func _release_player(player: Node, natural_finish: bool) -> StdResult:
	var pool: StdObjectPool = _pool_for_node(player)
	if pool == null: return StdResult.err("not an audio stream player: %s" % player)
	var id: int = player.get_instance_id()
	var released: StdResult = pool.release(player)
	if released.is_err(): return released
	var value: Variant = true
	if _handles.has(id):
		var handle: StdAudioHandle = _handles[id]
		_handles.erase(id)
		handle._invalidate(natural_finish)
		value = handle
	return StdResult.ok(value)


func _pool_for_dim(dim: StdAudioRecipeInterface.Dimension) -> StdObjectPool:
	match dim:
		StdAudioRecipeInterface.Dimension.D2: return _2d_player
		StdAudioRecipeInterface.Dimension.D3: return _3d_player
		_: return _global_player


# AudioStreamPlayer2D/3D do not inherit AudioStreamPlayer, so the
# branches are independent. Returns null for non stream players.
func _pool_for_node(node: Node) -> StdObjectPool:
	if node is AudioStreamPlayer: return _global_player
	if node is AudioStreamPlayer2D: return _2d_player
	if node is AudioStreamPlayer3D: return _3d_player
	return null


func _make_global() -> Node:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	_adopt(player)
	return player


func _make_2d() -> Node:
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	_adopt(player)
	return player


func _make_3d() -> Node:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	_adopt(player)
	return player


# Pooled players stay children and keep this connection across reuse.
func _adopt(player: Node) -> void:
	add_child(player)
	var _e: int = player.finished.connect(_on_player_finished.bind(player))
	return


func _reset_player(player: Node) -> void:
	player.stop()
	player.stream = null
	return
#endregion Private Helpers
