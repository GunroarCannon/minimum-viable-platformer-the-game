extends PlatformerController2D

@export var run_speed: float = 600.0
@export var auto_acceleration: float = 280.0  # How fast auto-run momentum builds up (px/s^2)

func _ready() -> void:
	print("[Player] _ready() START — calling super._ready() first")
	super._ready()   # <-- CRITICAL: initialises anim, col, ready_physics, _updateData etc.
	print("[Player] super._ready() complete. anim=", anim, " col=", col, " ready_physics=", ready_physics)
	print("[Player] PlayerSprite export ref: ", PlayerSprite)
	print("[Player] PlayerCollider export ref: ", PlayerCollider)
	_auto_setup_sprite_frames()
	
	# Apply tweakable run speed to the underlying controller logic
	maxSpeed = run_speed
	maxSpeedLock = run_speed
	
	# Set up the two Area2D sensors for stomp/death detection
	_setup_sensors()
	_setup_debug_ui()
	
	print("[Player] _ready() END. Position: ", position)

## Automatically creates a SpriteFrames resource with all required animation states.
func _auto_setup_sprite_frames() -> void:
	print("[Player] _auto_setup_sprite_frames() called")

	if not anim:
		push_error("[Player] ERROR — anim is null! PlayerSprite export was not assigned.")
		return

	print("[Player] anim node: ", anim, " | current scale: ", anim.scale)

	var placeholder_texture = load("res://a.png")
	if not placeholder_texture:
		push_warning("[Player] WARNING — 'res://a.png' not found.")
	else:
		var tex_size = placeholder_texture.get_size()
		print("[Player] Loaded a.png — size: ", tex_size)

	var new_frames = SpriteFrames.new()

	var required_animations = [
		"idle", "run", "walk", "jump", "falling",
		"slide", "latch", "crouch_idle", "crouch_walk", "roll"
	]

	for anim_name in required_animations:
		if anim_name == "idle" and new_frames.has_animation("default"):
			new_frames.rename_animation("default", "idle")
		elif not new_frames.has_animation(anim_name):
			new_frames.add_animation(anim_name)

		new_frames.set_animation_speed(anim_name, 10.0)
		new_frames.set_animation_loop(anim_name, true)

		if placeholder_texture:
			new_frames.add_frame(anim_name, placeholder_texture)
			print("[Player]   Added frame to animation '", anim_name, "'")

	anim.sprite_frames = new_frames
	print("[Player] SpriteFrames assigned to anim node")

	# Scale sprite to visually fit the collision box size.
	# Collision box is 80x110 px. Compute scale from actual texture dimensions.
	if placeholder_texture:
		var tex_size = placeholder_texture.get_size()
		var target_size = Vector2(80.0, 110.0)
		var new_scale = target_size / tex_size
		anim.scale = new_scale
		# Keep animScaleLock in sync so flipping works correctly in the base class
		animScaleLock = abs(new_scale)
		print("[Player] Sprite scale set to: ", new_scale, " | animScaleLock synced: ", animScaleLock)

	anim.play("idle")
	print("[Player] Playing 'idle' animation. anim.visible=", anim.visible,
		  " | anim.modulate=", anim.modulate,
		  " | anim.scale=", anim.scale,
		  " | anim.position=", anim.position)

@onready var dust_particles: CPUParticles2D = $DustParticles
var _was_on_floor: bool = false
var is_dead: bool = false
var game_over_ui: Node = null
var death_y_limit: float = 99999.0
var debug_label: Label = null

# Momentum-based auto-run
var auto_momentum: float = 0.0   # current auto-run speed, builds up to run_speed
var stun_timer: float = 0.0      # when > 0, auto-run is suppressed (e.g. after knockback)

# Dynamic zoom
var _base_zoom: float = 1.0          # set by level_generator after camera is created
var _zoom_tweened_out: bool = false  # tracks current tween state
var _zoom_tween: Tween = null        # active tween reference

