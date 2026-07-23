extends StdTest
## Headless tests for the public StdEffects service.
## Run: godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-effects


const SERVICE_PATH: String = "res://addons/std_lib/std-effects/scripts/std_effects.gd"
const SHADER_CODE: String = """
shader_type canvas_item;
uniform float progress = 0.0;
void fragment() { COLOR.a *= 1.0 - (progress * 0.0); }
"""


func _make_service() -> Node:
	var script: GDScript = load(SERVICE_PATH)
	var service: Node = script.new()
	return add_to_tree(service)


func _make_frames(loop: bool = false, count: int = 3) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_loop(&"default", loop)
	for i: int in count:
		frames.add_frame(&"default", PlaceholderTexture2D.new())
		pass
	return frames


func _make_sprite_recipe(
		id: StringName,
		loop: bool = false,
) -> StdSpriteEffectRecipe:
	var recipe: StdSpriteEffectRecipe = StdSpriteEffectRecipe.new()
	recipe.id = id
	recipe.frames = _make_frames(loop)
	recipe.speed_scale = 2.0
	recipe.scale = Vector2(3, 3)
	recipe.modulate = Color.RED
	recipe.z_index = 42
	return recipe


func _make_particle_recipe(id: StringName) -> StdParticleEffectRecipe:
	var recipe: StdParticleEffectRecipe = StdParticleEffectRecipe.new()
	recipe.id = id
	recipe.process_material = ParticleProcessMaterial.new()
	recipe.amount = 12
	recipe.lifetime = 0.5
	return recipe


func _make_shader_recipe(
		id: StringName,
		duration: float = 10.0,
) -> StdShaderEffectRecipe:
	var recipe: StdShaderEffectRecipe = StdShaderEffectRecipe.new()
	recipe.id = id
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	recipe.shader = shader
	recipe.params = {&"progress": 0.0}
	recipe.duration = duration
	return recipe


func _sprite(service: Node) -> AnimatedSprite2D:
	for child: Node in service.get_children():
		if child is AnimatedSprite2D: return child
	return null


func _particles(service: Node) -> GPUParticles2D:
	for child: Node in service.get_children():
		if child is GPUParticles2D: return child
	return null


func _teardown(service: Node) -> void:
	service.stop_all()
	return


func _test_registry_replaces_and_revokes() -> void:
	var service: Node = _make_service()
	var sprite: StdSpriteEffectRecipe = _make_sprite_recipe(&"impact")
	var replacement: StdParticleEffectRecipe = _make_particle_recipe(&"impact")

	var registered: StdResult = service.register(sprite)
	assert_ok(registered, "valid recipe registers")
	assert_eq(registered.unwrap(), sprite, "register returns the recipe")
	assert_ok(service.register(replacement), "same id replaces")
	assert_eq(service.fetch(&"impact").unwrap(), replacement, "replacement is stored")
	assert_true(service.fetch(&"missing").is_none(), "unknown id is none")

	var revoked: StdOption = service.revoke(&"impact")
	assert_eq(revoked.unwrap(), replacement, "revoke returns the recipe")
	assert_true(service.fetch(&"impact").is_none(), "revoked recipe is absent")
	assert_true(service.revoke(&"impact").is_none(), "second revoke is none")
	_teardown(service)
	return


