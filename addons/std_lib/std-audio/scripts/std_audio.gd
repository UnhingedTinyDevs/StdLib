extends Node
## Pooled audio service for global, 2D, and 3D streams.
##
## Register reusable [StdAudioRecipe] resources by id or play them directly.
## Every successful playback returns a [StdAudioHandle]. Ignoring that handle
## gives fire-and-forget behavior; retaining it allows explicit stopping.


## Default number of simultaneous global streams.
const DEFAULT_GLOBAL_POOL_SIZE: int = 16
## Default number of simultaneous 2D streams.
const DEFAULT_2D_POOL_SIZE: int = 32
## Default number of simultaneous 3D streams.
const DEFAULT_3D_POOL_SIZE: int = 32

enum _PlayerKind { GLOBAL, D2, D3 }


class _Playback:
	extends RefCounted

	var player: Node
	var pool: StdObjectPool
	var handle: StdAudioHandle

	func _init(player_node: Node, owner_pool: StdObjectPool, audio_handle: StdAudioHandle) -> void:
		player = player_node
		pool = owner_pool
		handle = audio_handle
		return


var _recipes: Dictionary[StringName, StdAudioRecipe] = {}
var _playbacks: Dictionary[int, _Playback] = {}
var _global_pool: StdObjectPool
var _pool_2d: StdObjectPool
var _pool_3d: StdObjectPool
var _playback_started: bool = false


#region Engine Methods
func _init() -> void:
	_global_pool = StdObjectPool.new(
			_new_player.bind(_PlayerKind.GLOBAL), DEFAULT_GLOBAL_POOL_SIZE, 0, _reset_player)
	_pool_2d = StdObjectPool.new(
			_new_player.bind(_PlayerKind.D2), DEFAULT_2D_POOL_SIZE, 0, _reset_player)
	_pool_3d = StdObjectPool.new(
			_new_player.bind(_PlayerKind.D3), DEFAULT_3D_POOL_SIZE, 0, _reset_player)
	return


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop_all()
	return
#endregion Engine Methods


#region Public API
## Sets the fixed global, 2D, and 3D pool capacities. Call before the
## first successful playback. Zero disables a category. Errs without
## changing the pools when a capacity is negative or playback has started.
func configure_pools(
		global_capacity: int = DEFAULT_GLOBAL_POOL_SIZE,
		capacity_2d: int = DEFAULT_2D_POOL_SIZE,
		capacity_3d: int = DEFAULT_3D_POOL_SIZE,
) -> StdResult:
	if _playback_started:
		return StdResult.err("audio pool capacities cannot change after playback starts")
	if global_capacity < 0 or capacity_2d < 0 or capacity_3d < 0:
		return StdResult.err("audio pool capacities cannot be negative")
	_global_pool = StdObjectPool.new(
			_new_player.bind(_PlayerKind.GLOBAL), global_capacity, 0, _reset_player)
	_pool_2d = StdObjectPool.new(
			_new_player.bind(_PlayerKind.D2), capacity_2d, 0, _reset_player)
	_pool_3d = StdObjectPool.new(
			_new_player.bind(_PlayerKind.D3), capacity_3d, 0, _reset_player)
	return StdResult.ok(true)


## Registers [param recipe] by [member StdAudioRecipe.id]. An existing recipe
## with the same id is replaced. The ok value is the registered recipe.
func register(recipe: StdAudioRecipe) -> StdResult:
	var valid: StdResult = _validate_registration(recipe)
	if valid.is_err(): return valid
	_recipes[recipe.id] = recipe
	return StdResult.ok(recipe)


## Atomically validates and registers every recipe. Existing registry entries
## are replaced, but duplicate ids within [param recipes] err. The ok value is
## the number stored.
func register_all(recipes: Array[StdAudioRecipe]) -> StdResult:
	var pending: Dictionary[StringName, StdAudioRecipe] = {}
	for recipe: StdAudioRecipe in recipes:
		var valid: StdResult = _validate_registration(recipe)
		if valid.is_err(): return valid
		if pending.has(recipe.id):
			return StdResult.err("register_all contains duplicate id '%s'" % recipe.id)
		pending[recipe.id] = recipe
		pass
	for id: StringName in pending:
		_recipes[id] = pending[id]
		pass
	return StdResult.ok(pending.size())


## Returns the recipe registered under [param id], or [StdOption] none.
func fetch(id: StringName) -> StdOption:
	var recipe: StdAudioRecipe = _recipes.get(id)
	if recipe == null: return StdOption.none()
	return StdOption.some(recipe)


