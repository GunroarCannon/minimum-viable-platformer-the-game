extends CharacterBody2D
class_name BaseEnemy

@export var can_be_stomped: bool = true
@export var gravity_scale: float = 1.0

var player: Node2D = null
var _is_dying: bool = false

func _ready() -> void:
	collision_layer = 2  # Enemies on Layer 2
	# Mask 3 = Layer 1 (floor) + Layer 2 (other enemies) — enemies collide with each other
	collision_mask  = 3
	
	# Hitbox Area2D only for detecting the PLAYER hitting us from the side/below
	var hitbox = $Hitbox
	if hitbox:
		hitbox.collision_layer = 4   # Hitbox on Layer 4
		hitbox.collision_mask  = 8   # Detect Layer 8 (player body sensor)
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _find_player() -> void:
	if player: return
	var p = get_parent().get_node_or_null("Player")
	if p: player = p

func _physics_process(delta: float) -> void:
	if _is_dying: return
	_find_player()
	velocity.y += 980 * gravity_scale * delta
	_custom_process(delta)
	move_and_slide()

func _custom_process(_delta: float) -> void:
	pass

# Called by the player's FOOT sensor — always a stomp
func stomp_by(stomper: Node2D) -> void:
	if _is_dying: return
	die()
	var body_vel = stomper.get("velocity")
	if body_vel is Vector2:
		stomper.set("velocity", Vector2(body_vel.x, -900)) # Big bounce

# Called when player body sensor overlaps our hitbox.
# Frogs, kobolds and bats KILL the player from any direction EXCEPT from the head.
# "From the head" = player centre is clearly above our centre (they are stomping).
# The foot sensor handles the stomp; we just skip the kill here.
func _on_hitbox_area_entered(area: Area2D) -> void:
	if _is_dying: return
	var body = area.get_parent()
	if body and body.has_method("die") and not body.get("is_dead"):
		# Player centre more than 30 px above our centre → overhead / head contact → no kill
		if body.global_position.y < global_position.y - 30:
			return
		body.die()

func die() -> void:
	if _is_dying: return
	_is_dying = true
	
	var poof = CPUParticles2D.new()
	poof.emitting = true
	poof.one_shot = true
	poof.amount = 24
	poof.lifetime = 0.5
	poof.explosiveness = 1.0
	poof.spread = 180.0
	poof.initial_velocity_min = 80.0
	poof.initial_velocity_max = 280.0
	poof.scale_amount_min = 8.0
	poof.scale_amount_max = 20.0
	poof.color = Color(0.9, 0.9, 0.9)
	get_parent().add_child(poof)
	poof.global_position = global_position
	
	queue_free()
