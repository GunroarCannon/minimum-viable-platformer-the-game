extends Area2D
class_name Spike

@export var spike_size: Vector2 = Vector2(128, 128)
@export var spike_color: Color = Color(1, 0, 0) # Red color for the spike

func _ready() -> void:
	# Ensure the collision shape matches a reduced size for fairness
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(spike_size.x * 0.6, spike_size.y * 0.6)
		# Shift collision box down so it sits on the floor
		collision_shape.position.y = spike_size.y * 0.2
	
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

func _draw() -> void:
	# Draw a primitive triangle
	var points = PackedVector2Array()
	# Bottom left
	points.append(Vector2(-spike_size.x / 2, spike_size.y / 2))
	# Top center
	points.append(Vector2(0, -spike_size.y / 2))
	# Bottom right
	points.append(Vector2(spike_size.x / 2, spike_size.y / 2))
	
	draw_polygon(points, PackedColorArray([spike_color]))

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
