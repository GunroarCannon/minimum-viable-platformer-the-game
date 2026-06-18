# Suggested asset size: 64x96 px
extends BaseEnemy

@export var walk_speed: float = 150.0
var direction: int = -1

func _ready() -> void:
	super._ready()
	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(64, 96)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(74, 106)

func _custom_process(delta: float) -> void:
	if is_on_floor():
		var ray_l = $RayCastLeft
		var ray_r = $RayCastRight
		
		if is_on_wall():
			direction *= -1
		elif direction == -1 and ray_l and not ray_l.is_colliding():
			direction = 1
		elif direction == 1 and ray_r and not ray_r.is_colliding():
			direction = -1
			
		velocity.x = direction * walk_speed

func _draw() -> void:
	draw_rect(Rect2(-32, -48, 64, 96), Color(0.8, 0.5, 0.2)) # Kobold color
	var eye_x = direction * 15
	draw_circle(Vector2(eye_x - 8, -30), 4, Color.RED)
	draw_circle(Vector2(eye_x + 8, -30), 4, Color.RED)
	draw_line(Vector2(eye_x - 12, -40), Vector2(eye_x - 4, -35), Color.BLACK, 2)
	draw_line(Vector2(eye_x + 12, -40), Vector2(eye_x + 4, -35), Color.BLACK, 2)
