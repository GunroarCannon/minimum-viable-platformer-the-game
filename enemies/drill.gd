extends Area2D
class_name Drill

@export var tile_size: Vector2 = Vector2(128, 128)
@onready var drill_size: Vector2 = Vector2(tile_size.x * 1.2, tile_size.y * 1.5)
@export var trigger_distance: float = 400.0
@export var fall_speed: float = 600.0

var state = "idle"
var player: Node2D = null
var death_y_limit: float = 4000.0

var anim: AnimatedSprite2D = null
var _engine_player: AudioStreamPlayer = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 # Layer 1 (Tiles, Player), Layer 2 (Enemies)
	body_entered.connect(_on_body_entered)
	
	# setup collision shape size dynamically
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = drill_size

	if Global.gfx("enemy_sprites"):
		anim = AnimatedSprite2D.new()
		var frames = SpriteFrames.new()
		frames.add_animation("drill")
		for f in range(6):
			var tex = load("res://assets/animations/mole/" + str(f) + ".png")
			if tex:
				frames.add_frame("drill", tex)
		frames.set_animation_speed("drill", 15.0)
		frames.set_animation_loop("drill", true)
		anim.sprite_frames = frames
		
		# Prioritize aspect ratio of the 480x620 asset to fit collision footprint (drill_size), scaled up by 1.6x for sprite size
		var base_tex = load("res://assets/animations/mole/0.png")
		if base_tex:
			var tex_size = base_tex.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				anim.scale = (drill_size / tex_size) * 1.6
		else:
			anim.scale = Vector2(0.32, 0.31) * 1.6
			
		add_child(anim)
		anim.play("drill")

func _process(delta: float) -> void:
	if Global.debug_toggles.get("show_collisions", false):
		queue_redraw()

	if not player:
		var parent = get_parent()
		if parent and parent.has_node("Player"):
			player = parent.get_node("Player")
			if player:
				death_y_limit = player.get("death_y_limit")
		return

	match state:
		"idle":
			if abs(global_position.x - player.global_position.x) < trigger_distance and global_position.y < player.global_position.y:
				state = "falling"
				_start_engine()
		"falling":
			global_position.y += fall_speed * delta
			if global_position.y > death_y_limit:
				_stop_engine()
				queue_free()

func _start_engine() -> void:
	if not Global.is_unlocked("sfx"): return
	var engine_stream = load("res://assets/sounds/Engine.wav")
	if engine_stream == null: return
	_engine_player = AudioStreamPlayer.new()
	_engine_player.stream = engine_stream
	_engine_player.volume_db = -6.0
	_engine_player.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
	_engine_player.finished.connect(func():
		if _engine_player and is_instance_valid(_engine_player) and state == "falling":
			_engine_player.play()
	)
	add_child(_engine_player)
	_engine_player.play()

func _stop_engine() -> void:
	if _engine_player and is_instance_valid(_engine_player):
		_engine_player.stop()
		_engine_player.queue_free()
		_engine_player = null

func _on_body_entered(body: Node) -> void:
	if body is TileObject:
		if state == "falling":
			_stop_engine()
			body.queue_free()
		return
	if state == "falling":
		_stop_engine()
		if body is BaseEnemy:
			body.die_torn(Vector2(0, fall_speed))
		elif body.has_method("die"):
			body.die(false, "a drill", true)
	elif state == "idle":
		# Side contact while idle — player walks into drill tip.
		if body.has_method("die") and not body.get("is_dead"):
			# Only kill from the pointy bottom half, not landing on top.
			if body is Node2D:
				var bpos := (body as Node2D).global_position
				if bpos.y > global_position.y - drill_size.y * 0.1:
					body.die(false, "a drill", true)

func _draw() -> void:
	if not Global.gfx("enemy_sprites") or not anim:
		# Draw a cool triangular/pointed drill shape so the user is wowed!
		# Top body
		draw_rect(Rect2(-drill_size.x / 2, -drill_size.y / 2, drill_size.x, drill_size.y * 0.4), Color(0.4, 0.4, 0.45))
		# Spinnable-looking yellow/black caution stripes on the body
		draw_rect(Rect2(-drill_size.x / 2, -drill_size.y / 2 + 10, drill_size.x, 15), Color(0.8, 0.7, 0.1))
		
		# Pointy tip (triangle) at the bottom
		var points = PackedVector2Array()
		points.append(Vector2(-drill_size.x / 2, -drill_size.y / 2 + drill_size.y * 0.4))
		points.append(Vector2(0, drill_size.y / 2))
		points.append(Vector2(drill_size.x / 2, -drill_size.y / 2 + drill_size.y * 0.4))
		draw_polygon(points, PackedColorArray([Color(0.6, 0.6, 0.65)]))
		
		# Draw screw threads (slanted lines)
		draw_line(Vector2(-drill_size.x / 2 + 10, -drill_size.y / 2 + drill_size.y * 0.4 + 10), Vector2(drill_size.x / 2 - 10, -drill_size.y / 2 + drill_size.y * 0.4 + 25), Color(0.3, 0.3, 0.3), 3.0)
		draw_line(Vector2(-drill_size.x / 3, -drill_size.y / 2 + drill_size.y * 0.4 + 25), Vector2(drill_size.x / 3, -drill_size.y / 2 + drill_size.y * 0.4 + 40), Color(0.3, 0.3, 0.3), 3.0)

	if Global.debug_toggles.get("show_collisions", false):
		draw_rect(Rect2(-drill_size.x / 2, -drill_size.y / 2, drill_size.x, drill_size.y), Color.GREEN, false, 2.0)
