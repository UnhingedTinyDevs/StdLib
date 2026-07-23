extends StdTest
## Headless tests for StdEffectPlayer.
## Run: godot --headless -s addons/std_lib/std-tests/scripts/std_test_runner.gd --path . -- addons/std_lib/std-effects


const SHADER_CODE: String = """
shader_type canvas_item;
uniform float progress = 0.0;
void fragment() { COLOR.a *= 1.0 - (progress * 0.0); }
"""


func _make_engine(size: int = 1) -> StdEffectPlayer:
	var engine: StdEffectPlayer = StdEffectPlayer.new()
	var _configured: Variant = engine.configure_pools(size, size, size).unwrap()
	return engine


func _teardown(engine: StdEffectPlayer) -> void:
	engine.stop_all()
	engine.free()
	return


func _make_frames(loop: bool = false, count: int = 3) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_loop(&"default", loop)
	for i: int in count:
		frames.add_frame(&"default", PlaceholderTexture2D.new())
		pass
	return frames


func _make_sprite_recipe(
		id: StringName,
		one_shot: bool = true,
		loop: bool = false,
) -> StdSpriteEffectRecipe:
	var recipe: StdSpriteEffectRecipe = StdSpriteEffectRecipe.new()
	recipe._id = id
	recipe._frames = _make_frames(loop)
	recipe._speed_scale = 2.0
	recipe._scale = Vector2(3, 3)
	recipe._modulate = Color.RED
	recipe._z_index = 42
	recipe.one_shot = one_shot
	return recipe


func _make_particle_recipe(id: StringName) -> StdParticleEffectRecipe:
	var recipe: StdParticleEffectRecipe = StdParticleEffectRecipe.new()
	recipe._id = id
	recipe._process_material = ParticleProcessMaterial.new()
	recipe._amount = 12
	recipe._lifetime = 0.5
	return recipe


func _make_shader_recipe(id: StringName, duration: float = 0.1) -> StdShaderEffectRecipe:
	var recipe: StdShaderEffectRecipe = StdShaderEffectRecipe.new()
	recipe._id = id
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	recipe._shader = shader
	recipe._params = {&"progress": 0.0}
	recipe._duration = duration
	return recipe


func _sprite(engine: StdEffectPlayer) -> AnimatedSprite2D:
	for child: Node in engine.get_children():
		if child is AnimatedSprite2D: return child
	return null


func _particles(engine: StdEffectPlayer) -> GPUParticles2D:
	for child: Node in engine.get_children():
		if child is GPUParticles2D: return child
	return null


func _test_pool_configuration() -> void:
	var engine: StdEffectPlayer = StdEffectPlayer.new()
	assert_err(engine.configure_pools(-1, 2, 3), "negative capacity errs")
	assert_ok(engine.configure_pools(1, 2, 3), "valid capacities configure atomically")
	assert_eq(engine._sprite_pool, null, "configuration stays lazy")

	var played: StdResult = engine.play(_make_sprite_recipe(&"aura", false))
	assert_ok(played, "first valid playback builds pools")
	assert_eq(engine._sprite_pool.capacity(), 1, "sprite capacity applied")
	assert_eq(engine._particle_pool.capacity(), 2, "particle capacity applied")
	assert_eq(engine._shader_pool.capacity(), 3, "shader capacity applied")
	assert_err(engine.configure_pools(4, 4, 4), "configuration after playback errs")
	_teardown(engine)
	return


func _test_invalid_play_does_not_lock_configuration() -> void:
	var engine: StdEffectPlayer = StdEffectPlayer.new()
	assert_err(engine.play(null), "null recipe errs")
	var empty: StdSpriteEffectRecipe = StdSpriteEffectRecipe.new()
	empty.one_shot = false
	assert_err(engine.play(empty), "invalid sprite errs")
	assert_eq(engine._sprite_pool, null, "invalid recipes do not build pools")
	assert_ok(engine.configure_pools(1, 1, 1), "configuration remains open")
	_teardown(engine)
	return


