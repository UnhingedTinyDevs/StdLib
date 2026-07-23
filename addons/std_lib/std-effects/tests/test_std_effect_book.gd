extends StdTest
## Headless tests for StdEffectBook.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-effects



func _make_recipe(id: StringName) -> StdSpriteEffectRecipe:
	var recipe: StdSpriteEffectRecipe = StdSpriteEffectRecipe.new()
	recipe._id = id
	return recipe


func _test_register() -> void:
	var book: StdEffectBook = StdEffectBook.new()
	var recipe: StdSpriteEffectRecipe = _make_recipe(&"burst")

	var rv: StdResult = book.register(recipe)
	assert_ok(rv, "register with id")
	assert_eq(rv.unwrap(), recipe, "register ok value is the recipe")

	assert_err(book.register(null), "register null recipe errs")
	assert_err(book.register(_make_recipe(&"")), "register without id errs")

	var dup: StdSpriteEffectRecipe = _make_recipe(&"burst")
	assert_err(book.register(dup), "duplicate id errs")
	assert_eq(book.fetch(&"burst").unwrap(), recipe, "duplicate register keeps first recipe")

	book.free()
	return


func _test_register_mixed_kinds() -> void:
	var book: StdEffectBook = StdEffectBook.new()
	var particle: StdParticleEffectRecipe = StdParticleEffectRecipe.new()
	particle._id = &"sparks"
	var shader: StdShaderEffectRecipe = StdShaderEffectRecipe.new()
	shader._id = &"flash"

	assert_ok(book.register(particle), "particle recipe registers")
	assert_ok(book.register(shader), "shader recipe registers")
	assert_eq(book.fetch(&"sparks").unwrap(), particle, "particle fetched back")
	assert_eq(book.fetch(&"flash").unwrap(), shader, "shader fetched back")

	book.free()
	return


func _test_fetch() -> void:
	var book: StdEffectBook = StdEffectBook.new()
	var recipe: StdSpriteEffectRecipe = _make_recipe(&"puff")
	assert_ok(book.register(recipe), "register for fetch")

	var found: StdOption = book.fetch(&"puff")
	assert_true(found.is_some(), "fetch registered id is some")
	assert_eq(found.unwrap(), recipe, "fetch returns the registered recipe")
	assert_true(book.fetch(&"missing").is_none(), "fetch unknown id is none")

	book.free()
	return


func _test_revoke() -> void:
	var book: StdEffectBook = StdEffectBook.new()
	var recipe: StdSpriteEffectRecipe = _make_recipe(&"aura")
	assert_ok(book.register(recipe), "register for revoke")

	var revoked: StdOption = book.revoke(&"aura")
	assert_true(revoked.is_some(), "revoke registered id is some")
	assert_eq(revoked.unwrap(), recipe, "revoke returns the recipe")
	assert_true(book.fetch(&"aura").is_none(), "fetch after revoke is none")
	assert_true(book.revoke(&"aura").is_none(), "second revoke is none")
	assert_ok(book.register(recipe), "re-register after revoke")

	book.free()
	return
