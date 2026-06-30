extends Area2D
class_name Smasher

@export var tile_size: Vector2 = Vector2(128, 128)
@onready var smasher_size: Vector2 = Vector2(tile_size.x * 1.5, tile_size.y * 2.0)
@export var trigger_distance: float = 400.0
@export var fall_speed: float = 1800.0
@export var rise_speed: float = 300.0

var original_y: float
var state = "idle" # idle, falling, smashed, rising
var smashed_timer: float = 0.0
var player: Node2D = null

var tex_normal = preload("res://assets/smasher_sharp/normal.png")
var tex_angry = preload("res://assets/smasher_sharp/angry.png")
var tex_hurt = preload("res://assets/smasher_sharp/hurt.png")
var sprite: Sprite2D = null

func _ready() -> void:
	original_y = global_position.y
	collision_layer = 2 # Detectable by spikes
	collision_mask = 1 | 2 # Player (1) and Enemies (2)
	
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(smasher_size.x * 0.8, smasher_size.y * 0.9)
	
	var raycast = $RayCast2D
	if raycast:
		raycast.target_position = Vector2(0, smasher_size.y / 2 + 10)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered_smasher)

	if Global.gfx("enemy_sprites"):
		sprite = Sprite2D.new()
		sprite.texture = tex_normal
		if sprite.texture:
			var tex_size = sprite.texture.get_size()
			if tex_size.y > 0:
				var scale_y = smasher_size.y / tex_size.y
				sprite.scale = Vector2(scale_y, scale_y)
		add_child(sprite)
		queue_redraw()

	# Create one-way static top collision so player/enemies can land/stand on top safely
	var sb = StaticBody2D.new()
	sb.collision_layer = 1 # Solid floor/wall layer
	sb.collision_mask = 0
	var sb_coll = CollisionShape2D.new()
	var sb_rect = RectangleShape2D.new()
	sb_rect.size = Vector2(smasher_size.x * 0.8, 20)
	sb_coll.shape = sb_rect
	sb_coll.position = Vector2(0, -smasher_size.y / 2 + 10)
	sb_coll.one_way_collision = true
	sb_coll.one_way_collision_margin = 16.0
	sb.add_child(sb_coll)
	add_child(sb)

func _process(delta: float) -> void:
	if Global.debug_toggles.get("show_collisions", false):
		queue_redraw()
	if not player:
		# Find player dynamically
		var parent = get_parent()
		if parent and parent.has_node("Player"):
			player = parent.get_node("Player")
		return
		
	match state:
		"idle":
			# Trigger if player is close horizontally and below the smasher
			if abs(global_position.x - player.global_position.x) < trigger_distance and global_position.y < player.global_position.y:
				state = "falling"
		"falling":
			global_position.y += fall_speed * delta
			var raycast = $RayCast2D
			if raycast and raycast.is_colliding():
				# Stop falling when hitting the floor
				var hit_point = raycast.get_collision_point()
				global_position.y = hit_point.y - smasher_size.y / 2
				state = "smashed"
				print("spike smashed")
				smashed_timer = 1.0
		"smashed":
			smashed_timer -= delta
			if smashed_timer <= 0:
				state = "rising"
		"rising":
			global_position.y -= rise_speed * delta
			if global_position.y <= original_y:
				global_position.y = original_y
				state = "idle"

	if sprite and Global.gfx("enemy_sprites"):
		if state == "falling" or state == "smashed":
			if sprite.texture != tex_angry:
				sprite.texture = tex_angry
		else:
			if sprite.texture != tex_normal:
				sprite.texture = tex_normal

func _draw() -> void:
	if not Global.gfx("enemy_sprites") or not sprite or not sprite.texture:
		var rect = Rect2(-smasher_size / 2, smasher_size)
		draw_rect(rect, Color(0.3, 0.3, 0.4)) # Dark Gray block
		
		# Draw angry "eyes" for personality
		draw_rect(Rect2(-smasher_size.x/4 - 15, -20, 30, 20), Color(1, 0, 0))
		draw_rect(Rect2(smasher_size.x/4 - 15, -20, 30, 20), Color(1, 0, 0))
		
		# Draw screw threads / slanted lines style Spikes
		var points = PackedVector2Array()
		points.append(Vector2(-smasher_size.x / 2, smasher_size.y / 2))
		points.append(Vector2(-smasher_size.x / 4, smasher_size.y / 2 + 20))
		points.append(Vector2(0, smasher_size.y / 2))
		points.append(Vector2(smasher_size.x / 4, smasher_size.y / 2 + 20))
		points.append(Vector2(smasher_size.x / 2, smasher_size.y / 2))
		draw_polygon(points, PackedColorArray([Color(0.8, 0.8, 0.8)]))

	if Global.debug_toggles.get("show_collisions", false):
		draw_rect(Rect2(-smasher_size / 2, smasher_size), Color.GREEN, false, 2.0)

func _on_body_entered(body: Node2D) -> void:
	if state == "falling" or state == "smashed":
		# Check if body is landing on top
		var body_bottom = body.global_position.y
		if body.get("collision_layer") == 1:
			body_bottom += 55.0
		elif body is BaseEnemy:
			body_bottom += body.get("tear_size").y / 2.0
			
		if body_bottom < global_position.y - smasher_size.y / 2 + 15:
			return

		if body is BaseEnemy:
			body.die_torn(Vector2(0, fall_speed))
		elif body.has_method("die") and not body.get("is_dead"):
			body.die()

func die() -> void:
	if sprite and Global.gfx("enemy_sprites"):
		sprite.texture = tex_hurt
	TearEffect.apply(self, smasher_size, Color(0.3, 0.3, 0.4), Vector2.ZERO)
	queue_free()

func _on_area_entered_smasher(area: Area2D) -> void:
	if area.get_script() and area.get_script().resource_path.contains("spike"):
		die()
