extends StdTest
## Headless tests for StdAudioPlayer.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-audio


# The runner processes no frames and its root never enters the tree,
# so suites emit stream-player finished signals directly.
func _make_engine() -> StdAudioPlayer:
	var engine: StdAudioPlayer = StdAudioPlayer.new()
	var _configured: Variant = engine.configure_pools(1, 1, 1).unwrap()
	return engine


func _teardown(engine: StdAudioPlayer) -> void:
	engine.stop_all()
	engine.free()
	return


func _make_recipe(id: StringName = &"sfx", volume: float = 100.0, one_shot: bool = false) -> StdAudioRecipe:
	var recipe: StdAudioRecipe = StdAudioRecipe.new()
	recipe._id = id
	recipe._stream = AudioStreamWAV.new()
	recipe._volume = volume
	recipe.one_shot = one_shot
	return recipe


func _global_player(engine: StdAudioPlayer) -> AudioStreamPlayer:
	for child: Node in engine.get_children():
		if child is AudioStreamPlayer:
			return child
	return null


func _player_2d(engine: StdAudioPlayer) -> AudioStreamPlayer2D:
	for child: Node in engine.get_children():
		if child is AudioStreamPlayer2D:
			return child
	return null


func _player_3d(engine: StdAudioPlayer) -> AudioStreamPlayer3D:
	for child: Node in engine.get_children():
		if child is AudioStreamPlayer3D:
			return child
	return null


func _test_pool_configuration() -> void:
	var engine: StdAudioPlayer = StdAudioPlayer.new()

	assert_err(engine.configure_pools(-1, 2, 3), "negative capacity errs")
	assert_ok(engine.configure_pools(1, 2, 3), "valid capacities configure atomically")
	assert_eq(engine._global_player, null, "configuration does not build pools")

	var played: StdResult = engine.play(_make_recipe())
	assert_ok(played, "first valid playback builds pools")
	assert_eq(engine._global_player.capacity(), 1, "global configured capacity applied")
	assert_eq(engine._2d_player.capacity(), 2, "2D configured capacity applied")
	assert_eq(engine._3d_player.capacity(), 3, "3D configured capacity applied")
	assert_err(engine.configure_pools(4, 4, 4), "configuration after first playback errs")

	_teardown(engine)
	return


func _test_invalid_play_does_not_lock_configuration() -> void:
	var engine: StdAudioPlayer = StdAudioPlayer.new()

	assert_err(engine.play(null), "play null recipe errs")
	var no_stream: StdAudioRecipe = StdAudioRecipe.new()
	no_stream._id = &"empty"
	assert_err(engine.play(no_stream), "play recipe without stream errs")
	var bad_volume: StdAudioRecipe = _make_recipe(&"bad_volume", NAN)
	assert_err(engine.play(bad_volume), "play recipe with NaN volume errs")
	var bad_radius: StdAudioRecipe2D = StdAudioRecipe2D.new()
	bad_radius._stream = AudioStreamWAV.new()
	bad_radius._radius = INF
	assert_err(engine.play(bad_radius), "play recipe with infinite radius errs")
	assert_eq(engine._global_player, null, "invalid recipes do not build pools")
	assert_ok(engine.configure_pools(1, 1, 1), "configuration remains open after invalid play")

	_teardown(engine)
	return


func _test_zero_capacity_disables_dimension() -> void:
	var engine: StdAudioPlayer = StdAudioPlayer.new()
	assert_ok(engine.configure_pools(0, 1, 1), "zero capacity is accepted")

	var rv: StdResult = engine.play(_make_recipe())
	assert_err(rv, "disabled global pool rejects playback")
	assert_true(String(rv.unwrap_err()).contains("GLOBAL"), "exhaustion error names the dimension")
	assert_true(String(rv.unwrap_err()).contains("0/0"), "exhaustion error reports usage and capacity")
	assert_true(String(rv.unwrap_err()).contains("configure_pools"), "exhaustion error names the remedy")

	_teardown(engine)
	return


func _test_play_returns_opaque_handle_and_configures_player() -> void:
	var engine: StdAudioPlayer = _make_engine()
	var recipe: StdAudioRecipe = _make_recipe(&"sfx", 80.0)
	recipe._bus = &"Master"

	var rv: StdResult = engine.play(recipe)
	assert_ok(rv, "play valid recipe")
	var handle: StdAudioHandle = rv.unwrap()
	assert_true(handle is StdAudioHandle, "managed play returns StdAudioHandle")
	assert_true(handle.is_active(), "new handle is active")
	var player: AudioStreamPlayer = _global_player(engine)
	assert_eq(player.stream, recipe._stream, "stream applied to private player")
	assert_eq(player.bus, &"Master", "bus applied to private player")
	assert_true(is_equal_approx(player.volume_linear, 0.8), "volume 80 maps to 0.8 linear")
	assert_eq(engine._global_player.active_count(), 1, "player is acquired")

	_teardown(engine)
	return


