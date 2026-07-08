# Suggested asset size: 64x128 px
extends StaticBody2D

@export var shoot_interval: float = 3.0
@export var bullet_scene: PackedScene = preload("res://enemies/bullet.tscn")
@export var direction: int = -1

var timer: float = 0.0

var anim: AnimatedSprite2D = null

func _ready() -> void:
	collision_layer = 1 # Solid wall
	collision_mask = 0
	timer = shoot_interval

	if Global.gfx("enemy_sprites"):
		anim = AnimatedSprite2D.new()
		var frames = SpriteFrames.new()
		
		frames.add_animation("shoot")
		for f in range(16):
			var tex = load("res://assets/animations/cannon/" + str(f) + ".png")
			if tex:
				frames.add_frame("shoot", tex)
				
		frames.set_animation_speed("shoot", 10.0)
		frames.set_animation_loop("shoot", true)
		
		anim.sprite_frames = frames
		anim.scale = Vector2(0.582, 0.582)
		add_child(anim)
		anim.play("shoot")
		anim.flip_h = direction < 0

func _process(delta: float) -> void:
	if Global.debug_toggles.get("show_collisions", false):
		queue_redraw()
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
	Global.stat_add("bullets_fired", 1)

func _draw() -> void:
	if not Global.gfx("enemy_sprites") or not anim:
		# Draw pillar
		draw_rect(Rect2(-32, -64, 64, 128), Color(0.2, 0.2, 0.3))
		# Draw cannon opening
		var opening_x = direction * 28
		draw_rect(Rect2(opening_x - 4, -36, 8, 32), Color.BLACK)

	if Global.debug_toggles.get("show_collisions", false):
		draw_rect(Rect2(-32, -64, 64, 128), Color.GREEN, false, 2.0)