func _test_zero_capacity_disables_kind() -> void:
	var engine: StdEffectPlayer = StdEffectPlayer.new()
	assert_ok(engine.configure_pools(0, 1, 1), "zero capacity is accepted")
	var rv: StdResult = engine.play(_make_sprite_recipe(&"aura", false))
	assert_err(rv, "disabled sprite pool rejects playback")
	assert_true(String(rv.unwrap_err()).contains("sprite"), "exhaustion names the effect kind")
	assert_true(String(rv.unwrap_err()).contains("0/0"), "exhaustion reports usage and capacity")
	assert_true(String(rv.unwrap_err()).contains("configure_pools"), "exhaustion names the remedy")
	_teardown(engine)
	return


func _test_play_returns_handle_and_configures_private_sprite() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var recipe: StdSpriteEffectRecipe = _make_sprite_recipe(&"aura", false)
	var rv: StdResult = engine.play(recipe, Vector2(64, 32))
	assert_ok(rv, "managed sprite plays")
	var handle: StdEffectHandle = rv.unwrap()
	assert_true(handle is StdEffectHandle, "managed play returns StdEffectHandle")
	assert_true(handle.is_active(), "new handle is active")
	var sprite: AnimatedSprite2D = _sprite(engine)
	assert_eq(sprite.sprite_frames, recipe._frames, "frames applied")
	assert_eq(sprite.animation, &"default", "animation applied")
	assert_eq(sprite.speed_scale, 2.0, "speed scale applied")
	assert_eq(sprite.scale, Vector2(3, 3), "scale applied")
	assert_eq(sprite.modulate, Color.RED, "modulate applied")
	assert_eq(sprite.z_index, 42, "z index applied")
	assert_eq(sprite.position, Vector2(64, 32), "position applied")
	assert_true(sprite.visible, "sprite is shown")
	_teardown(engine)
	return


func _test_kind_routing_is_enforced() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var oneshot: StdSpriteEffectRecipe = _make_sprite_recipe(&"pop", true)
	var managed: StdSpriteEffectRecipe = _make_sprite_recipe(&"aura", false)
	var particle: StdParticleEffectRecipe = _make_particle_recipe(&"sparks")
	var shader: StdShaderEffectRecipe = _make_shader_recipe(&"flash")
	var target: Control = Control.new()

	assert_err(engine.play(oneshot), "one-shot sprite through play errs")
	assert_err(engine.play_oneshot(managed), "managed sprite through play_oneshot errs")
	assert_err(engine.play(particle), "particle through play errs")
	assert_err(engine.play(shader), "shader through play errs")
	assert_err(engine.play_oneshot(shader), "shader through play_oneshot errs")
	assert_err(engine.play_on(oneshot, target), "sprite through play_on errs")
	assert_err(engine.play_on(particle, target), "particle through play_on errs")

	target.free()
	_teardown(engine)
	return


func _test_recipe_validation() -> void:
	var engine: StdEffectPlayer = StdEffectPlayer.new()
	var no_frames: StdSpriteEffectRecipe = StdSpriteEffectRecipe.new()
	no_frames.one_shot = true
	assert_err(engine.play_oneshot(no_frames), "sprite without frames errs")

	var no_animation: StdSpriteEffectRecipe = _make_sprite_recipe(&"no_animation")
	no_animation._animation = &""
	assert_err(engine.play_oneshot(no_animation), "empty animation name errs")
	var empty_animation: StdSpriteEffectRecipe = _make_sprite_recipe(&"empty_animation")
	empty_animation._frames = _make_frames(false, 0)
	assert_err(engine.play_oneshot(empty_animation), "animation without frames errs")
	var stopped_animation: StdSpriteEffectRecipe = _make_sprite_recipe(&"stopped")
	stopped_animation._speed_scale = 0.0
	assert_err(engine.play_oneshot(stopped_animation), "non-positive sprite speed errs")
	stopped_animation._speed_scale = NAN
	assert_err(engine.play_oneshot(stopped_animation), "NaN sprite speed errs")

	var particle: StdParticleEffectRecipe = _make_particle_recipe(&"bad_particle")
	particle._amount = 0
	assert_err(engine.play_oneshot(particle), "non-positive particle amount errs")
	particle._amount = 1
	particle._lifetime = 0.0
	assert_err(engine.play_oneshot(particle), "non-positive particle lifetime errs")
	particle._lifetime = INF
	assert_err(engine.play_oneshot(particle), "infinite particle lifetime errs")
	particle._lifetime = 1.0
	particle._explosiveness = 2.0
	assert_err(engine.play_oneshot(particle), "out-of-range explosiveness errs")
	particle._explosiveness = NAN
	assert_err(engine.play_oneshot(particle), "NaN explosiveness errs")

	var shader: StdShaderEffectRecipe = _make_shader_recipe(&"bad_shader")
	shader._tween_param = &""
	var target: Control = Control.new()
	assert_err(engine.play_on(shader, target), "empty tween parameter errs")
	shader._tween_param = &"progress"
	shader._duration = 0.0
	assert_err(engine.play_on(shader, target), "non-positive shader duration errs")
	shader._duration = INF
	assert_err(engine.play_on(shader, target), "infinite shader duration errs")
	assert_eq(engine._sprite_pool, null, "invalid recipes acquire nothing")

	target.free()
	_teardown(engine)
	return


