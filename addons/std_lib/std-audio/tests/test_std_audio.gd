extends StdTest
## Headless tests for the public StdAudio service.
## Run: godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-audio


const SERVICE_PATH: String = "res://addons/std_lib/std-audio/scripts/std_audio.gd"


func _make_service() -> Node:
	var script: GDScript = load(SERVICE_PATH)
	var service: Node = script.new()
	return add_to_tree(service)


func _make_stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var data: PackedByteArray = PackedByteArray()
	data.resize(8000)
	stream.data = data
	return stream


func _make_recipe(
		id: StringName = &"sfx",
		volume_db: float = 0.0,
) -> StdAudioRecipe:
	var recipe: StdAudioRecipe = StdAudioRecipe.new()
	recipe.id = id
	recipe.stream = _make_stream()
	recipe.volume_db = volume_db
	return recipe


func _make_recipe_2d(id: StringName = &"sfx_2d") -> StdAudioRecipe2D:
	var recipe: StdAudioRecipe2D = StdAudioRecipe2D.new()
	recipe.id = id
	recipe.stream = _make_stream()
	return recipe


func _make_recipe_3d(id: StringName = &"sfx_3d") -> StdAudioRecipe3D:
	var recipe: StdAudioRecipe3D = StdAudioRecipe3D.new()
	recipe.id = id
	recipe.stream = _make_stream()
	return recipe


func _global_player(service: Node) -> AudioStreamPlayer:
	for child: Node in service.get_children():
		if child is AudioStreamPlayer: return child
	return null


func _player_2d(service: Node) -> AudioStreamPlayer2D:
	for child: Node in service.get_children():
		if child is AudioStreamPlayer2D: return child
	return null


func _player_3d(service: Node) -> AudioStreamPlayer3D:
	for child: Node in service.get_children():
		if child is AudioStreamPlayer3D: return child
	return null


func _teardown(service: Node) -> void:
	service.stop_all()
	return


func _test_registry_replaces_and_revokes() -> void:
	var service: Node = _make_service()
	var original: StdAudioRecipe = _make_recipe(&"impact")
	var replacement: StdAudioRecipe = _make_recipe(&"impact", -6.0)

	var registered: StdResult = service.register(original)
	assert_ok(registered, "valid recipe registers")
	assert_eq(registered.unwrap(), original, "register returns recipe")
	assert_ok(service.register(replacement), "same id replaces")
	assert_eq(service.fetch(&"impact").unwrap(), replacement, "replacement is stored")
	assert_true(service.fetch(&"missing").is_none(), "unknown id is none")

	var revoked: StdOption = service.revoke(&"impact")
	assert_eq(revoked.unwrap(), replacement, "revoke returns recipe")
	assert_true(service.fetch(&"impact").is_none(), "revoked recipe is absent")
	assert_true(service.revoke(&"impact").is_none(), "second revoke is none")
	_teardown(service)
	return


func _test_register_all_is_atomic() -> void:
	var service: Node = _make_service()
	var global: StdAudioRecipe = _make_recipe(&"global")
	var recipe_2d: StdAudioRecipe2D = _make_recipe_2d(&"positional_2d")
	var recipe_3d: StdAudioRecipe3D = _make_recipe_3d(&"positional_3d")
	var batch: Array[StdAudioRecipe] = [global, recipe_2d, recipe_3d]

	var registered: StdResult = service.register_all(batch)
	assert_ok(registered, "valid mixed batch registers")
	assert_eq(registered.unwrap(), 3, "batch reports stored count")
	assert_eq(service.fetch(&"positional_2d").unwrap(), recipe_2d, "2D recipe stored")

	var duplicates: Array[StdAudioRecipe] = [
		_make_recipe(&"duplicate"),
		_make_recipe_2d(&"duplicate"),
	]
	assert_err(service.register_all(duplicates), "duplicate batch id errs")
	assert_true(service.fetch(&"duplicate").is_none(), "duplicate batch changes nothing")

	var invalid: StdAudioRecipe = _make_recipe(&"invalid")
	invalid.stream = null
	var partly_invalid: Array[StdAudioRecipe] = [
		_make_recipe(&"would_be_new"),
		invalid,
	]
	assert_err(service.register_all(partly_invalid), "invalid batch errs")
	assert_true(service.fetch(&"would_be_new").is_none(), "invalid batch is atomic")
	assert_ok(service.register_all([] as Array[StdAudioRecipe]), "empty batch is valid")
	_teardown(service)
	return


