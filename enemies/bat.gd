# Suggested asset size: 64x64 px
extends BaseEnemy

@export var fly_speed: float = 200.0
@export var trigger_distance: float = 1000.0

func _ready() -> void:
	gravity_scale = 0.0 # Ignore gravity
	super._ready()
	tear_size  = Vector2(64, 48)
	tear_color = Color(0.2, 0.2, 0.22)
	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(64, 64)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(74, 74)

var triggered: bool = false

func _custom_process(delta: float) -> void:
	if not player: return
	
	if not triggered:
		var dist = global_position.distance_to(player.global_position)
		if dist < trigger_distance:
			triggered = true
			# Calculate a steep downward dive direction
			var dir = global_position.direction_to(player.global_position)
			dir.y = max(dir.y, 0.8) # Force a steep downward trajectory
			velocity = dir.normalized() * fly_speed
		else:
			velocity = velocity.move_toward(Vector2.ZERO, fly_speed * delta)

func _draw() -> void:
	# Draw bat wings and body
	var points = PackedVector2Array()
	points.append(Vector2(0, -10))
	points.append(Vector2(-32, -32))
	points.append(Vector2(-10, 0))
	points.append(Vector2(-32, 32))
	points.append(Vector2(0, 10))
	points.append(Vector2(32, 32))
	points.append(Vector2(10, 0))
	points.append(Vector2(32, -32))
	draw_polygon(points, PackedColorArray([Color(0.2, 0.2, 0.2)]))
	# Red eyes
	draw_circle(Vector2(-5, -5), 3, Color.RED)
	draw_circle(Vector2(5, -5), 3, Color.RED)