func _test_looping_oneshot_is_rejected() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var looping: StdSpriteEffectRecipe = _make_sprite_recipe(&"loop", true, true)
	assert_err(engine.play_oneshot(looping), "looping one-shot would leak and errs")
	assert_eq(engine._sprite_pool, null, "rejected loop builds no pools")
	looping.one_shot = false
	var handle: StdEffectHandle = engine.play(looping).unwrap()
	assert_true(handle.is_active(), "managed loop is active")
	assert_ok(handle.stop(), "managed loop stops explicitly")
	_teardown(engine)
	return


func _test_particle_burst_releases_on_finished() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var recipe: StdParticleEffectRecipe = _make_particle_recipe(&"sparks")
	var rv: StdResult = engine.play_oneshot(recipe, Vector2(10, 20))
	assert_ok(rv, "particle burst plays")
	assert_eq(rv.unwrap(), true, "one-shot returns no handle")
	var emitter: GPUParticles2D = _particles(engine)
	assert_eq(emitter.amount, 12, "amount applied")
	assert_eq(emitter.lifetime, 0.5, "lifetime applied")
	assert_eq(emitter.position, Vector2(10, 20), "position applied")
	assert_eq(engine._particle_pool.active_count(), 1, "emitter is acquired")
	emitter.finished.emit()
	assert_eq(engine._particle_pool.active_count(), 0, "finished releases emitter")
	_teardown(engine)
	return


func _test_pool_exhaustion_and_reuse() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var recipe: StdSpriteEffectRecipe = _make_sprite_recipe(&"aura", false)
	var first: StdEffectHandle = engine.play(recipe).unwrap()
	var exhausted: StdResult = engine.play(recipe)
	assert_err(exhausted, "second managed effect exhausts pool")
	assert_true(String(exhausted.unwrap_err()).contains("1/1"), "exhaustion reports active capacity")
	assert_ok(first.stop(), "handle releases slot")
	assert_ok(engine.play(recipe), "slot is reusable")
	_teardown(engine)
	return


func _test_handle_stop_and_foreign_rejection() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var recipe: StdSpriteEffectRecipe = _make_sprite_recipe(&"aura", false)
	var handle: StdEffectHandle = engine.play(recipe).unwrap()
	assert_ok(handle.stop(), "handle stops its effect")
	assert_true(not handle.is_active(), "stopped handle is inactive")
	assert_err(handle.stop(), "double stop errs")
	assert_err(engine.stop(null), "null handle errs")

	var foreign_engine: StdEffectPlayer = _make_engine()
	var foreign: StdEffectHandle = foreign_engine.play(recipe).unwrap()
	assert_err(engine.stop(foreign), "foreign handle errs")
	_teardown(foreign_engine)
	_teardown(engine)
	return


func _test_managed_natural_finish_releases_and_notifies() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var handle: StdEffectHandle = engine.play(_make_sprite_recipe(&"aura", false)).unwrap()
	var notifications: Array[bool] = []
	var _e: int = handle.finished.connect(func() -> void: notifications.append(true))
	_sprite(engine).animation_finished.emit()
	assert_eq(engine._sprite_pool.active_count(), 0, "natural finish releases sprite")
	assert_true(not handle.is_active(), "natural finish invalidates handle")
	assert_eq(notifications.size(), 1, "natural finish emits handle finished")
	assert_err(handle.stop(), "naturally finished handle cannot stop")
	_teardown(engine)
	return


