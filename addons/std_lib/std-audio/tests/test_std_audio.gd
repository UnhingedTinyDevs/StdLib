extends StdTest
## Headless tests for the StdAudio facade.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-audio


const STD_AUDIO_SCRIPT: String = "res://addons/std_lib/std-audio/scripts/std_audio.gd"


# The facade is an autoload in host projects, so this unit suite instances the
# script directly.
func _make_facade() -> Node:
	var script: GDScript = load(STD_AUDIO_SCRIPT)
	var facade: Node = script.new()
	return facade


func _make_recipe(id: StringName) -> StdAudioRecipe:
	var recipe: StdAudioRecipe = StdAudioRecipe.new()
	recipe._id = id
	recipe._stream = AudioStreamWAV.new()
	return recipe


func _teardown(facade: Node) -> void:
	facade.stop_all()
	facade.free()
	return


func _test_play_and_stop() -> void:
	var facade: Node = _make_facade()

	var rv: StdResult = facade.play(_make_recipe(&"sfx"))
	assert_ok(rv, "facade play")
	assert_true(rv.unwrap() is StdAudioHandle, "facade play returns StdAudioHandle")
	assert_ok(facade.stop(rv.unwrap()), "facade stop of handle")
	assert_err(facade.stop(rv.unwrap()), "facade double stop errs")
	assert_err(facade.play(null), "facade play null errs")

	_teardown(facade)
	return


func _test_configure_pools() -> void:
	var facade: Node = _make_facade()

	assert_ok(facade.configure_pools(1, 2, 3), "facade configures pools")
	assert_ok(facade.play(_make_recipe(&"sfx")), "facade plays with configured pools")
	assert_err(facade.configure_pools(3, 3, 3), "facade rejects late configuration")

	_teardown(facade)
	return


func _make_oneshot(id: StringName) -> StdAudioRecipe:
	var recipe: StdAudioRecipe = _make_recipe(id)
	recipe.one_shot = true
	return recipe


func _test_play_oneshot() -> void:
	var facade: Node = _make_facade()

	assert_err(facade.play(_make_oneshot(&"sfx")), "facade play of one_shot recipe errs")
	var rv: StdResult = facade.play_oneshot(_make_oneshot(&"sfx"))
	assert_ok(rv, "facade play_oneshot")
	assert_eq(rv.unwrap(), true, "facade play_oneshot returns no handle")
	assert_err(facade.play_oneshot(_make_recipe(&"managed")), "facade play_oneshot of managed recipe errs")

	_teardown(facade)
	return


func _test_play_oneshot_id() -> void:
	var facade: Node = _make_facade()

	assert_ok(facade.register(_make_oneshot(&"blip")), "register one_shot recipe")
	assert_ok(facade.play_oneshot_id(&"blip"), "facade play_oneshot_id of registered recipe")
	assert_err(facade.play_id(&"blip"), "facade play_id of one_shot recipe errs")
	assert_err(facade.play_oneshot_id(&"missing"), "facade play_oneshot_id of unknown id errs")

	_teardown(facade)
	return


func _test_registry_and_play_id() -> void:
	var facade: Node = _make_facade()
	var recipe: StdAudioRecipe = _make_recipe(&"jump")

	assert_ok(facade.register(recipe), "facade register")
	assert_eq(facade.fetch(&"jump").unwrap(), recipe, "facade fetch")
	assert_ok(facade.play_id(&"jump"), "facade play_id of registered recipe")
	assert_err(facade.play_id(&"missing"), "facade play_id of unknown id errs")
	assert_eq(facade.revoke(&"jump").unwrap(), recipe, "facade revoke")
	assert_err(facade.play_id(&"jump"), "facade play_id after revoke errs")

	_teardown(facade)
	return


func _test_stop_all() -> void:
	var facade: Node = _make_facade()

	assert_ok(facade.play(_make_recipe(&"a")), "play first for stop_all")
	assert_ok(facade.play(_make_recipe(&"b")), "play second for stop_all")
	facade.stop_all()
	assert_ok(facade.play(_make_recipe(&"c")), "play after stop_all is ok")

	_teardown(facade)
	return


func _test_register_all() -> void:
	var facade: Node = _make_facade()
	var recipes: Array[StdAudioRecipe] = [
		_make_recipe(&"sfx_a"), _make_recipe(&"sfx_b"), _make_recipe(&"sfx_c"),
	]

	var rv: StdResult = facade.register_all(recipes)
	assert_ok(rv, "register_all ok")
	assert_eq(rv.unwrap(), 3, "reports how many it added")
	for id: StringName in [&"sfx_a", &"sfx_b", &"sfx_c"]:
		assert_true(facade.fetch(id).is_some(), "%s is registered" % id)

	_teardown(facade)
	return


func _test_register_all_is_idempotent() -> void:
	# The whole reason this exists: a game registers on load, and reloading its
	# scene to restart runs that again. A second pass must be silent, not a
	# duplicate-id error per recipe.
	var facade: Node = _make_facade()
	var recipes: Array[StdAudioRecipe] = [_make_recipe(&"sfx_a"), _make_recipe(&"sfx_b")]

	var first: StdResult = facade.register_all(recipes)
	assert_eq(first.unwrap(), 2, "the first pass adds both")

	var second: StdResult = facade.register_all(recipes)
	assert_ok(second, "registering the same recipes again is not an error")
	assert_eq(second.unwrap(), 0, "and adds nothing")

	var grown: Array[StdAudioRecipe] = [_make_recipe(&"sfx_a"), _make_recipe(&"sfx_new")]
	var third: StdResult = facade.register_all(grown)
	assert_ok(third, "a mixed known/new list is fine")
	assert_eq(third.unwrap(), 1, "and adds only what was new")
	assert_true(facade.fetch(&"sfx_new").is_some(), "the new one landed")

	_teardown(facade)
	return


func _test_register_all_reports_a_bad_recipe() -> void:
	var facade: Node = _make_facade()
	var recipes: Array[StdAudioRecipe] = [_make_recipe(&"sfx_ok"), _make_recipe(&"")]

	var rv: StdResult = facade.register_all(recipes)
	assert_err(rv, "a recipe with no id errs")
	assert_true(String(rv.unwrap_err()).contains("register_all"), "the error names the operation")
	assert_true(facade.fetch(&"sfx_ok").is_some(), "recipes before the bad one still registered")

	assert_ok(facade.register_all([] as Array[StdAudioRecipe]), "an empty list is fine")
	_teardown(facade)
	return