func _test_recipe_zero_values_are_preserved() -> void:
	var recipe: StdAudioRecipe = StdAudioRecipe.new()
	assert_true(is_equal_approx(recipe.volume().unwrap(), 50.0), "default recipe volume is 50")
	recipe._volume = 0.0
	assert_true(recipe.volume().is_some(), "zero volume is some")
	assert_true(is_equal_approx(recipe.volume().unwrap(), 0.0), "zero volume is preserved")

	var recipe2d: StdAudioRecipe2D = StdAudioRecipe2D.new()
	assert_true(recipe2d.pos().is_some(), "2D origin is some")
	assert_eq(recipe2d.pos().unwrap(), Vector2.ZERO, "2D origin is preserved")
	assert_true(is_equal_approx(recipe2d.radius().unwrap(), 1000.0), "2D default radius is 1000")
	recipe2d._radius = 0.0
	assert_true(is_equal_approx(recipe2d.radius().unwrap(), 0.0), "2D zero radius is preserved")

	var recipe3d: StdAudioRecipe3D = StdAudioRecipe3D.new()
	assert_true(recipe3d.pos().is_some(), "3D origin is some")
	assert_eq(recipe3d.pos().unwrap(), Vector3.ZERO, "3D origin is preserved")
	recipe3d._radius = 0.0
	assert_true(is_equal_approx(recipe3d.radius().unwrap(), 0.0), "3D zero radius is preserved")
	return


func _test_zero_volume_is_silent() -> void:
	var engine: StdAudioPlayer = _make_engine()

	var rv: StdResult = engine.play(_make_recipe(&"quiet", 0.0))
	assert_ok(rv, "play with volume 0")
	assert_true(is_equal_approx(_global_player(engine).volume_linear, 0.0), "volume 0 is silent")

	_teardown(engine)
	return


func _test_pool_exhaustion_and_reuse() -> void:
	var engine: StdAudioPlayer = _make_engine()
	var recipe: StdAudioRecipe = _make_recipe()

	var first: StdResult = engine.play(recipe)
	assert_ok(first, "first play fills the size 1 pool")
	assert_err(engine.play(recipe), "play on exhausted pool errs")
	assert_ok(engine.stop(first.unwrap()), "stop releases the slot")
	assert_ok(engine.play(recipe), "play after stop is ok again")

	_teardown(engine)
	return


func _test_handle_and_engine_stop() -> void:
	var engine: StdAudioPlayer = _make_engine()

	var first: StdAudioHandle = engine.play(_make_recipe()).unwrap()
	assert_ok(first.stop(), "handle stops its playback")
	assert_true(not first.is_active(), "handle is inactive after stop")
	assert_eq(engine._global_player.active_count(), 0, "handle stop returns player to pool")
	assert_err(first.stop(), "handle double stop errs")

	var second: StdAudioHandle = engine.play(_make_recipe()).unwrap()
	assert_ok(engine.stop(second), "engine stops a managed handle")
	assert_err(engine.stop(second), "engine double stop errs")
	assert_err(engine.stop(null), "null handle errs")

	var foreign_engine: StdAudioPlayer = _make_engine()
	var foreign: StdAudioHandle = foreign_engine.play(_make_recipe()).unwrap()
	assert_err(engine.stop(foreign), "handle from another engine errs")

	_teardown(foreign_engine)
	_teardown(engine)
	return


func _test_play_rejects_one_shot() -> void:
	var engine: StdAudioPlayer = _make_engine()

	var rv: StdResult = engine.play(_make_recipe(&"sfx", 100.0, true))
	assert_err(rv, "play of one_shot recipe errs")
	assert_true(String(rv.unwrap_err()).contains("play_oneshot"), "err points at play_oneshot")
	assert_eq(engine._global_player, null, "rejected play does not build pools")

	_teardown(engine)
	return


func _test_play_oneshot() -> void:
	var engine: StdAudioPlayer = _make_engine()

	assert_err(engine.play_oneshot(_make_recipe()), "play_oneshot of managed recipe errs")
	assert_err(engine.play_oneshot(null), "play_oneshot of null errs")

	var rv: StdResult = engine.play_oneshot(_make_recipe(&"sfx", 100.0, true))
	assert_ok(rv, "play_oneshot of one_shot recipe")
	assert_eq(rv.unwrap(), true, "play_oneshot returns no handle")
	assert_eq(engine._global_player.active_count(), 1, "one-shot player is acquired")

	_global_player(engine).finished.emit()
	assert_eq(engine._global_player.active_count(), 0, "one-shot releases on finished")
	assert_ok(engine.play(_make_recipe()), "slot is reusable after auto-release")

	_teardown(engine)
	return


func _test_play_oneshot_rejects_looping() -> void:
	var engine: StdAudioPlayer = _make_engine()

	var wav_loop: StdAudioRecipe = _make_recipe(&"loop_wav", 100.0, true)
	wav_loop._stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var rv: StdResult = engine.play_oneshot(wav_loop)
	assert_err(rv, "play_oneshot of looping WAV errs")
	assert_true(String(rv.unwrap_err()).contains("looping"), "err names the looping stream")

	var ogg_loop: StdAudioRecipe = _make_recipe(&"loop_ogg", 100.0, true)
	ogg_loop._stream = AudioStreamOggVorbis.new()
	ogg_loop._stream.loop = true
	assert_err(engine.play_oneshot(ogg_loop), "play_oneshot of looping Ogg errs")
	assert_eq(engine._global_player, null, "rejected loops acquire nothing")

	_teardown(engine)
	return


