# Suggested asset size: 64x64 px
extends BaseEnemy

@export var walk_speed: float = 100.0
@export var trigger_distance: float = 400.0
@export var explosion_delay: float = 1.0
@export var explosion_radius: float = 250.0

var state = "walking" # walking, loading, exploding
var timer: float = 0.0
var color_mod = Color(0.1, 0.1, 0.1)

func _ready() -> void:
	super._ready()
	tear_size      = Vector2(64, 64)
	tear_color     = Color(0.12, 0.12, 0.12)
	tears_on_death = false  # bomb uses its own explosion effect
	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(64, 64)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(74, 74)

func _custom_process(delta: float) -> void:
	if not player: return
	
	match state:
		"walking":
			if is_on_floor():
				var dir = sign(player.global_position.x - global_position.x)
				if dir == 0: dir = 1
				velocity.x = dir * walk_speed
				
			if abs(player.global_position.x - global_position.x) < trigger_distance:
				state = "loading"
				timer = explosion_delay
				velocity.x = 0
		"loading":
			velocity.x = 0
			timer -= delta
			# Pulse red
			var pulse = (sin(timer * 30) + 1.0) / 2.0
			color_mod = Color(pulse, 0.1, 0.1)
			queue_redraw()
			
			if timer <= 0:
				_explode()

func _explode() -> void:
	state = "exploding"
	
	if player and player.has_method("shake_camera"):
		player.shake_camera(40.0, 0.5)
		
	var dist = global_position.distance_to(player.global_position)
	if dist <= explosion_radius:
		if player.has_method("die"):
			player.die()
	
	var poof = CPUParticles2D.new()
	poof.emitting = true
	poof.one_shot = true
	poof.amount = 60
	poof.lifetime = 0.5
	poof.explosiveness = 1.0
	poof.spread = 180.0
	poof.initial_velocity_min = 200.0
	poof.initial_velocity_max = 600.0
	poof.scale_amount_min = 10.0
	poof.scale_amount_max = 40.0
	poof.color = Color(1.0, 0.4, 0.0)
	
	get_parent().add_child(poof)
	poof.global_position = global_position
	
	queue_free()

func _draw() -> void:
	# Bomb body
	draw_circle(Vector2(0, 0), 32, color_mod)
	# Fuse
	draw_line(Vector2(0, -32), Vector2(10, -50), Color.DARK_GRAY, 4.0)
	if state == "loading":
		draw_circle(Vector2(10, -50), 8, Color.YELLOW)
		draw_circle(Vector2(10, -50), 4, Color.ORANGE)
