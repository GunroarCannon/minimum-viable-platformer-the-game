extends Area2D

@export var token_value: int = 1

var _collected: bool = false
var _t: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 8                    # player body sensor on layer 8
	monitoring = true
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 28.0
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	add_to_group("coins")
	z_index = 5

func _process(delta: float) -> void:
	if _collected: return
	_t += delta
	rotation = sin(_t * 2.6) * 0.28
	position.y += sin(_t * 4.0) * 0.35
	queue_redraw()

func _draw() -> void:
	if _collected: return
	var r := 24.0 + sin(_t * 6.0) * 1.5
	# Rim shadow
	draw_circle(Vector2(0, 3), r, Color(0, 0, 0, 0.25))
	# Body
	draw_circle(Vector2.ZERO, r, Color(0.95, 0.78, 0.20))
	# Inner ring
	draw_arc(Vector2.ZERO, r - 4.0, 0, TAU, 32, Color(0.78, 0.55, 0.10), 2.5, true)
	# Glint
	draw_circle(Vector2(-r * 0.30, -r * 0.30), r * 0.20, Color(1.0, 0.96, 0.55))
	# Outline
	draw_arc(Vector2.ZERO, r, 0, TAU, 36, Color(0.18, 0.13, 0.05), 2.5, true)

func _on_area_entered(_area: Area2D) -> void:
	if _collected: return
	# Anything on layer 8 is the player body sensor.
	_collect()

func _collect() -> void:
	_collected = true
	Global.add_tokens(token_value)
	TokenPop.spawn(get_parent(), global_position, token_value)
	# Sparks
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 22
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 380)
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 460.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.color = Color(0.98, 0.85, 0.30)
	get_parent().add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	queue_free()
