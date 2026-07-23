extends StdTest
## Headless tests for StdAudioBook.
## Run: godot4.6 --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- --module std-audio



func _make_recipe(id: StringName) -> StdAudioRecipe:
	var recipe: StdAudioRecipe = StdAudioRecipe.new()
	recipe._id = id
	recipe._stream = AudioStreamWAV.new()
	return recipe


func _test_register() -> void:
	var book: StdAudioBook = StdAudioBook.new()
	var recipe: StdAudioRecipe = _make_recipe(&"explosion")

	var rv: StdResult = book.register(recipe)
	assert_ok(rv, "register with id")
	assert_eq(rv.unwrap(), recipe, "register ok value is the recipe")

	assert_err(book.register(null), "register null recipe errs")
	assert_err(book.register(_make_recipe(&"")), "register without id errs")

	var dup: StdAudioRecipe = _make_recipe(&"explosion")
	assert_err(book.register(dup), "duplicate id errs")
	assert_eq(book.fetch(&"explosion").unwrap(), recipe, "duplicate register keeps first recipe")

	book.free()
	return


func _test_fetch() -> void:
	var book: StdAudioBook = StdAudioBook.new()
	var recipe: StdAudioRecipe = _make_recipe(&"jump")
	assert_ok(book.register(recipe), "register for fetch")

	var found: StdOption = book.fetch(&"jump")
	assert_true(found.is_some(), "fetch registered id is some")
	assert_eq(found.unwrap(), recipe, "fetch returns the registered recipe")
	assert_true(book.fetch(&"missing").is_none(), "fetch unknown id is none")

	book.free()
	return


func _test_revoke() -> void:
	var book: StdAudioBook = StdAudioBook.new()
	var recipe: StdAudioRecipe = _make_recipe(&"music")
	assert_ok(book.register(recipe), "register for revoke")

	var revoked: StdOption = book.revoke(&"music")
	assert_true(revoked.is_some(), "revoke registered id is some")
	assert_eq(revoked.unwrap(), recipe, "revoke returns the recipe")
	assert_true(book.fetch(&"music").is_none(), "fetch after revoke is none")
	assert_true(book.revoke(&"music").is_none(), "second revoke is none")
	assert_ok(book.register(recipe), "re-register after revoke")

	book.free()
	return