func _test_global_play_configures_releases_and_reuses() -> void:
	var service: Node = _make_service()
	assert_ok(service.configure_pools(1, 1, 1), "small pools configure")
	var recipe: StdAudioRecipe = _make_recipe(&"music", -6.0)
	var played: StdResult = service.play(recipe)
	assert_ok(played, "global recipe plays")
	var handle: StdAudioHandle = played.unwrap()
	var player: AudioStreamPlayer = _global_player(service)

	assert_eq(player.stream, recipe.stream, "stream applied")
	assert_eq(player.bus, &"Master", "bus applied")
	assert_eq(player.volume_db, -6.0, "volume applied")
	assert_err(service.play(recipe), "full global pool rejects another playback")
	assert_ok(handle.stop(), "handle releases global player")
	assert_true(not handle.is_active(), "stopped handle is inactive")
	assert_err(handle.stop(), "double stop errs")
	assert_ok(service.play(recipe), "released global player is reusable")
	_teardown(service)
	return


func _test_natural_finish_releases_and_notifies() -> void:
	var service: Node = _make_service()
	var handle: StdAudioHandle = service.play(_make_recipe()).unwrap()
	var notifications: Array[bool] = []
	var error: Error = handle.finished.connect(func() -> void: notifications.append(true))
	assert_eq(error, OK, "handle signal connects")

	_global_player(service).finished.emit()
	assert_true(not handle.is_active(), "natural finish invalidates handle")
	assert_eq(notifications.size(), 1, "natural finish emits handle signal")
	assert_err(handle.stop(), "naturally finished handle cannot stop")
	assert_ok(service.play(_make_recipe()), "naturally released slot is reusable")
	_teardown(service)
	return


func _test_play_2d_applies_position_and_distance() -> void:
	var service: Node = _make_service()
	var recipe: StdAudioRecipe2D = _make_recipe_2d()
	recipe.max_distance = 250.0
	recipe.volume_db = -3.0

	var played: StdResult = service.play_2d(recipe, Vector2(10, 20))
	assert_ok(played, "2D recipe plays")
	var player: AudioStreamPlayer2D = _player_2d(service)
	assert_eq(player.stream, recipe.stream, "2D stream applied")
	assert_eq(player.position, Vector2(10, 20), "2D position applied")
	assert_eq(player.max_distance, 250.0, "2D max distance applied")
	assert_eq(player.volume_db, -3.0, "2D volume applied")
	assert_ok(played.unwrap().stop(), "2D handle stops")
	_teardown(service)
	return


func _test_play_3d_applies_position_and_distance() -> void:
	var service: Node = _make_service()
	var recipe: StdAudioRecipe3D = _make_recipe_3d()
	recipe.max_distance = 500.0
	recipe.volume_db = -9.0

	var played: StdResult = service.play_3d(recipe, Vector3(1, 2, 3))
	assert_ok(played, "3D recipe plays")
	var player: AudioStreamPlayer3D = _player_3d(service)
	assert_eq(player.stream, recipe.stream, "3D stream applied")
	assert_eq(player.position, Vector3(1, 2, 3), "3D position applied")
	assert_eq(player.max_distance, 500.0, "3D max distance applied")
	assert_eq(player.volume_db, -9.0, "3D volume applied")
	assert_ok(played.unwrap().stop(), "3D handle stops")
	_teardown(service)
	return


func _test_playback_by_id_checks_recipe_type() -> void:
	var service: Node = _make_service()
	var recipes: Array[StdAudioRecipe] = [
		_make_recipe(&"global"),
		_make_recipe_2d(&"positional_2d"),
		_make_recipe_3d(&"positional_3d"),
	]
	assert_ok(service.register_all(recipes), "recipes register")

	assert_ok(service.play_id(&"global"), "global id plays")
	assert_ok(service.play_2d_id(&"positional_2d", Vector2.ZERO), "2D id plays")
	assert_ok(service.play_3d_id(&"positional_3d", Vector3.ZERO), "3D id plays")
	assert_err(service.play_id(&"positional_2d"), "global play rejects 2D recipe")
	assert_err(service.play_2d_id(&"global", Vector2.ZERO), "2D play rejects global recipe")
	assert_err(service.play_3d_id(&"positional_2d", Vector3.ZERO), "3D play rejects 2D recipe")
	assert_err(service.play_id(&"missing"), "missing id errs")
	_teardown(service)
	return


