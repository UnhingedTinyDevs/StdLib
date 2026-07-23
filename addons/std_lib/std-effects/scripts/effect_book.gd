class_name StdEffectBook
extends Node
## A registry for storing [code]StdEffectRecipeInterface[/code]'s by id
##
## Allows for the storing and referencing of [code]StdEffectRecipeInterface[/code]s
## from anywhere else in the codebase. Instanced as a child of the
## StdEffects service, which exposes it through
## [code]StdEffects.register/fetch/revoke[/code].


var _recipe_book: Dictionary[StringName, StdEffectRecipeInterface] = {}


## Add a new recipe to the book, keyed by its id. Errs when the recipe
## is null, has no id, or the id is already registered (the first
## registration wins). On success the ok value is the recipe.
func register(recipe: StdEffectRecipeInterface) -> StdResult:
	if recipe == null: return StdResult.err("recipe is null")
	var id_opt: StdOption = recipe.id()
	if id_opt.is_none(): return StdResult.err("recipe has no id")
	var id: StringName = id_opt.unwrap()
	if _recipe_book.has(id):
		return StdResult.err("recipe '%s' is already registered" % id)
	_recipe_book[id] = recipe
	return StdResult.ok(recipe)


## Grab a recipe from the book
func fetch(id: StringName) -> StdOption:
	if not _recipe_book.has(id): return StdOption.none()
	return StdOption.some(_recipe_book.get(id))


## Removes the desired effect from the recipe book
func revoke(id: StringName) -> StdOption:
	if not _recipe_book.has(id): return StdOption.none()
	var rv: StdOption = StdOption.some(_recipe_book.get(id))
	_recipe_book.erase(id)
	return rv
