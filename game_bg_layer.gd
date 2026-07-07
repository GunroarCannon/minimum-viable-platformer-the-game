extends Control

## A single visual stratum of the in-game background. Configurable via meta-data
## set by game_bg.gd. Cheap: only redraws when `scroll_x` changes (and on resize).

@export var layer_type: String = "sky"   # "sky" / "far" / "near"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	Global.sky_changed.connect(queue_redraw)
	Global.palette_changed.connect(queue_redraw)

func _draw() -> void:
	match layer_type:
		"sky":    _draw_sky()
		"clouds": _draw_clouds()
		"far":    _draw_hills(0.62, Color(0.93, 0.72, 0.45), 80.0)
		"near":   _draw_hills(0.78, Color(0.85, 0.55, 0.30), 110.0)

func _draw_sky() -> void:
	var sz = size
	var top: Color
	var mid: Color
	var bot: Color
	match Global.sky_color:
		"sunset":
			top = Color(1.00, 0.60, 0.30)
			mid = Color(0.95, 0.42, 0.32)
			bot = Color(0.78, 0.30, 0.48)
		"night":
			top = Color(0.04, 0.06, 0.18)
			mid = Color(0.07, 0.10, 0.26)
			bot = Color(0.10, 0.14, 0.30)
		"dawn":
			top = Color(0.72, 0.62, 0.90)
			mid = Color(0.95, 0.72, 0.80)
			bot = Color(1.00, 0.88, 0.68)
		"overcast":
			top = Color(0.68, 0.70, 0.74)
			mid = Color(0.74, 0.76, 0.80)
			bot = Color(0.80, 0.82, 0.85)
		_:  # default — warm peach gradient
			top = Color(1.00, 0.93, 0.80)
			mid = Color(0.99, 0.83, 0.62)
			bot = Color(0.97, 0.74, 0.50)
	var bands := 28
	for i in bands:
		var t = float(i) / float(bands - 1)
		var col: Color
		if t < 0.55:
			col = top.lerp(mid, t / 0.55)
		else:
			col = mid.lerp(bot, (t - 0.55) / 0.45)
		draw_rect(Rect2(0, sz.y * t, sz.x, sz.y / bands + 1), col, true)

func _draw_clouds() -> void:
	var sz = size
	var scroll_x: float = float(get_meta("scroll_x", 0.0))
	# 5 cloud "footballs". Each cloud is several overlapping ellipsoid puffs.
	for i in 7:
		var seed_i = i * 137.0
		# Wrap each cloud across the screen.
		var spread = sz.x + 600.0
		var period_x = fposmod(seed_i * 350.0 - scroll_x, spread) - 300.0
		var cy = sz.y * (0.10 + sin(seed_i * 1.7) * 0.05 + (i % 3) * 0.06)
		var scale := 1.0 + (i % 3) * 0.35
		var col := Color(1.0, 0.97, 0.93, 0.85)
		_draw_one_cloud(Vector2(period_x, cy), 70.0 * scale, col)

func _draw_one_cloud(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p + Vector2(-r * 0.8, 0), r * 0.75, col)
	draw_circle(p + Vector2(-r * 0.3, -r * 0.25), r * 0.95, col)
	draw_circle(p + Vector2( r * 0.2,  r * 0.05), r * 1.05, col)
	draw_circle(p + Vector2( r * 0.7, -r * 0.10), r * 0.85, col)
	draw_circle(p + Vector2( r * 1.1,  r * 0.10), r * 0.65, col)

func _draw_hills(y_ratio: float, col: Color, amp: float) -> void:
	var sz = size
	var baseline = sz.y * y_ratio
	var scroll_x: float = float(get_meta("scroll_x", 0.0))

	var n = 80
	var poly = PackedVector2Array()
	poly.append(Vector2(0, sz.y))
	for i in n + 1:
		var t = float(i) / float(n)
		var x = t * sz.x
		# Use the world-space x so hills slide as the camera moves.
		var wx = x + scroll_x
		var s1 = sin(wx * 0.0035) * 0.6
		var s2 = sin(wx * 0.0102 + 1.3) * 0.30
		var y = baseline + (s1 + s2) * amp
		poly.append(Vector2(x, y))
	poly.append(Vector2(sz.x, sz.y))
	draw_colored_polygon(poly, col)
