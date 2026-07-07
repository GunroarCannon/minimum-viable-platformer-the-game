extends PlatformerController2D

@export var run_speed: float = 600.0
@export var auto_acceleration: float = 280.0  # How fast auto-run momentum builds up (px/s^2)

# Resolved-once feature flags (cached at _ready for hot-loop reads)
var _use_sprite_player: bool = false
var _use_sprite_anims:  bool = false
var _use_juice:         bool = false
var _use_shake:         bool = false
var _use_zoom:          bool = false
var _use_tears:         bool = false
var _use_particles:     bool = false
var _use_outline:       bool = false
var _use_double_jump:   bool = false
var _use_sprint:        bool = false
var _use_wall_jump:     bool = false
var _use_motion_trail:  bool = false
var _use_footstep_dust: bool = false
var _use_impact_freeze: bool = false
var _use_hit_flash:     bool = false

func _resolve_flags() -> void:
	# When primitives is forced via debug, everything visual stays primitive.
	var primitives = Global.use_primitives
	_use_sprite_player = (not primitives) and Global.is_unlocked("player_sprite")
	_use_sprite_anims  = _use_sprite_player and Global.is_unlocked("sprite_animations")
	_use_juice         = Global.is_unlocked("juice_squash")
	_use_shake         = Global.is_unlocked("camera_shake")
	_use_zoom          = Global.is_unlocked("dynamic_zoom")
	_use_tears         = Global.is_unlocked("tear_effects")
	_use_particles     = Global.is_unlocked("particles")
	_use_outline       = _use_sprite_player and Global.is_unlocked("outline")
	_use_double_jump   = Global.is_unlocked("double_jump")
	_use_sprint        = Global.is_unlocked("sprint")
	_use_wall_jump     = Global.is_unlocked("wall_jump")
	_use_motion_trail  = Global.is_unlocked("motion_trail")
	_use_footstep_dust = Global.is_unlocked("footstep_dust")
	_use_impact_freeze = Global.is_unlocked("impact_freeze")
	_use_hit_flash     = Global.is_unlocked("hit_flash")

func _ready() -> void:
	super._ready()
	add_to_group("player")
	_resolve_flags()
	_auto_setup_sprite_frames()

	if _use_sprint:
		run_speed = 820.0
	if Global.is_unlocked("fast_mode") and bool(Global.settings_cfg.get("fast_mode", false)):
		run_speed *= 1.35
	maxSpeed = run_speed
	maxSpeedLock = run_speed

	# Gameplay-unlock wiring on the addon's existing fields.
	if _use_double_jump:
		jumps = 2
	if _use_wall_jump:
		wallJump = true
	if has_method("_updateData"):
		_updateData()

	_setup_sensors()
	_setup_motion_trail()
	_setup_footstep_dust()
	_apply_outline_material()

func _draw() -> void:
	# Primitive shape if we don't have the player sprite unlocked.
	if not _use_sprite_player:
		draw_rect(Rect2(-40, -55, 80, 110), Color(0.2, 0.4, 0.9, 0.8), true)
		draw_rect(Rect2(10, -35, 15, 15), Color.WHITE, true)
		draw_rect(Rect2(20, -30, 5, 5), Color.BLACK, true)
	if Global.debug_toggles.get("show_collisions", false):
		draw_rect(Rect2(-40, -55, 80, 110), Color.GREEN, false, 2.0)