func _test_recipe_is_looping() -> void:
	var recipe: StdAudioRecipe = StdAudioRecipe.new()
	assert_true(not recipe.is_looping(), "no stream is not looping")

	recipe._stream = AudioStreamWAV.new()
	assert_true(not recipe.is_looping(), "default WAV is not looping")
	recipe._stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	assert_true(recipe.is_looping(), "WAV with loop_mode is looping")

	recipe._stream = AudioStreamOggVorbis.new()
	assert_true(not recipe.is_looping(), "default Ogg is not looping")
	recipe._stream.loop = true
	assert_true(recipe.is_looping(), "Ogg with loop is looping")
	return


func _test_managed_natural_finish_releases_and_notifies() -> void:
	var engine: StdAudioPlayer = _make_engine()
	var handle: StdAudioHandle = engine.play(_make_recipe()).unwrap()
	var notifications: Array[bool] = []
	var _e: int = handle.finished.connect(func() -> void: notifications.append(true))

	_global_player(engine).finished.emit()
	assert_eq(engine._global_player.active_count(), 0, "natural finish releases managed player")
	assert_true(not handle.is_active(), "natural finish invalidates handle")
	assert_eq(notifications.size(), 1, "natural finish emits handle finished")
	assert_err(handle.stop(), "naturally finished handle cannot stop again")

	_teardown(engine)
	return


func _test_manual_stop_does_not_emit_finished() -> void:
	var engine: StdAudioPlayer = _make_engine()
	var handle: StdAudioHandle = engine.play(_make_recipe()).unwrap()
	var notifications: Array[bool] = []
	var _e: int = handle.finished.connect(func() -> void: notifications.append(true))

	assert_ok(handle.stop(), "manual handle stop succeeds")
	assert_eq(notifications.size(), 0, "manual stop does not emit finished")

	_teardown(engine)
	return


func _test_managed_loop_stays_active_until_stopped() -> void:
	var engine: StdAudioPlayer = _make_engine()
	var recipe: StdAudioRecipe = _make_recipe(&"music")
	recipe._stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	var rv: StdResult = engine.play(recipe)
	assert_ok(rv, "managed loop is accepted")
	var handle: StdAudioHandle = rv.unwrap()
	assert_true(handle.is_active(), "managed loop handle is active")
	assert_eq(engine._global_player.active_count(), 1, "managed loop holds pool slot")
	assert_ok(handle.stop(), "managed loop stops explicitly")

	_teardown(engine)
	return


func _test_positional_values_apply_exactly() -> void:
	var engine: StdAudioPlayer = _make_engine()
	var recipe2d: StdAudioRecipe2D = StdAudioRecipe2D.new()
	recipe2d._id = &"pos2d"
	recipe2d._stream = AudioStreamWAV.new()
	recipe2d._pos = Vector2.ZERO
	recipe2d._radius = 0.0

	assert_ok(engine.play(recipe2d), "play 2D recipe")
	var player2d: AudioStreamPlayer2D = _player_2d(engine)
	assert_eq(player2d.position, Vector2.ZERO, "2D origin applied")
	assert_true(is_equal_approx(player2d.max_distance, StdAudioPlayer.MIN_POSITIONAL_RADIUS),
			"2D zero radius maps to Godot's positive engine minimum")

	var recipe3d: StdAudioRecipe3D = StdAudioRecipe3D.new()
	recipe3d._id = &"pos3d"
	recipe3d._stream = AudioStreamWAV.new()
	recipe3d._pos = Vector3(1.0, 2.0, 3.0)
	# Leave the radius at its exported default.
	assert_ok(engine.play(recipe3d), "play 3D recipe")
	var player3d: AudioStreamPlayer3D = _player_3d(engine)
	assert_eq(player3d.position, Vector3(1.0, 2.0, 3.0), "3D position applied")
	assert_eq(player3d.max_distance, 1000.0, "3D default radius applied")

	_teardown(engine)
	return


func _test_stop_all_invalidates_handles() -> void:
	var engine: StdAudioPlayer = _make_engine()
	var recipe2d: StdAudioRecipe2D = StdAudioRecipe2D.new()
	recipe2d._id = &"pos2d"
	recipe2d._stream = AudioStreamWAV.new()

	var global_handle: StdAudioHandle = engine.play(_make_recipe()).unwrap()
	var handle2d: StdAudioHandle = engine.play(recipe2d).unwrap()
	engine.stop_all()
	assert_true(not global_handle.is_active(), "stop_all invalidates global handle")
	assert_true(not handle2d.is_active(), "stop_all invalidates 2D handle")
	assert_eq(engine._global_player.active_count(), 0, "stop_all releases global pool")
	assert_eq(engine._2d_player.active_count(), 0, "stop_all releases 2D pool")

	_teardown(engine)
	return