## Removes and returns the recipe registered under [param id], or
## [StdOption] none.
func revoke(id: StringName) -> StdOption:
	var recipe: StdAudioRecipe = _recipes.get(id)
	if recipe == null: return StdOption.none()
	_recipes.erase(id)
	return StdOption.some(recipe)


## Plays a global recipe. The ok value is a [StdAudioHandle].
func play(recipe: StdAudioRecipe) -> StdResult:
	if not is_inside_tree(): return StdResult.err("StdAudio must be inside the scene tree")
	if recipe == null: return StdResult.err("audio recipe is null")
	if recipe is StdAudioRecipe2D or recipe is StdAudioRecipe3D:
		return StdResult.err("positional recipes require play_2d() or play_3d()")
	
	var valid: StdResult = _validate_recipe(recipe)
	if valid.is_err(): return valid
	
	var acquired: StdResult = _acquire(_global_pool, "global")
	if acquired.is_err(): return acquired
	
	var player: AudioStreamPlayer = acquired.unwrap()
	player.stream = recipe.stream
	player.bus = recipe.bus
	player.volume_db = recipe.volume_db
	return _start(player, _global_pool)


## Fetches and plays a global recipe registered under [param id].
func play_id(id: StringName) -> StdResult:
	var recipe: StdOption = fetch(id)
	if recipe.is_none(): return StdResult.err("no audio recipe registered with id '%s'" % id)
	return play(recipe.unwrap())


## Plays [param recipe] at [param position] in 2D. The ok value is a
## [StdAudioHandle].
func play_2d(recipe: StdAudioRecipe2D, position: Vector2) -> StdResult:
	if not is_inside_tree(): return StdResult.err("StdAudio must be inside the scene tree")
	if recipe == null: return StdResult.err("2D audio recipe is null")
	if not position.is_finite(): return StdResult.err("2D audio position must be finite")
	
	var valid: StdResult = _validate_recipe(recipe)
	if valid.is_err(): return valid
	
	var acquired: StdResult = _acquire(_pool_2d, "2D")
	if acquired.is_err(): return acquired
	
	var player: AudioStreamPlayer2D = acquired.unwrap()
	player.stream = recipe.stream
	player.bus = recipe.bus
	player.volume_db = recipe.volume_db
	player.position = position
	player.max_distance = recipe.max_distance
	return _start(player, _pool_2d)


## Fetches and plays a 2D recipe registered under [param id].
func play_2d_id(id: StringName, position: Vector2) -> StdResult:
	var recipe: StdOption = fetch(id)
	if recipe.is_none(): return StdResult.err("no audio recipe registered with id '%s'" % id)
	var value: Variant = recipe.unwrap()
	if value is not StdAudioRecipe2D:
		return StdResult.err("audio recipe '%s' is not a 2D recipe" % id)
	return play_2d(value, position)


## Plays [param recipe] at [param position] in 3D. The ok value is a
## [StdAudioHandle].
func play_3d(recipe: StdAudioRecipe3D, position: Vector3) -> StdResult:
	if not is_inside_tree(): return StdResult.err("StdAudio must be inside the scene tree")
	if recipe == null: return StdResult.err("3D audio recipe is null")
	if not position.is_finite(): return StdResult.err("3D audio position must be finite")
	var valid: StdResult = _validate_recipe(recipe)
	if valid.is_err(): return valid
	var acquired: StdResult = _acquire(_pool_3d, "3D")
	if acquired.is_err(): return acquired
	var player: AudioStreamPlayer3D = acquired.unwrap()
	player.stream = recipe.stream
	player.bus = recipe.bus
	player.volume_db = recipe.volume_db
	player.position = position
	player.max_distance = recipe.max_distance
	return _start(player, _pool_3d)


## Fetches and plays a 3D recipe registered under [param id].
func play_3d_id(id: StringName, position: Vector3) -> StdResult:
	var recipe: StdOption = fetch(id)
	if recipe.is_none(): return StdResult.err("no audio recipe registered with id '%s'" % id)
	var value: Variant = recipe.unwrap()
	if value is not StdAudioRecipe3D:
		return StdResult.err("audio recipe '%s' is not a 3D recipe" % id)
	return play_3d(value, position)