## Automatically creates a SpriteFrames resource with all required animation states.
func _auto_setup_sprite_frames() -> void:
	if not anim:
		return

	if not _use_sprite_player:
		anim.visible = false
		queue_redraw()
		return

	anim.visible = true

	var new_frames = SpriteFrames.new()
	# Static or animated based on flags.
	var animations_to_load = {
		"idle":        { "path": "res://assets/animations/player/player_idle", "count": 4 if _use_sprite_anims else 1 },
		"run":         { "path": "res://assets/animations/player/player_run",  "count": 7 if _use_sprite_anims else 1 },
		"walk":        { "path": "res://assets/animations/player/player_run",  "count": 7 if _use_sprite_anims else 1 },
		"jump":        { "path": "res://assets/animations/player/player_jump", "count": 7 if _use_sprite_anims else 1 },
		"falling":     { "path": "res://assets/animations/player/player_jump", "count": 7 if _use_sprite_anims else 1 },
		"slide":       { "path": "res://assets/animations/player/player_run",  "count": 7 if _use_sprite_anims else 1 },
		"latch":       { "path": "res://assets/animations/player/player_idle", "count": 4 if _use_sprite_anims else 1 },
		"crouch_idle": { "path": "res://assets/animations/player/player_idle", "count": 4 if _use_sprite_anims else 1 },
		"crouch_walk": { "path": "res://assets/animations/player/player_run",  "count": 7 if _use_sprite_anims else 1 },
		"roll":        { "path": "res://assets/animations/player/player_run",  "count": 7 if _use_sprite_anims else 1 },
		"hurt_1":      { "path": "res://assets/animations/player/player_hurt_1","count": 3 if _use_sprite_anims else 1 },
		"hurt_2":      { "path": "res://assets/animations/player/player_hurt_2","count": 3 if _use_sprite_anims else 1 },
	}

	for anim_name in animations_to_load:
		if not new_frames.has_animation(anim_name):
			new_frames.add_animation(anim_name)
		new_frames.set_animation_speed(anim_name, 10.0 if _use_sprite_anims else 1.0)
		var is_loop = not (anim_name in ["jump", "falling", "hurt_1", "hurt_2"])
		new_frames.set_animation_loop(anim_name, is_loop and _use_sprite_anims)
		var cfg = animations_to_load[anim_name]
		for f in range(cfg["count"]):
			var path = cfg["path"] + "/" + str(f) + ".png"
			var tex = load(path)
			if tex:
				new_frames.add_frame(anim_name, tex)

	anim.sprite_frames = new_frames

	var new_scale = Vector2(0.5, 0.5)
	anim.scale = new_scale
	animScaleLock = abs(new_scale)
	anim.play("idle")


@onready var dust_particles: CPUParticles2D = $DustParticles
var _was_on_floor: bool = false
var is_dead: bool = false
var game_over_ui: Node = null
var death_y_limit: float = 99999.0

# Momentum-based auto-run
var auto_momentum: float = 0.0
var stun_timer: float = 0.0

# Dynamic zoom
var _base_zoom: float = 1.0
var _zoom_tweened_out: bool = false
var _zoom_tween: Tween = null

# Airborne edge-detect for combo system + stat tracking

var _takeoff_y: float = 0.0
var _peak_y: float = 0.0

# Sensors
var _foot_sensor: Area2D = null
var _body_sensor: Area2D = null
var _screen_sensor: Area2D = null
var _screen_shape: RectangleShape2D = null

func _setup_sensors() -> void:
	_foot_sensor = Area2D.new()
	_foot_sensor.collision_layer = 0
	_foot_sensor.collision_mask  = 4
	var foot_shape = CollisionShape2D.new()
	var foot_rect  = RectangleShape2D.new()
	foot_rect.size = Vector2(50, 20)
	foot_shape.shape = foot_rect
	foot_shape.position = Vector2(0, 60)
	_foot_sensor.add_child(foot_shape)
	add_child(_foot_sensor)
	_foot_sensor.area_entered.connect(_on_foot_sensor_area_entered)
	_foot_sensor.body_entered.connect(_on_foot_sensor_body_entered)

	_screen_sensor = Area2D.new()
	_screen_sensor.collision_layer = 0
	_screen_sensor.collision_mask  = 1
	_screen_sensor.monitoring = true
	_screen_sensor.monitorable = false
	_screen_shape = RectangleShape2D.new()
	_screen_shape.size = Vector2(1280, 720)
	var screen_coll = CollisionShape2D.new()
	screen_coll.shape = _screen_shape
	_screen_sensor.add_child(screen_coll)
	add_child(_screen_sensor)

	_body_sensor = Area2D.new()
	_body_sensor.collision_layer = 8
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
	if velocity.y > 50:
		var enemy = area.get_parent()
		if enemy and enemy.has_method("stomp_by"):
			enemy.stomp_by(self)
			_kick_impact_juice()
			ComboSystem.notify_stomp(global_position)
			Global.stat_add("enemies_stomped", 1)

func _on_foot_sensor_body_entered(body: Node) -> void:
	if is_dead: return
	if velocity.y > 50 and body.has_method("stomp_by"):
		body.stomp_by(self)
		_kick_impact_juice()
		ComboSystem.notify_stomp(global_position)
		Global.stat_add("enemies_stomped", 1)