func _test_validation_rejects_bad_input() -> void:
	var service: Node = _make_service()
	assert_err(service.play(null), "null global recipe errs")
	assert_err(service.play_2d(null, Vector2.ZERO), "null 2D recipe errs")
	assert_err(service.play_3d(null, Vector3.ZERO), "null 3D recipe errs")
	assert_err(service.play(_make_recipe_2d()), "global play rejects positional recipe")

	var no_stream: StdAudioRecipe = _make_recipe()
	no_stream.stream = null
	assert_err(service.play(no_stream), "missing stream errs")
	var no_bus: StdAudioRecipe = _make_recipe()
	no_bus.bus = &""
	assert_err(service.play(no_bus), "empty bus errs")
	var bad_bus: StdAudioRecipe = _make_recipe()
	bad_bus.bus = &"missing_test_bus"
	assert_err(service.play(bad_bus), "unknown bus errs")
	var bad_volume: StdAudioRecipe = _make_recipe()
	bad_volume.volume_db = NAN
	assert_err(service.play(bad_volume), "non-finite volume errs")

	var bad_distance_2d: StdAudioRecipe2D = _make_recipe_2d()
	bad_distance_2d.max_distance = 0.0
	assert_err(service.play_2d(bad_distance_2d, Vector2.ZERO), "non-positive 2D distance errs")
	var bad_distance_3d: StdAudioRecipe3D = _make_recipe_3d()
	bad_distance_3d.max_distance = INF
	assert_err(service.play_3d(bad_distance_3d, Vector3.ZERO), "non-finite 3D distance errs")
	assert_err(service.play_2d(_make_recipe_2d(), Vector2(INF, 0)), "non-finite 2D position errs")
	assert_err(service.play_3d(_make_recipe_3d(), Vector3(0, NAN, 0)), "non-finite 3D position errs")

	var unidentified: StdAudioRecipe = _make_recipe(&"")
	assert_err(service.register(unidentified), "registration requires id")
	assert_err(service.register(null), "registration rejects null")

	var script: GDScript = load(SERVICE_PATH)
	var off_tree: Node = script.new()
	assert_err(off_tree.play(_make_recipe()), "off-tree playback errs")
	off_tree.free()
	_teardown(service)
	return


func _test_pool_configuration_and_exhaustion() -> void:
	var service: Node = _make_service()
	assert_err(service.configure_pools(-1, 1, 1), "negative capacity errs")
	assert_ok(service.configure_pools(0, 1, 1), "zero capacity configures")
	var disabled: StdResult = service.play(_make_recipe())
	assert_err(disabled, "zero disables global playback")
	assert_true(String(disabled.unwrap_err()).contains("0/0"), "error reports capacity")
	assert_ok(service.configure_pools(1, 1, 1), "failed playback does not lock pools")

	var handle: StdAudioHandle = service.play(_make_recipe()).unwrap()
	assert_err(service.configure_pools(2, 2, 2), "successful playback locks pools")
	assert_ok(handle.stop(), "configured playback stops")
	_teardown(service)
	return


func _test_stop_all_releases_every_dimension() -> void:
	var service: Node = _make_service()
	var global: StdAudioHandle = service.play(_make_recipe()).unwrap()
	var handle_2d: StdAudioHandle = service.play_2d(
			_make_recipe_2d(), Vector2.ZERO).unwrap()
	var handle_3d: StdAudioHandle = service.play_3d(
			_make_recipe_3d(), Vector3.ZERO).unwrap()
	var notifications: Array[bool] = []
	var error: Error = global.finished.connect(func() -> void: notifications.append(true))
	assert_eq(error, OK, "handle signal connects")

	assert_eq(service.stop_all(), 3, "stop_all reports every playback")
	assert_true(not global.is_active(), "global handle invalidated")
	assert_true(not handle_2d.is_active(), "2D handle invalidated")
	assert_true(not handle_3d.is_active(), "3D handle invalidated")
	assert_eq(notifications.size(), 0, "stop_all is silent")
	assert_eq(service.stop_all(), 0, "second stop_all has nothing to stop")
	_teardown(service)
	return
