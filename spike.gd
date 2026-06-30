# Suggested asset size: 128x128 px
extends Area2D
class_name Spike

@export var spike_size: Vector2 = Vector2(128, 128)
@export var spike_color: Color = Color(1, 0, 0)

var sprite: Sprite2D = null

func _ready() -> void:
	# Detect both player (layer 1) and living enemies (layer 2), but NOT bullets
	collision_layer = 2
	collision_mask  = 3  # layer 1 (player/floor bodies) + layer 2 (enemies)

	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(spike_size.x * 0.6, spike_size.y * 0.6)
		collision_shape.position.y = spike_size.y * 0.2

	if Global.gfx("enemy_sprites"):
		sprite = Sprite2D.new()
		sprite.texture = preload("res://assets/spikes.png")
		if sprite.texture:
			var tex_size = sprite.texture.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				sprite.scale = spike_size / tex_size
		add_child(sprite)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(_delta: float) -> void:
	if Global.debug_toggles.get("show_collisions", false):
		queue_redraw()

func _draw() -> void:
	if not Global.gfx("enemy_sprites") or not sprite or not sprite.texture:
		var points = PackedVector2Array()
		points.append(Vector2(-spike_size.x / 2, spike_size.y / 2))
		points.append(Vector2(0, -spike_size.y / 2))
		points.append(Vector2(spike_size.x / 2, spike_size.y / 2))
		draw_polygon(points, PackedColorArray([spike_color]))

	if Global.debug_toggles.get("show_collisions", false):
		var coll_size = Vector2(spike_size.x * 0.6, spike_size.y * 0.6)
		var coll_pos = Vector2(-coll_size.x / 2, spike_size.y * 0.2 - coll_size.y / 2)
		draw_rect(Rect2(coll_pos, coll_size), Color.GREEN, false, 2.0)


func _on_body_entered(body: Node2D) -> void:
	
	if body is BaseEnemy:
		# Bullets are excluded – they fly, don't walk into spikes meaningfully,
		# and can pass through narrow gaps. Check via script name instead of class.
		if body.get_script() and body.get_script().resource_path.contains("bullet"):
			return
		body.die_torn(body.velocity)
	elif body.has_method("die"):
		body.die()  # player – by_fall defaults false → tear death

func _on_area_entered(area: Area2D) -> void:
	print("[Spike Debug] area_entered by: ", area.name, " script: ", area.get_script().resource_path if area.get_script() else "none")
	if area.has_method("die"):
		if area.get_script() and area.get_script().resource_path.contains("smasher"):
			print("[Spike Debug] Smasher script matched. Calling die()!")
			area.die()