# Two Area2D sensors added at runtime:
var _foot_sensor: Area2D = null    # small area just below feet → stomps enemy
var _body_sensor: Area2D = null    # full body area on Layer 8 → enemies kill us
var _screen_sensor: Area2D = null  # screen-sized area for tile counting (zoom mode 2)
var _screen_shape: RectangleShape2D = null  # reference kept so we can resize it each frame

func _setup_sensors() -> void:
	# --- Foot sensor (stomp detection) ---
	_foot_sensor = Area2D.new()
	_foot_sensor.collision_layer = 0
	_foot_sensor.collision_mask  = 4  # enemy hitbox layer
	var foot_shape = CollisionShape2D.new()
	var foot_rect  = RectangleShape2D.new()
	foot_rect.size = Vector2(50, 20)
	foot_shape.shape = foot_rect
	foot_shape.position = Vector2(0, 60)   # just below feet
	_foot_sensor.add_child(foot_shape)
	add_child(_foot_sensor)
	_foot_sensor.area_entered.connect(_on_foot_sensor_area_entered)
	_foot_sensor.body_entered.connect(_on_foot_sensor_body_entered)

	# --- Screen sensor (tile counting for dynamic zoom mode 2) ---
	_screen_sensor = Area2D.new()
	_screen_sensor.collision_layer = 0
	_screen_sensor.collision_mask  = 1  # Layer 1 = solid tiles / floor
	_screen_sensor.monitoring = true
	_screen_sensor.monitorable = false
	_screen_shape = RectangleShape2D.new()
	_screen_shape.size = Vector2(1280, 720)  # initial size, updated every frame
	var screen_coll = CollisionShape2D.new()
	screen_coll.shape = _screen_shape
	_screen_sensor.add_child(screen_coll)
	add_child(_screen_sensor)

	# --- Body sensor (death on touch) ---
	_body_sensor = Area2D.new()
	_body_sensor.collision_layer = 8   # Layer 8 — enemies look for this
	_body_sensor.collision_mask  = 0
	var body_shape = CollisionShape2D.new()
	var body_rect  = RectangleShape2D.new()
	body_rect.size = Vector2(60, 90)
	body_shape.shape = body_rect
	body_shape.position = Vector2(0, 0)
	_body_sensor.add_child(body_shape)
	add_child(_body_sensor)

func _on_foot_sensor_area_entered(area: Area2D) -> void:
	if is_dead: return
	# Only stomp if we're falling
	if velocity.y > 50:
		var enemy = area.get_parent()
		if enemy and enemy.has_method("stomp_by"):
			enemy.stomp_by(self)

func _on_foot_sensor_body_entered(body: Node) -> void:
	if is_dead: return
	if velocity.y > 50:
		if body.has_method("stomp_by"):
			body.stomp_by(self)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead: return
	if event is InputEventKey or event is InputEventScreenTouch:
		if event.is_pressed() and not event.is_echo():
			Input.action_press("jump")
		elif not event.is_pressed():
			Input.action_release("jump")

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += terminalVelocity * delta
		# Bleed off horizontal speed by 2 units per physics frame
		velocity.x = move_toward(velocity.x, 0.0, 2.0)
		move_and_slide()
		return

	var local_limit = get_local_lowest_y() + 384.0
	if global_position.y > local_limit:
		die(true)
		return

	# ——— Momentum-based auto-run ———
	if stun_timer > 0.0:
		# Knockback/stun: bleed momentum to zero and don't press right
		stun_timer -= get_physics_process_delta_time()
		auto_momentum = move_toward(auto_momentum, 0.0, auto_acceleration * get_physics_process_delta_time() * 4.0)
		Input.action_release("right")
	else:
		# Gradually build momentum up to run_speed
		auto_momentum = move_toward(auto_momentum, run_speed, auto_acceleration * get_physics_process_delta_time())
		# Only press "right" in proportion to momentum (simulate gentle ramp-up)
		if auto_momentum > 20.0:
			Input.action_press("right")
		else:
			Input.action_release("right")
		# Clamp max velocity to the current auto momentum cap
		if velocity.x > auto_momentum:
			velocity.x = auto_momentum

	_was_on_floor = is_on_floor()
	super._physics_process(delta)

	# Jump stretch
	if not _was_on_floor and velocity.y < 0 and jumpTap:
		if dust_particles:
			dust_particles.restart()
			dust_particles.emitting = true
		_squash_and_stretch(Vector2(0.6, 1.4))

	# Land squash
	if is_on_floor() and not _was_on_floor:
		if dust_particles:
			dust_particles.restart()
			dust_particles.emitting = true
		_squash_and_stretch(Vector2(1.4, 0.6))
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider is TileObject:
				collider.squash()

