# Suggested asset size: 128x128 px
extends BaseEnemy

@export var hop_distance: float = 600.0
@export var hop_velocity: Vector2 = Vector2(500, -1000)
@export var hop_cooldown: float = 2.0

var timer: float = 0.0
var _was_on_floor: bool = false

func _ready() -> void:
	super._ready()
	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(128, 128)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(138, 138)

func _custom_process(delta: float) -> void:
	if not player: return
	
	timer -= delta
	var currently_on_floor = is_on_floor()
	
	if currently_on_floor and not _was_on_floor:
		_break_tiles_below()
		
	_was_on_floor = currently_on_floor
	
	if currently_on_floor:
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		
		if timer <= 0.0 and abs(player.global_position.x - global_position.x) < hop_distance:
			var dir = sign(player.global_position.x - global_position.x)
			if dir == 0: dir = 1
			velocity = Vector2(hop_velocity.x * dir, hop_velocity.y)
			timer = hop_cooldown

func _break_tiles_below() -> void:
	if player and player.has_method("shake_camera"):
		player.shake_camera(30.0, 0.4)
		
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is TileObject and collision.get_normal().y < -0.5:
			collider.queue_free()

func _draw() -> void:
	draw_circle(Vector2(0, 0), 64, Color(0.1, 0.5, 0.1)) # Dark green body
	# Eyes
	draw_circle(Vector2(-30, -30), 16, Color.WHITE)
	draw_circle(Vector2(30, -30), 16, Color.WHITE)
	draw_circle(Vector2(-30, -30), 8, Color.BLACK)
	draw_circle(Vector2(30, -30), 8, Color.BLACK)
