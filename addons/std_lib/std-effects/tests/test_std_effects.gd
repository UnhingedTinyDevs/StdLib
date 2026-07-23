extends StdTest
## Headless smoke tests for the StdEffects facade.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-effects


const FACADE_PATH: String = "res://addons/std_lib/std-effects/scripts/std_effects.gd"


func _make_facade() -> Node:
	var script: GDScript = load(FACADE_PATH)
	return script.new()


func _make_oneshot_recipe(id: StringName) -> StdSpriteEffectRecipe:
	var recipe: StdSpriteEffectRecipe = StdSpriteEffectRecipe.new()
	recipe._id = id
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_loop(&"default", false)
	frames.add_frame(&"default", PlaceholderTexture2D.new())
	recipe._frames = frames
	recipe.one_shot = true
	return recipe


func _test_register_and_play_by_id() -> void:
	var facade: Node = _make_facade()
	var recipe: StdSpriteEffectRecipe = _make_oneshot_recipe(&"pop")

	assert_err(facade.play_oneshot_id(&"pop"), "unregistered id errs")
	assert_ok(facade.register(recipe), "register through the facade")
	assert_err(facade.register(recipe), "duplicate register errs")
	assert_ok(facade.play_oneshot_id(&"pop", Vector2(5, 5)), "play_oneshot_id after register")
	assert_err(facade.play_id(&"pop"), "one-shot recipe through play_id errs")
	assert_err(facade.play_id(&"never_registered"), "play_id unknown id errs")

	assert_true(facade.fetch(&"pop").is_some(), "fetch delegates")
	assert_true(facade.revoke(&"pop").is_some(), "revoke delegates")
	assert_err(facade.play_oneshot_id(&"pop"), "revoked id no longer plays")
	facade.free()
	return


func _test_direct_play_delegates() -> void:
	var facade: Node = _make_facade()
	var recipe: StdSpriteEffectRecipe = _make_oneshot_recipe(&"pop")

	assert_ok(facade.play_oneshot(recipe), "play_oneshot delegates")
	assert_err(facade.play(recipe), "play rejects one-shot recipe through the facade")
	assert_err(facade.play_on(recipe, null), "play_on rejects non-shader recipe")

	assert_err(facade.stop(null), "stop rejects null handles")
	facade.stop_all()

	facade.free()
	return


func _test_play_on_id() -> void:
	var facade: Node = _make_facade()
	var recipe: StdShaderEffectRecipe = StdShaderEffectRecipe.new()
	recipe._id = &"flash"
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float progress = 0.0;\nvoid fragment() {}"
	recipe._shader = shader

	assert_ok(facade.register(recipe), "register shader recipe")
	var target: Control = Control.new()
	var played: StdResult = facade.play_on_id(&"flash", target)
	assert_ok(played, "play_on_id runs")
	assert_true(played.unwrap() is StdEffectHandle, "play_on_id returns StdEffectHandle")
	assert_ok(facade.stop(played.unwrap()), "shader handle stops through facade")
	assert_eq(target.material, null, "stop restores original material")
	assert_err(facade.play_on_id(&"missing", target), "play_on_id unknown id errs")

	target.free()
	facade.free()
	return


func _test_register_all() -> void:
	var facade: Node = _make_facade()
	var recipes: Array[StdEffectRecipeInterface] = [
		_make_oneshot_recipe(&"fx_a"), _make_oneshot_recipe(&"fx_b"),
	]

	var rv: StdResult = facade.register_all(recipes)
	assert_ok(rv, "register_all ok")
	assert_eq(rv.unwrap(), 2, "reports how many it added")
	assert_true(facade.fetch(&"fx_a").is_some(), "fx_a is registered")
	assert_true(facade.fetch(&"fx_b").is_some(), "fx_b is registered")

	# Idempotent: a scene reload re-registers and must stay quiet.
	var again: StdResult = facade.register_all(recipes)
	assert_ok(again, "registering the same recipes again is not an error")
	assert_eq(again.unwrap(), 0, "and adds nothing")
	var invalid: Array[StdEffectRecipeInterface] = [null]
	assert_err(facade.register_all(invalid), "register_all reports a null recipe")

	facade.free()
	return


func _test_pool_configuration_delegates() -> void:
	var facade: Node = _make_facade()
	assert_err(facade.configure_pools(-1, 1, 1), "invalid capacities err through facade")
	assert_ok(facade.configure_pools(1, 2, 3), "valid capacities delegate")
	var managed: StdSpriteEffectRecipe = _make_oneshot_recipe(&"aura")
	managed.one_shot = false
	var played: StdResult = facade.play(managed)
	assert_ok(played, "managed play after configuration")
	assert_true(played.unwrap() is StdEffectHandle, "facade returns StdEffectHandle")
	assert_ok(facade.stop(played.unwrap()), "facade stops StdEffectHandle")
	assert_err(facade.configure_pools(2, 2, 2), "configuration locks after playback")
	facade.free()
	return
