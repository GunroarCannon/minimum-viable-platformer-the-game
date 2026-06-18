# Suggested asset size: 64x48 px
extends BaseEnemy

@export var fly_speed: float = 400.0
var direction: int = -1

func _ready() -> void:
	gravity_scale = 0.0 # Bullets fly straight
	can_be_stomped = true
	super._ready()
	collision_mask = 1 # Only collide with walls, not other enemies
	
	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(64, 48)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(74, 58)

func _custom_process(delta: float) -> void:
	velocity.x = direction * fly_speed
	
	if is_on_wall():
		die()

func stomp_by(stomper: Node2D) -> void:
	if _is_dying: return
	die()
	var body_vel = stomper.get("velocity")
	if body_vel is Vector2:
		stomper.set("velocity", Vector2(body_vel.x, -700)) # Normal bounce

func _draw() -> void:
	# Draw bullet body
	var rect = Rect2(-32, -24, 64, 48)
	draw_rect(rect, Color(0.1, 0.1, 0.1))
	# Draw nose cone
	var points = PackedVector2Array()
	if direction < 0:
		points.append(Vector2(-32, -24))
		points.append(Vector2(-48, 0))
		points.append(Vector2(-32, 24))
	else:
		points.append(Vector2(32, -24))
		points.append(Vector2(48, 0))
		points.append(Vector2(32, 24))
	draw_polygon(points, PackedColorArray([Color(0.2, 0.2, 0.2)]))
	# Draw eye
	var eye_x = direction * 15
	draw_circle(Vector2(eye_x, -5), 5, Color.WHITE)
	draw_circle(Vector2(eye_x + direction * 2, -5), 2, Color.RED)
