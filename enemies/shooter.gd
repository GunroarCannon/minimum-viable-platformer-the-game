# Suggested asset size: 64x128 px
extends StaticBody2D

@export var shoot_interval: float = 3.0
@export var bullet_scene: PackedScene = preload("res://enemies/bullet.tscn")
@export var direction: int = -1

var timer: float = 0.0

func _ready() -> void:
	collision_layer = 1 # Solid wall
	collision_mask = 0
	timer = shoot_interval

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		timer = shoot_interval
		_shoot()

func _shoot() -> void:
	if not bullet_scene: return
	var bullet = bullet_scene.instantiate()
	bullet.direction = direction
	# Spawn completely outside the shooter's hitbox (32 + 32 = 64 minimum clearance)
	bullet.global_position = global_position + Vector2(direction * 70, -20)
	get_parent().add_child(bullet)

func _draw() -> void:
	# Draw pillar
	draw_rect(Rect2(-32, -64, 64, 128), Color(0.2, 0.2, 0.3))
	# Draw cannon opening
	var opening_x = direction * 28
	draw_rect(Rect2(opening_x - 4, -36, 8, 32), Color.BLACK)