## Stops every active playback and returns the number stopped. Explicit
## stopping invalidates handles without emitting [signal StdAudioHandle.finished].
func stop_all() -> int:
	var ids: Array[int] = []
	ids.assign(_playbacks.keys())
	var stopped: int = 0
	for id: int in ids:
		var playback: _Playback = _playbacks.get(id)
		if playback == null: continue
		if is_instance_valid(playback.player):
			playback.player.call(&"stop")
		var released: StdResult = _release(id, false)
		if released.is_ok(): stopped += 1
		pass
	return stopped
#endregion Public API


#region Signal Handlers
func _on_finished(player: Node) -> void:
	var id: int = player.get_instance_id()
	if not _playbacks.has(id): return
	var _released: StdResult = _release(id, true).inspect_err(
			func(error: Variant) -> void:
				push_warning("StdAudio auto-release failed: %s" % error)
				return)
	return
#endregion Signal Handlers


#region Private Helpers
func _validate_registration(recipe: StdAudioRecipe) -> StdResult:
	if recipe == null: return StdResult.err("audio recipe is null")
	if recipe.id == &"": return StdResult.err("audio recipe has no id")
	return _validate_recipe(recipe)


func _validate_recipe(recipe: StdAudioRecipe) -> StdResult:
	var label: StringName = recipe.id if recipe.id != &"" else &"<unregistered>"
	if recipe.stream == null: return StdResult.err("audio recipe '%s' has no stream" % label)
	if recipe.bus == &"": return StdResult.err("audio recipe '%s' has no bus" % label)
	if AudioServer.get_bus_index(recipe.bus) < 0:
		return StdResult.err("audio recipe '%s' uses unknown bus '%s'" % [label, recipe.bus])
	if not is_finite(recipe.volume_db):
		return StdResult.err("audio recipe '%s' volume_db must be finite" % label)
	if recipe is StdAudioRecipe2D:
		if not is_finite(recipe.max_distance) or recipe.max_distance <= 0.0:
			return StdResult.err("audio recipe '%s' max_distance must be positive" % label)
	elif recipe is StdAudioRecipe3D:
		if not is_finite(recipe.max_distance) or recipe.max_distance <= 0.0:
			return StdResult.err("audio recipe '%s' max_distance must be positive" % label)
	return StdResult.ok(true)


func _acquire(pool: StdObjectPool, label: String) -> StdResult:
	var acquired: StdResult = pool.acquire()
	if acquired.is_ok(): return acquired
	if pool.is_exhausted():
		return StdResult.err(
				"%s audio pool exhausted (%d/%d active)"
				% [label, pool.active_count(), pool.capacity()])
	return StdResult.err("%s audio player unavailable: %s" % [label, acquired.unwrap_err()])


func _start(player: Node, pool: StdObjectPool) -> StdResult:
	add_child(player)
	var id: int = player.get_instance_id()
	var handle: StdAudioHandle = StdAudioHandle.new(self, id)
	_playbacks[id] = _Playback.new(player, pool, handle)
	_playback_started = true
	player.call(&"play")
	return StdResult.ok(handle)


func _release(id: int, natural_finish: bool) -> StdResult:
	var playback: _Playback = _playbacks.get(id)
	if playback == null: return StdResult.err("audio playback is no longer active")
	if not is_instance_valid(playback.player):
		_playbacks.erase(id)
		playback.handle._invalidate(false)
		return StdResult.err("audio player no longer exists")
	var released: StdResult = playback.pool.release(playback.player)
	if released.is_err(): return released
	_playbacks.erase(id)
	playback.handle._invalidate(natural_finish)
	return StdResult.ok(true)


# Called only by StdAudioHandle.
func _stop_from_handle(handle: StdAudioHandle) -> StdResult:
	if handle == null or not handle.is_active():
		return StdResult.err("audio playback is no longer active")
	var playback: _Playback = _playbacks.get(handle._playback_id)
	if playback == null or playback.handle != handle:
		return StdResult.err("audio handle is not owned by StdAudio")
	playback.player.call(&"stop")
	return _release(handle._playback_id, false)


func _new_player(kind: _PlayerKind) -> Node:
	var player: Node
	match kind:
		_PlayerKind.D2:
			player = AudioStreamPlayer2D.new()
		_PlayerKind.D3:
			player = AudioStreamPlayer3D.new()
		_:
			player = AudioStreamPlayer.new()
	var error: Error = player.connect(&"finished", _on_finished.bind(player))
	if error != OK:
		push_error("StdAudio could not connect an audio player's finished signal")
		player.free()
		return null
	return player


func _reset_player(player: Node) -> void:
	player.call(&"stop")
	player.set(&"stream", null)
	return
#endregion Private Helpers