func _test_manual_stop_is_silent() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var handle: StdEffectHandle = engine.play(_make_sprite_recipe(&"aura", false)).unwrap()
	var notifications: Array[bool] = []
	var _e: int = handle.finished.connect(func() -> void: notifications.append(true))
	assert_ok(handle.stop(), "manual stop succeeds")
	assert_eq(notifications.size(), 0, "manual stop does not emit finished")
	_teardown(engine)
	return


func _test_shader_natural_completion_restores_material() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var recipe: StdShaderEffectRecipe = _make_shader_recipe(&"flash")
	var target: Control = Control.new()
	var original: CanvasItemMaterial = CanvasItemMaterial.new()
	target.material = original
	var rv: StdResult = engine.play_on(recipe, target)
	assert_ok(rv, "shader effect runs headless")
	var handle: StdEffectHandle = rv.unwrap()
	assert_true(handle.is_active(), "off-tree shader remains managed")
	var runner: StdShaderEffectRunner = null
	for child: Node in engine.get_children():
		if child is StdShaderEffectRunner:
			runner = child
			break
	assert_true(runner != null, "private shader runner exists")
	runner._on_tween_finished()
	assert_true(not handle.is_active(), "natural completion invalidates handle")
	assert_eq(target.material, original, "original material is restored")
	assert_eq(engine._shader_pool.active_count(), 0, "runner auto-releases")
	target.free()
	_teardown(engine)
	return


func _test_shader_overlap_and_material_ownership() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var recipe: StdShaderEffectRecipe = _make_shader_recipe(&"flash", 10.0)
	var target: Control = Control.new()
	var original: CanvasItemMaterial = CanvasItemMaterial.new()
	target.material = original
	var first: StdResult = engine.play_on(recipe, target)
	assert_ok(first, "first shader starts")
	assert_true(first.unwrap() is StdEffectHandle, "shader returns StdEffectHandle")
	assert_err(engine.play_on(recipe, target), "overlapping shader on target errs")
	assert_true(target.material is ShaderMaterial, "first shader remains applied")

	var external: CanvasItemMaterial = CanvasItemMaterial.new()
	target.material = external
	assert_ok(first.unwrap().stop(), "shader handle stops")
	assert_eq(target.material, external, "stop preserves newer external material")
	assert_ok(engine.play_on(recipe, target), "target is reusable after stop")
	engine.stop_all()

	target.free()
	_teardown(engine)
	return


func _test_shader_rejects_bad_targets_and_assets() -> void:
	var engine: StdEffectPlayer = _make_engine()
	var recipe: StdShaderEffectRecipe = _make_shader_recipe(&"flash")
	assert_err(engine.play_on(recipe, null), "null target errs")
	var dying: Control = Control.new()
	dying.queue_free()
	assert_err(engine.play_on(recipe, dying), "queued target errs")
	var no_shader: StdShaderEffectRecipe = StdShaderEffectRecipe.new()
	var target: Control = Control.new()
	assert_err(engine.play_on(no_shader, target), "missing shader errs")
	target.free()
	_teardown(engine)
	return


func _test_stop_all_releases_every_kind_and_invalidates_handles() -> void:
	var engine: StdEffectPlayer = _make_engine(2)
	var managed: StdSpriteEffectRecipe = _make_sprite_recipe(&"aura", false)
	var first: StdEffectHandle = engine.play(managed).unwrap()
	var second: StdEffectHandle = engine.play(managed).unwrap()
	assert_ok(engine.play_oneshot(_make_particle_recipe(&"sparks")), "particle active before stop_all")
	engine.stop_all()
	assert_true(not first.is_active(), "stop_all invalidates first handle")
	assert_true(not second.is_active(), "stop_all invalidates second handle")
	assert_eq(engine._sprite_pool.active_count(), 0, "all sprites released")
	assert_eq(engine._particle_pool.active_count(), 0, "all particles released")
	assert_ok(engine.play(managed), "pools remain reusable")
	_teardown(engine)
	return