func _test_register_all_is_atomic() -> void:
	var service: Node = _make_service()
	var sprite: StdSpriteEffectRecipe = _make_sprite_recipe(&"sprite")
	var particles: StdParticleEffectRecipe = _make_particle_recipe(&"particles")
	var shader: StdShaderEffectRecipe = _make_shader_recipe(&"shader")
	var batch: Array[StdEffectRecipe] = [sprite, particles, shader]

	var registered: StdResult = service.register_all(batch)
	assert_ok(registered, "valid batch registers")
	assert_eq(registered.unwrap(), 3, "batch reports stored count")
	assert_eq(service.fetch(&"particles").unwrap(), particles, "mixed types are stored")

	var duplicate: StdSpriteEffectRecipe = _make_sprite_recipe(&"duplicate")
	var duplicates: Array[StdEffectRecipe] = [
		duplicate,
		_make_particle_recipe(&"duplicate"),
	]
	assert_err(service.register_all(duplicates), "duplicate batch id errs")
	assert_true(service.fetch(&"duplicate").is_none(), "duplicate batch changes nothing")

	var invalid: StdSpriteEffectRecipe = _make_sprite_recipe(&"invalid")
	invalid.frames = null
	var partly_invalid: Array[StdEffectRecipe] = [
		_make_sprite_recipe(&"would_be_new"),
		invalid,
	]
	assert_err(service.register_all(partly_invalid), "invalid batch errs")
	assert_true(service.fetch(&"would_be_new").is_none(), "invalid batch is atomic")
	assert_ok(service.register_all([] as Array[StdEffectRecipe]), "empty batch is valid")
	_teardown(service)
	return


func _test_play_sprite_configures_releases_and_reuses() -> void:
	var service: Node = _make_service()
	assert_ok(service.configure_pools(1, 1), "small pools configure")
	var recipe: StdSpriteEffectRecipe = _make_sprite_recipe(&"aura")
	var played: StdResult = service.play_sprite(recipe, Vector2(64, 32))
	assert_ok(played, "sprite plays")
	var handle: StdEffectHandle = played.unwrap()
	var notifications: Array[bool] = []
	var error: Error = handle.finished.connect(func() -> void: notifications.append(true))
	assert_eq(error, OK, "handle signal connects")

	var sprite: AnimatedSprite2D = _sprite(service)
	assert_eq(sprite.sprite_frames, recipe.frames, "frames applied")
	assert_eq(sprite.animation, recipe.animation, "animation applied")
	assert_eq(sprite.speed_scale, recipe.speed_scale, "speed applied")
	assert_eq(sprite.scale, recipe.scale, "scale applied")
	assert_eq(sprite.modulate, recipe.modulate, "modulate applied")
	assert_eq(sprite.z_index, recipe.z_index, "z index applied")
	assert_eq(sprite.position, Vector2(64, 32), "position applied")
	assert_err(service.play_sprite(recipe), "full pool rejects another sprite")

	sprite.animation_finished.emit()
	assert_true(not handle.is_active(), "natural finish invalidates handle")
	assert_eq(notifications.size(), 1, "natural finish emits handle signal")
	assert_ok(service.play_sprite(recipe), "released sprite is reusable")
	_teardown(service)
	return


func _test_looping_sprite_stops_through_handle() -> void:
	var service: Node = _make_service()
	var recipe: StdSpriteEffectRecipe = _make_sprite_recipe(&"loop", true)
	var handle: StdEffectHandle = service.play_sprite(recipe).unwrap()
	var notifications: Array[bool] = []
	var error: Error = handle.finished.connect(func() -> void: notifications.append(true))
	assert_eq(error, OK, "handle signal connects")

	assert_true(handle.is_active(), "loop starts active")
	assert_ok(handle.stop(), "handle stops loop")
	assert_true(not handle.is_active(), "stopped handle is inactive")
	assert_eq(notifications.size(), 0, "manual stop is silent")
	assert_err(handle.stop(), "double stop errs")
	_teardown(service)
	return


func _test_play_particles_configures_and_releases() -> void:
	var service: Node = _make_service()
	var recipe: StdParticleEffectRecipe = _make_particle_recipe(&"sparks")
	var played: StdResult = service.play_particles(recipe, Vector2(10, 20))
	assert_ok(played, "particles play")
	var handle: StdEffectHandle = played.unwrap()
	var particles: GPUParticles2D = _particles(service)

	assert_eq(particles.process_material, recipe.process_material, "material applied")
	assert_eq(particles.amount, recipe.amount, "amount applied")
	assert_eq(particles.lifetime, recipe.lifetime, "lifetime applied")
	assert_eq(particles.position, Vector2(10, 20), "position applied")
	particles.finished.emit()
	assert_true(not handle.is_active(), "particle completion invalidates handle")
	assert_ok(service.play_particles(recipe), "particle slot is reusable")
	_teardown(service)
	return


