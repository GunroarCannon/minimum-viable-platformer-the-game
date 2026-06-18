extends StaticBody2D
class_name RampObject

@export var ramp_type: String = "up" # "up" (/) or "down" (\)
@export var base_size: Vector2 = Vector2(128, 128)

func _ready() -> void:
	update_ramp()

func update_ramp() -> void:
	var points = PackedVector2Array()
	if ramp_type == "up":
		# / Ramp
		points.append(Vector2(-base_size.x/2, base_size.y/2))
		points.append(Vector2(base_size.x/2, -base_size.y/2))
		points.append(Vector2(base_size.x/2, base_size.y/2))
	else:
		# \ Ramp
		points.append(Vector2(-base_size.x/2, -base_size.y/2))
		points.append(Vector2(base_size.x/2, base_size.y/2))
		points.append(Vector2(-base_size.x/2, base_size.y/2))
		
	var coll = $CollisionPolygon2D
	if coll:
		coll.polygon = points
	queue_redraw()

func _draw() -> void:
	var points = PackedVector2Array()
	if ramp_type == "up":
		points.append(Vector2(-base_size.x/2, base_size.y/2))
		points.append(Vector2(base_size.x/2, -base_size.y/2))
		points.append(Vector2(base_size.x/2, base_size.y/2))
	else:
		points.append(Vector2(-base_size.x/2, -base_size.y/2))
		points.append(Vector2(base_size.x/2, base_size.y/2))
		points.append(Vector2(-base_size.x/2, base_size.y/2))
	
	# Warm stone color with top-edge highlight
	draw_polygon(points, PackedColorArray([Color(0.65, 0.55, 0.45)]))
	# Draw highlight line
	if ramp_type == "up":
		draw_line(Vector2(-base_size.x/2, base_size.y/2), Vector2(base_size.x/2, -base_size.y/2), Color(0.8, 0.7, 0.6), 4.0)
	else:
		draw_line(Vector2(-base_size.x/2, -base_size.y/2), Vector2(base_size.x/2, base_size.y/2), Color(0.8, 0.7, 0.6), 4.0)

func squash() -> void:
	# Simple visual squash feedback
	scale = Vector2(1.1, 0.9)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SPRING)