# Brief slow-mo + chromatic kick on stomp. No-op if either unlock is off.
func _kick_impact_juice() -> void:
	if _use_impact_freeze:
		Engine.time_scale = 0.06
		# Process-always + ignore-time-scale so the reset still fires at wall time.
		var t = get_tree().create_timer(0.05, true, false, true)
		t.timeout.connect(func(): Engine.time_scale = 1.0)
	if Global.is_unlocked("chromatic_aberration"):
		ScreenFX.kick_chromatic(0.020, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead: return
	if event is InputEventKey or event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo():
			Input.action_press("jump")
		elif not event.is_pressed():
			Input.action_release("jump")

# ─── MOTION TRAIL ──────────────────────────────────────────────────────────
var _trail: Line2D = null
var _trail_points: Array[Vector2] = []
const TRAIL_LEN := 14

func _setup_motion_trail() -> void:
	if not _use_motion_trail: return
	_trail = Line2D.new()
	_trail.width = 28.0
	_trail.default_color = Color(0.2, 0.4, 0.9, 0.45)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	_trail.width_curve = curve
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.z_index = -1
	# Trail is drawn in WORLD space — parent it to the level so it doesn't rotate with us on death.
	call_deferred("_attach_trail_to_world")

func _attach_trail_to_world() -> void:
	if _trail == null: return
	if get_parent() == null: return
	get_parent().add_child(_trail)
	# After this, points pushed into the line are in world coords.

func _tick_motion_trail() -> void:
	if _trail == null: return
	_trail_points.push_front(global_position + Vector2(0, -16))
	if _trail_points.size() > TRAIL_LEN:
		_trail_points.pop_back()
	_trail.clear_points()
	for p in _trail_points:
		_trail.add_point(p)

# ─── FOOTSTEP DUST ─────────────────────────────────────────────────────────
var _foot_dust: CPUParticles2D = null

func _setup_footstep_dust() -> void:
	if not _use_footstep_dust: return
	_foot_dust = CPUParticles2D.new()
	_foot_dust.amount = 16
	_foot_dust.lifetime = 0.42
	_foot_dust.one_shot = false
	_foot_dust.emitting = false
	_foot_dust.explosiveness = 0.0
	_foot_dust.spread = 50.0
	_foot_dust.direction = Vector2(0, -1)
	_foot_dust.gravity = Vector2(0, 240)
	_foot_dust.initial_velocity_min = 60.0
	_foot_dust.initial_velocity_max = 160.0
	_foot_dust.scale_amount_min = 3.5
	_foot_dust.scale_amount_max = 9.0
	_foot_dust.color = Color(0.85, 0.74, 0.55, 0.8)
	_foot_dust.position = Vector2(0, 52)
	add_child(_foot_dust)

func _tick_footstep_dust() -> void:
	if _foot_dust == null: return
	_foot_dust.emitting = is_on_floor() and abs(velocity.x) > 220.0

# ─── HIT FLASH (white) on stun edge ────────────────────────────────────────
var _prev_stun: float = 0.0
func _maybe_hit_flash() -> void:
	if not _use_hit_flash: return
	if stun_timer > 0.0 and _prev_stun <= 0.0:
		var target = anim if (anim and _use_sprite_player) else self
		var tw = create_tween()
		var orig = target.modulate
		tw.tween_property(target, "modulate", Color(1.6, 1.6, 1.6, target.modulate.a), 0.05)
		tw.tween_property(target, "modulate", orig, 0.18)
	_prev_stun = stun_timer

# ─── OUTLINE SHADER ────────────────────────────────────────────────────────
func _apply_outline_material() -> void:
	if not _use_outline: return
	if not anim: return
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/outline.gdshader")
	mat.set_shader_parameter("outline_color", Color(0.10, 0.07, 0.05, 1.0))
	mat.set_shader_parameter("outline_width", 2.2)
	anim.material = mat


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += terminalVelocity * delta
		velocity.x = move_toward(velocity.x, 0.0, 2.0)
		move_and_slide()
		return

	# The addon's multi-jump path (jumps > 1) blocks jump when is_on_wall() is true.
	# Force it here before super runs so the player can still jump off the floor
	# when pressing against a wall.
	if jumps > 1 and is_on_floor() and is_on_wall():
		if Input.is_action_just_pressed("jump"):
			velocity.y = -jumpMagnitude

	var local_limit = get_local_lowest_y() + 192.0
	if global_position.y > local_limit:
		die(true)
		return

	if stun_timer > 0.0:
		stun_timer -= delta
		auto_momentum = move_toward(auto_momentum, 0.0, auto_acceleration * delta * 4.0)
		Input.action_release("right")
	else:
		auto_momentum = move_toward(auto_momentum, run_speed, auto_acceleration * delta)
		if auto_momentum > 20.0:
			Input.action_press("right")
		else:
			Input.action_release("right")
		if velocity.x > auto_momentum:
			velocity.x = auto_momentum

	_was_on_floor = is_on_floor()
	_maybe_hit_flash()
	super._physics_process(delta)

	# Jump stretch
	if not _was_on_floor and velocity.y < 0 and jumpTap:
		if dust_particles and _use_particles:
			dust_particles.restart()
			dust_particles.emitting = true
		if _use_juice:
			_squash_and_stretch(Vector2(0.6, 1.4))
		if anim and _use_sprite_anims:
			anim.frame = 0
			anim.play("jump")

	# Land squash
	if is_on_floor() and not _was_on_floor:
		if dust_particles and _use_particles:
			dust_particles.restart()
			dust_particles.emitting = true
		if _use_juice:
			_squash_and_stretch(Vector2(1.4, 0.6))
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider and collider.has_method("squash"):
				collider.squash()

	# Track best distance in real time
	var d := int(global_position.x / 128.0)
	if d > Global.last_run_distance:
		Global.stat_add("total_distance_m", d - Global.last_run_distance)
		Global.last_run_distance = d

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
	if not _use_shake: return
	shake_intensity = intensity
	shake_duration = duration
	_shake_timer = duration

func _process(delta: float) -> void:
	super._process(delta)
	if is_dead:
		ScreenFX.wobble_intensity = 0.0
		return
	if Global.debug_toggles.get("show_collisions", false):
		queue_redraw()
	# Drive in-air warp shader intensity from vertical speed.
	if Global.is_unlocked("wobble_shader"):
		var vel_y_abs = abs(velocity.y)
		var target_wobble 	= clamp(vel_y_abs / 1200.0, 0.0, 1.0)
		if is_on_floor():
			target_wobble = 0.0
		ScreenFX.wobble_intensity = move_toward(ScreenFX.wobble_intensity, target_wobble, delta * 5.0)
	else:
		ScreenFX.wobble_intensity = 0.0
	# Combo/airtime tracking — edge-detect ground contact.
	var on_floor := is_on_floor()
	if on_floor != _was_on_floor:
		ComboSystem.notify_airborne(not on_floor)
		if not on_floor and velocity.y < -50.0:
			# Leaving the ground upward → count as a jump.
			Global.stat_add("jumps", 1)
			_takeoff_y = global_position.y
			_peak_y = global_position.y
		elif on_floor and _takeoff_y != 0.0:
			var jump_h := int(_takeoff_y - _peak_y)
			if jump_h > 0:
				Global.stat_max("highest_jump_px", jump_h)
			_takeoff_y = 0.0
		_was_on_floor = on_floor
	if not on_floor and global_position.y < _peak_y:
		_peak_y = global_position.y

	if _shake_timer > 0:
		_shake_timer -= delta
		var cam = _get_camera()
		if cam:
			var t = max(_shake_timer / shake_duration, 0.0)
			var amt = shake_intensity * t
			cam.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
			if _shake_timer <= 0:
				cam.offset = Vector2.ZERO
	if _use_zoom:
		_update_dynamic_zoom(delta)
	_tick_motion_trail()
	_tick_footstep_dust()

func _update_dynamic_zoom(_delta: float) -> void:
	var cam = _get_camera()
	if not cam or _base_zoom <= 0.0: return

	var should_zoom_out := false

	match Global.camera_zoom_mode:
		1:
			var hazards = get_tree().get_nodes_in_group("hazards")
			for h in hazards:
				if not h is Node2D: continue
				var dist = h.global_position.x - global_position.x
				if dist > 0 and dist > Global.camera_hazard_distance:
					should_zoom_out = true
					break
		2:
			if _screen_shape:
				var vp_size = get_viewport_rect().size
				var world_w = vp_size.x / cam.zoom.x
				var world_h = vp_size.y / cam.zoom.y
				_screen_shape.size = Vector2(world_w, world_h)

				var query = PhysicsShapeQueryParameters2D.new()
				query.shape = _screen_shape
				query.transform = Transform2D(0.0, global_position)
				query.collision_mask = 1
				query.collide_with_bodies = true
				query.collide_with_areas = false

				var space = get_world_2d().direct_space_state
				var results = space.intersect_shape(query, 64)
				var count := 0
				for r in results:
					var c = r["collider"]
					if not c.is_in_group("solid_tiles"): continue
					# Strips bundle many tile-units in one body — count them properly.
					if c is TileStrip:
						count += int(c.length_tiles)
					else:
						count += 1
				should_zoom_out = count < Global.camera_tile_threshold

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

func die(is_fall: bool = false, cause: String = "") -> void:
	if is_dead: return
	is_dead = true
	if cause == "" and is_fall:
		cause = "the fall"
	Global.last_death_cause = cause
	Global.stat_add("deaths", 1)
	if cause != "":
		Global.stat_bucket("deaths_by_cause", cause, 1)
	Global.stat_max("longest_run_m", Global.last_run_distance)

	if _body_sensor:
		_body_sensor.set_deferred("monitoring", false)
		_body_sensor.set_deferred("monitorable", false)
	if _foot_sensor:
		_foot_sensor.set_deferred("monitoring", false)

	Input.action_release("right")
	Input.action_release("jump")

	# In ALL death modes, detach the camera so it stops chasing the dying body.
	# (Tear effects can free the player, taking child nodes with it.)
	var cam = _get_camera()
	if cam:
		var old_global = cam.global_position
		cam.offset = Vector2.ZERO
		cam.position_smoothing_enabled = false
		cam.get_parent().remove_child(cam)
		get_parent().add_child(cam)
		cam.global_position = old_global
		cam.make_current()
	_shake_timer = 0.0

	# Splatter — parented to the level so it survives a tear-effect that hides us.
	BloodSplat.apply(get_parent(), global_position, velocity)

	if is_fall:
		if anim:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(anim, "rotation_degrees", 90.0, 0.35)
			tween.parallel().tween_property(anim, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.2)

		if _use_particles:
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
		collision_layer = 0
		collision_mask = 0
		velocity = Vector2.ZERO

		# Death flash + squash animation before the tear/hide.
		var target_node: Node = anim if (anim and _use_sprite_player) else self
		var death_flash := create_tween()
		death_flash.tween_property(target_node, "modulate",
			Color(2.5, 2.5, 2.5, 1.0), 0.05)
		death_flash.tween_property(target_node, "modulate",
			Color(1.0, 0.18, 0.18, 1.0), 0.10)
		if _use_juice and anim and _use_sprite_player:
			var base_s: Vector2 = animScaleLock if animScaleLock != Vector2.ZERO else Vector2(0.5, 0.5)
			death_flash.parallel().tween_property(anim, "scale",
				base_s * Vector2(1.5, 0.5), 0.07)
			death_flash.tween_property(anim, "scale",
				base_s, 0.12).set_trans(Tween.TRANS_BACK)
		await death_flash.finished

		if anim and _use_sprite_anims:
			var anim_name = "hurt_1" if randf() < 0.5 else "hurt_2"
			anim.play(anim_name)
			await get_tree().process_frame
		if _use_tears:
			TearEffect.apply(self, Vector2(80, 110), Color(0.4, 0.8, 1.0), velocity, [], "circular")
		else:
			if anim: anim.visible = false
			visible = _use_sprite_player  # keep something to look at unless primitives

	# Award tokens & remember distance
	var distance_tiles = max(Global.last_run_distance, int(global_position.x / 128.0))
	var awarded = Global.on_player_death(distance_tiles)

	await get_tree().create_timer(1.4).timeout

	if Global.debug_toggles.get("auto_restart", false):
		if not Global.debug_toggles.get("keep_seed", false):
			var level_gen = load("res://level_generator.gd")
			if level_gen:
				level_gen.current_seed = 0
		get_tree().reload_current_scene()
	else:
		if game_over_ui and game_over_ui.has_method("show_game_over"):
			game_over_ui.show_game_over(awarded, distance_tiles)

func get_local_lowest_y() -> float:
	var player_x = global_position.x
	var lowest_y = -999999.0
	var found = false
	for tile in get_tree().get_nodes_in_group("solid_tiles"):
		if not tile is Node2D: continue
		var half_w = 64.0
		var centre_x = tile.global_position.x
		if tile is TileStrip:
			var ts: TileStrip = tile
			half_w = ts.length_tiles * ts.tile_size.x * 0.5
			centre_x = tile.global_position.x + half_w - ts.tile_size.x * 0.5
		if abs(centre_x - player_x) < half_w + 256.0:
			if tile.global_position.y > lowest_y:
				lowest_y = tile.global_position.y
				found = true
	if found:
		return lowest_y
	return 2000.0