func _squash_and_stretch(target_scale_modifier: Vector2) -> void:
	if not anim: return
	var base_scale = animScaleLock
	if anim.scale.x < 0:
		base_scale.x *= -1
		target_scale_modifier.x *= -1
	var squished_scale = base_scale * abs(target_scale_modifier)
	squished_scale.x *= sign(anim.scale.x) if anim.scale.x != 0 else 1
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(anim, "scale", squished_scale, 0.1)
	tween.tween_property(anim, "scale", base_scale, 0.15)

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var _shake_timer: float = 0.0

func shake_camera(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
	_shake_timer = duration

func _process(delta: float) -> void:
	super._process(delta)
	if _shake_timer > 0:
		_shake_timer -= delta
		var cam = _get_camera()
		if cam:
			var t = max(_shake_timer / shake_duration, 0.0)
			var amt = shake_intensity * t
			cam.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
			if _shake_timer <= 0:
				cam.offset = Vector2.ZERO
	_update_dynamic_zoom(delta)
	_update_debug_text()

func _update_dynamic_zoom(_delta: float) -> void:
	var cam = _get_camera()
	if not cam or _base_zoom <= 0.0: return

	var should_zoom_out := false

	match Global.camera_zoom_mode:
		1: # — Hazard Distance mode —
			var hazards = get_tree().get_nodes_in_group("hazards")
			for h in hazards:
				if not h is Node2D: continue
				var dist = h.global_position.x - global_position.x
				# Only care about hazards ahead of the player
				if dist > 0 and dist > Global.camera_hazard_distance:
					should_zoom_out = true
					break

		2: # — Tile Count mode — uses a direct physics shape query (works on StaticBody2D)
			if _screen_shape:
				var vp_size = get_viewport_rect().size
				var world_w = vp_size.x / cam.zoom.x
				var world_h = vp_size.y / cam.zoom.y
				_screen_shape.size = Vector2(world_w, world_h)

				var query = PhysicsShapeQueryParameters2D.new()
				query.shape = _screen_shape
				query.transform = Transform2D(0.0, global_position)
				query.collision_mask = 1  # Layer 1 = solid tiles
				query.collide_with_bodies = true
				query.collide_with_areas = false

				var space = get_world_2d().direct_space_state
				var results = space.intersect_shape(query, 64)  # max 64 results
				var count := 0
				for r in results:
					if r["collider"].is_in_group("solid_tiles"):
						count += 1
				should_zoom_out = count < Global.camera_tile_threshold

	# Only tween when the state changes
	if should_zoom_out and not _zoom_tweened_out:
		_zoom_tweened_out = true
		_do_zoom_tween(cam, _base_zoom * Global.camera_zoom_out_factor)
	elif not should_zoom_out and _zoom_tweened_out:
		_zoom_tweened_out = false
		_do_zoom_tween(cam, _base_zoom)

func _do_zoom_tween(cam: Camera2D, target_zoom: float) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(cam, "zoom", Vector2.ONE * target_zoom, Global.camera_zoom_tween_duration)

func _get_camera() -> Camera2D:
	for child in get_children():
		if child is Camera2D:
			return child
	return null

func die(is_fall: bool = false) -> void:
	if is_dead: return
	is_dead = true

	# Disable sensors so enemies stop triggering further hits
	if _body_sensor:
		_body_sensor.set_deferred("monitoring", false)
		_body_sensor.set_deferred("monitorable", false)
	if _foot_sensor:
		_foot_sensor.set_deferred("monitoring", false)

	# Release actions
	Input.action_release("right")
	Input.action_release("jump")

	if is_fall:
		# Reparent camera to level so it stops following the player down
		var cam = _get_camera()
		if cam:
			var old_global = cam.global_position
			cam.get_parent().remove_child(cam)
			get_parent().add_child(cam)
			cam.global_position = old_global

		# Launch in the OPPOSITE horizontal direction + a little upward
		var launch_dir = -sign(velocity.x) if velocity.x != 0.0 else -1.0
		velocity = Vector2(launch_dir * 300.0, -480.0)

		# Fall-over animation: rotate sprite to lie flat (90°), flash red
		if anim:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(anim, "rotation_degrees", 90.0, 0.35)
			tween.parallel().tween_property(anim, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.2)

		# Poof burst
		var poof = CPUParticles2D.new()
		poof.emitting = true
		poof.one_shot = true
		poof.amount = 40
		poof.lifetime = 0.8
		poof.explosiveness = 0.9
		poof.spread = 180.0
		poof.gravity = Vector2(0, 300)
		poof.initial_velocity_min = 150.0
		poof.initial_velocity_max = 400.0
		poof.scale_amount_min = 6.0
		poof.scale_amount_max = 18.0
		poof.color = Color(0.4, 0.8, 1.0)
		get_parent().add_child(poof)
		poof.global_position = global_position
	else:
		# Tear death!
		collision_layer = 0
		collision_mask = 0
		velocity = Vector2.ZERO
		TearEffect.apply(self, Vector2(80, 110), Color(0.4, 0.8, 1.0), velocity, [], "circular")

	# Wait for player to settle before reloading or showing game-over screen
	await get_tree().create_timer(1.8).timeout
	if Global.debug_toggles.get("auto_restart", false):
		if not Global.debug_toggles.get("keep_seed", false):
			var level_gen = load("res://level_generator.gd")
			if level_gen:
				level_gen.current_seed = 0
		get_tree().reload_current_scene()
	else:
		if game_over_ui and game_over_ui.has_method("show_game_over"):
			game_over_ui.show_game_over()

func _setup_debug_ui() -> void:
	if not Global.debugText: return
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	var bg = Panel.new()
	bg.size = Vector2(250, 120)
	bg.position = Vector2(5, 5)
	canvas_layer.add_child(bg)
	
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_font_size_override("font_size", 14)
	canvas_layer.add_child(debug_label)

	# Dynamic toggle list CheckBoxes
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(5, 135)
	canvas_layer.add_child(vbox)
	
	for key in Global.debug_toggles:
		var cb = CheckBox.new()
		cb.text = key.replace("_", " ").capitalize()
		cb.button_pressed = Global.debug_toggles[key]
		cb.toggled.connect(func(pressed: bool) -> void:
			Global.debug_toggles[key] = pressed
		)
		vbox.add_child(cb)

func _update_debug_text() -> void:
	if debug_label:
		var mem_mb = OS.get_static_memory_usage() / 1024.0 / 1024.0
		var fps = Engine.get_frames_per_second()
		debug_label.text = "FPS: %d\nMemory: %.2f MB\nPos: (%d, %d)\nVel: (%d, %d)\nAuto-run: %.1f\nStun: %.2f" % [
			fps,
			mem_mb,
			global_position.x, global_position.y,
			velocity.x, velocity.y,
			auto_momentum,
			stun_timer
		]

func get_local_lowest_y() -> float:
	var player_x = global_position.x
	var lowest_y = -999999.0
	var found = false
	for tile in get_tree().get_nodes_in_group("solid_tiles"):
		if tile is Node2D:
			if abs(tile.global_position.x - player_x) < 256.0:
				if tile.global_position.y > lowest_y:
					lowest_y = tile.global_position.y
					found = true
	if found:
		return lowest_y
	return 2000.0
