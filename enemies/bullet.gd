# Suggested asset size: 64x48 px
extends BaseEnemy

@export var fly_speed: float = 400.0
var direction: int = -1

func _ready() -> void:
	gravity_scale  = 0.0  # Bullets fly straight
	can_be_stomped = true
	tears_on_death = true
	tear_type      = "logs"
	tear_size      = Vector2(64, 48)
	tear_color     = Color(0.12, 0.12, 0.12)
	super._ready()
	collision_mask = 1  # Only collide with walls (not other enemies physically)

	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(64, 48)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(74, 58)

	# Area2D that detects ALL enemy bodies (layer 2) — kills them on contact
	var dmg_area = Area2D.new()
	dmg_area.collision_layer = 0
	dmg_area.collision_mask  = 2  # enemy CharacterBody2D layer
	var dmg_shape = CollisionShape2D.new()
	var dmg_rect  = RectangleShape2D.new()
	dmg_rect.size = Vector2(64, 48)
	dmg_shape.shape = dmg_rect
	dmg_area.add_child(dmg_shape)
	add_child(dmg_area)
	dmg_area.body_entered.connect(_on_hit_enemy)

func _on_hit_enemy(body: Node) -> void:
	if _is_dying: return
	if body == self: return
	if body is BaseEnemy:
		body.die_torn(Vector2(direction * fly_speed, 0.0))
		die()  # bullet also dies (poof) when it kills

func _custom_process(_delta: float) -> void:
	velocity.x = direction * fly_speed
	if is_on_wall():
		die()

func stomp_by(stomper: Node2D) -> void:
	if _is_dying: return
	die()
	var body_vel = stomper.get("velocity")
	if body_vel is Vector2:
		stomper.set("velocity", Vector2(body_vel.x, -700))

func _draw() -> void:
	draw_rect(Rect2(-32, -24, 64, 48), Color(0.1, 0.1, 0.1))
	var points = PackedVector2Array()
	if direction < 0:
		points.append(Vector2(-32, -24))
		points.append(Vector2(-48,   0))
		points.append(Vector2(-32,  24))
	else:
		points.append(Vector2( 32, -24))
		points.append(Vector2( 48,   0))
		points.append(Vector2( 32,  24))
	draw_polygon(points, PackedColorArray([Color(0.2, 0.2, 0.2)]))
	var eye_x = direction * 15
	draw_circle(Vector2(eye_x,                 -5), 5, Color.WHITE)
	draw_circle(Vector2(eye_x + direction * 2, -5), 2, Color.RED)