func _test_play_shader_owns_and_restores_material() -> void:
	var service: Node = _make_service()
	var recipe: StdShaderEffectRecipe = _make_shader_recipe(&"flash")
	var target: Control = Control.new()
	var original: CanvasItemMaterial = CanvasItemMaterial.new()
	target.material = original

	var played: StdResult = service.play_shader(recipe, target)
	assert_ok(played, "shader plays")
	var handle: StdEffectHandle = played.unwrap()
	assert_true(target.material is ShaderMaterial, "shader material is applied")
	assert_err(service.play_shader(recipe, target), "overlapping shader errs")
	assert_ok(handle.stop(), "shader stops through handle")
	assert_eq(target.material, original, "original material is restored")
	assert_ok(service.play_shader(recipe, target), "target is reusable after stop")

	service.stop_all()
	target.free()
	_teardown(service)
	return


func _test_shader_preserves_newer_external_material() -> void:
	var service: Node = _make_service()
	var recipe: StdShaderEffectRecipe = _make_shader_recipe(&"flash")
	var target: Control = Control.new()
	var handle: StdEffectHandle = service.play_shader(recipe, target).unwrap()
	var external: CanvasItemMaterial = CanvasItemMaterial.new()
	target.material = external

	assert_ok(handle.stop(), "shader stops")
	assert_eq(target.material, external, "newer external material wins")
	target.free()
	_teardown(service)
	return


func _test_shader_finishes_naturally() -> void:
	var service: Node = _make_service()
	var recipe: StdShaderEffectRecipe = _make_shader_recipe(&"flash", 0.000001)
	var target: Control = Control.new()
	var original: CanvasItemMaterial = CanvasItemMaterial.new()
	target.material = original
	var handle: StdEffectHandle = service.play_shader(recipe, target).unwrap()
	var notifications: Array[bool] = []
	var error: Error = handle.finished.connect(func() -> void: notifications.append(true))
	assert_eq(error, OK, "handle signal connects")

	await process_wait(2)
	assert_true(not handle.is_active(), "completed shader invalidates handle")
	assert_eq(notifications.size(), 1, "completed shader emits finished")
	assert_eq(target.material, original, "completed shader restores material")
	target.free()
	_teardown(service)
	return


func _test_playback_by_id_checks_recipe_type() -> void:
	var service: Node = _make_service()
	var sprite: StdSpriteEffectRecipe = _make_sprite_recipe(&"sprite")
	var particles: StdParticleEffectRecipe = _make_particle_recipe(&"particles")
	var shader: StdShaderEffectRecipe = _make_shader_recipe(&"shader")
	var recipes: Array[StdEffectRecipe] = [sprite, particles, shader]
	assert_ok(service.register_all(recipes), "recipes register")

	assert_ok(service.play_sprite_id(&"sprite"), "sprite id plays")
	assert_ok(service.play_particles_id(&"particles"), "particle id plays")
	var target: Control = Control.new()
	assert_ok(service.play_shader_id(&"shader", target), "shader id plays")
	assert_err(service.play_sprite_id(&"particles"), "wrong sprite id type errs")
	assert_err(service.play_particles_id(&"shader"), "wrong particle id type errs")
	assert_err(service.play_shader_id(&"sprite", target), "wrong shader id type errs")
	assert_err(service.play_sprite_id(&"missing"), "missing id errs")

	service.stop_all()
	target.free()
	_teardown(service)
	return


