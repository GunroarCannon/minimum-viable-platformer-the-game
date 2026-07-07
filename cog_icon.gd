extends Control

## Simple polygon cog. Drop-in child of a Button to render an icon that scales
## without relying on emoji fonts.

@export var color: Color = Color(0.18, 0.14, 0.10)
@export var hub_color: Color = Color(1.0, 0.95, 0.85)
@export var teeth: int = 10

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c = size * 0.5
	var outer = min(size.x, size.y) * 0.42
	var inner = outer * 0.55
	var hub = outer * 0.35
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(teeth * 2):
		var a = TAU * float(i) / float(teeth * 2)
		var r = outer if (i % 2) == 0 else inner
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		cols.append(color)
	draw_polygon(pts, cols)
	draw_circle(c, hub, hub_color)
	draw_arc(c, hub, 0.0, TAU, 32, color, 2.0, true)
