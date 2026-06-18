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

func _ready() -> void:
	original_y = global_position.y
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(smasher_size.x * 0.8, smasher_size.y * 0.9)
	
	var raycast = $RayCast2D
	if raycast:
		raycast.target_position = Vector2(0, smasher_size.y / 2 + 10)
	
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
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

func _draw() -> void:
	var rect = Rect2(-smasher_size / 2, smasher_size)
	draw_rect(rect, Color(0.3, 0.3, 0.4)) # Dark Gray block
	
	# Draw angry "eyes" for personality
	draw_rect(Rect2(-smasher_size.x/4 - 15, -20, 30, 20), Color(1, 0, 0))
	draw_rect(Rect2(smasher_size.x/4 - 15, -20, 30, 20), Color(1, 0, 0))
	
	# Draw primitive spikes at the bottom
	var points = PackedVector2Array()
	points.append(Vector2(-smasher_size.x / 2, smasher_size.y / 2))
	points.append(Vector2(-smasher_size.x / 4, smasher_size.y / 2 + 20))
	points.append(Vector2(0, smasher_size.y / 2))
	points.append(Vector2(smasher_size.x / 4, smasher_size.y / 2 + 20))
	points.append(Vector2(smasher_size.x / 2, smasher_size.y / 2))
	draw_polygon(points, PackedColorArray([Color(0.8, 0.8, 0.8)]))

func _on_body_entered(body: Node2D) -> void:
	# Kill player if touching while falling or smashed (prevent clipping exploit)
	if (state == "falling" or state == "smashed") and body.has_method("die"):
		body.die()