func _test_validation_rejects_bad_input_before_playback() -> void:
	var service: Node = _make_service()
	assert_err(service.play_sprite(null), "null sprite errs")
	assert_err(service.play_particles(null), "null particles err")
	var target: Control = Control.new()
	assert_err(service.play_shader(null, target), "null shader errs")

	var sprite: StdSpriteEffectRecipe = _make_sprite_recipe(&"sprite")
	sprite.frames = null
	assert_err(service.play_sprite(sprite), "missing frames err")
	sprite = _make_sprite_recipe(&"sprite")
	sprite.animation = &"missing"
	assert_err(service.play_sprite(sprite), "missing animation errs")
	sprite = _make_sprite_recipe(&"sprite")
	sprite.speed_scale = NAN
	assert_err(service.play_sprite(sprite), "non-finite sprite speed errs")
	assert_err(
			service.play_sprite(_make_sprite_recipe(&"sprite"), Vector2(INF, 0.0)),
			"non-finite sprite position errs")

	var particles: StdParticleEffectRecipe = _make_particle_recipe(&"particles")
	particles.amount = 0
	assert_err(service.play_particles(particles), "non-positive amount errs")
	particles.amount = 1
	particles.lifetime = INF
	assert_err(service.play_particles(particles), "non-finite lifetime errs")
	particles.lifetime = 1.0
	particles.explosiveness = 2.0
	assert_err(service.play_particles(particles), "out-of-range explosiveness errs")

	var shader: StdShaderEffectRecipe = _make_shader_recipe(&"shader")
	shader.tween_param = &""
	assert_err(service.play_shader(shader, target), "empty tween parameter errs")
	shader.tween_param = &"progress"
	shader.duration = 0.0
	assert_err(service.play_shader(shader, target), "non-positive duration errs")
	var dying: Control = Control.new()
	dying.queue_free()
	assert_err(
			service.play_shader(_make_shader_recipe(&"shader"), dying),
			"queued target errs")

	assert_err(service.register(StdEffectRecipe.new()), "unsupported base recipe errs")
	var unidentified: StdSpriteEffectRecipe = _make_sprite_recipe(&"")
	assert_err(service.register(unidentified), "registration requires id")
	target.free()
	_teardown(service)
	return


func _test_pool_configuration_locks_after_success() -> void:
	var service: Node = _make_service()
	assert_err(service.configure_pools(-1, 1), "negative capacity errs")
	assert_ok(service.configure_pools(0, 1), "zero capacity configures")
	assert_err(service.play_sprite(_make_sprite_recipe(&"sprite")), "zero disables sprites")
	assert_ok(service.configure_pools(1, 1), "failed playback does not lock pools")

	var handle: StdEffectHandle = service.play_sprite(_make_sprite_recipe(&"sprite")).unwrap()
	assert_err(service.configure_pools(2, 2), "successful playback locks pools")
	assert_ok(handle.stop(), "configured sprite stops")
	_teardown(service)
	return


func _test_stop_all_releases_every_type() -> void:
	var service: Node = _make_service()
	var sprite: StdEffectHandle = service.play_sprite(_make_sprite_recipe(&"sprite")).unwrap()
	var particles: StdEffectHandle = service.play_particles(
			_make_particle_recipe(&"particles")).unwrap()
	var target: Control = Control.new()
	var original: CanvasItemMaterial = CanvasItemMaterial.new()
	target.material = original
	var shader: StdEffectHandle = service.play_shader(
			_make_shader_recipe(&"shader"), target).unwrap()

	assert_eq(service.stop_all(), 3, "stop_all reports every playback")
	assert_true(not sprite.is_active(), "sprite handle invalidated")
	assert_true(not particles.is_active(), "particle handle invalidated")
	assert_true(not shader.is_active(), "shader handle invalidated")
	assert_eq(target.material, original, "stop_all restores shader target")
	assert_eq(service.stop_all(), 0, "second stop_all has nothing to stop")

	target.free()
	_teardown(service)
	return
