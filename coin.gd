extends Area2D

@export var token_value: int = 1

var _collected: bool = false
var _t: float = 0.0
## Set true while a drop-tween is running so the bob animation doesn't fight the tween.
## The coin draws nothing during flight and resumes bobbing once landed.
var flying: bool = false :
	set(v):
		flying = v
		if not v:
			queue_redraw()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 8 | 4   # layer 8 = player body sensor, layer 4 = enemy hitboxes
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
	if _collected or flying: return
	_t += delta
	rotation = sin(_t * 2.6) * 0.28
	position.y += sin(_t * 4.0) * 0.35
	queue_redraw()

func _draw() -> void:
	if _collected or flying: return
	var r := 24.0 + sin(_t * 6.0) * 1.5
	draw_circle(Vector2(0, 3), r, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, r, Color(0.95, 0.78, 0.20))
	draw_arc(Vector2.ZERO, r - 4.0, 0, TAU, 32, Color(0.78, 0.55, 0.10), 2.5, true)
	draw_circle(Vector2(-r * 0.30, -r * 0.30), r * 0.20, Color(1.0, 0.96, 0.55))
	draw_arc(Vector2.ZERO, r, 0, TAU, 36, Color(0.18, 0.13, 0.05), 2.5, true)

func _on_area_entered(area: Area2D) -> void:
	if _collected or flying: return
	if area.collision_layer & 8:
		# Player body sensor.
		_collect()
	elif area.collision_layer & 4:
		# Enemy hitbox — enemy "eats" the coin.
		var enemy := area.get_parent()
		if enemy and not enemy.get("_is_dying"):
			_enemy_eat(enemy)

func _collect() -> void:
	_collected = true
	AudioManager.play("gem_gather", 0.0, 0.04)
	Global.add_tokens(token_value)
	TokenPop.spawn(get_parent(), global_position, token_value)
	var p := CPUParticles2D.new()
	p.texture = Global.get_circle_texture()
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

func _enemy_eat(enemy: Node) -> void:
	_collected = true
	# Track how many coins this enemy has swallowed.
	if "coins_eaten" in enemy:
		enemy.coins_eaten += token_value
	# Brief dark-smoke dissolve — enemy absorbed the coin.
	var p := CPUParticles2D.new()
	p.texture = Global.get_circle_texture()
	p.emitting = true
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 120.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = Color(0.55, 0.45, 0.10, 0.8)
	get_parent().add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	queue_free()
