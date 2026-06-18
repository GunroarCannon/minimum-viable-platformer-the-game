# Suggested asset size: 64x64 px
extends BaseEnemy

@export var hop_distance: float = 600.0
@export var hop_velocity: Vector2 = Vector2(400, -800)
@export var hop_cooldown: float = 1.5

var timer: float = 0.0

func _ready() -> void:
	super._ready()
	tear_size  = Vector2(64, 64)
	tear_color = Color(0.2, 0.8, 0.2)
	# Ensure shapes match the 64x64 size
	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(64, 64)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(74, 74)

func _custom_process(delta: float) -> void:
	if not player: return
	
	timer -= delta
	
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, 800 * delta)
		
		if timer <= 0.0 and abs(player.global_position.x - global_position.x) < hop_distance:
			var dir = sign(player.global_position.x - global_position.x)
			if dir == 0: dir = 1
			velocity = Vector2(hop_velocity.x * dir, hop_velocity.y)
			timer = hop_cooldown

func _draw() -> void:
	draw_circle(Vector2(0, 0), 32, Color(0.2, 0.8, 0.2)) # Green body
	# Eyes
	draw_circle(Vector2(-15, -15), 8, Color.WHITE)
	draw_circle(Vector2(15, -15), 8, Color.WHITE)
	draw_circle(Vector2(-15, -15), 4, Color.BLACK)
	draw_circle(Vector2(15, -15), 4, Color.BLACK)
