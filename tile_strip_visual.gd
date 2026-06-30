extends Node2D

## Visual child of TileStrip. Owns the actual _draw() call so the strip can
## tween scale/position without triggering re-draws of the static body.
##
## Caches its polygon arrays so per-frame work is just `draw_polygon` /
## `draw_colored_polygon` calls — no math per frame.

var owner_strip = null

var _top_poly: PackedVector2Array
var _earth_poly: PackedVector2Array
var _earth_uvs: PackedVector2Array
var _earth_cols: PackedColorArray
var _grass_band_poly: PackedVector2Array
var _grass_dark_poly: PackedVector2Array
var _outline_top: PackedVector2Array
var _ready_built := false

const TOP_WAVE_AMP := 6.0        # amplitude of the wavy grass top — kept small so hazards above stay readable
const TOP_WAVE_DENSITY := 0.045  # waves per pixel
const GRASS_THICK := 10.0        # height of the yellow-green band
const GRASS_DARK_THICK := 4.0    # underline thickness

func _ready() -> void:
	_build_geometry()
	if owner_strip == null:
		# owner_strip set after add_child — defer one frame and rebuild.
		call_deferred("_late_build")
	else:
		_ready_built = true
		queue_redraw()

func _late_build() -> void:
	if owner_strip == null: return
	_build_geometry()
	_ready_built = true
	queue_redraw()

func _build_geometry() -> void:
	if not owner_strip: return
	var w: float = owner_strip.get_world_width()
	var depth: float = owner_strip.depth_tiles * owner_strip.tile_size.y
	var grass_top = -2.0  # top wave just barely peeks above the tile edge

	# Wave phase is keyed to WORLD x so adjacent strips connect seamlessly
	# at their shared edge — same x in two strips yields the same wave value.
	var world_x_origin: float = owner_strip.position.x + position.x
	var samples = max(24, int(w / 18.0))
	_top_poly = PackedVector2Array()
	for i in samples + 1:
		var t = float(i) / float(samples)
		var x = t * w
		var wx = world_x_origin + x
		# Two layers of sin at fixed world frequencies → continuous across strips.
		var y = grass_top \
			+ sin(wx * 0.024) * TOP_WAVE_AMP * 0.6 \
			+ sin(wx * 0.057 + 1.0) * TOP_WAVE_AMP * 0.35
		_top_poly.append(Vector2(x, y))

	# ─── EARTH POLY (peach gradient via per-vertex colours) ───────────────
	# Build a strip of vertices: top row matches _top_poly, bottom row is flat.
	_earth_poly = PackedVector2Array()
	_earth_cols = PackedColorArray()
	for p in _top_poly:
		_earth_poly.append(p)
		_earth_cols.append(owner_strip._strip_color_earth_top)
	for i in range(_top_poly.size() - 1, -1, -1):
		var p = _top_poly[i]
		_earth_poly.append(Vector2(p.x, depth))
		_earth_cols.append(owner_strip._strip_color_earth_bot)

	# ─── GRASS BAND (thinner so hazards on top stay readable) ─────────────
	_grass_band_poly = PackedVector2Array()
	for p in _top_poly:
		_grass_band_poly.append(p)
	for i in range(_top_poly.size() - 1, -1, -1):
		var p = _top_poly[i]
		_grass_band_poly.append(Vector2(p.x, p.y + GRASS_THICK))

	# Dark grass underline
	_grass_dark_poly = PackedVector2Array()
	for p in _top_poly:
		_grass_dark_poly.append(Vector2(p.x, p.y + GRASS_THICK))
	for i in range(_top_poly.size() - 1, -1, -1):
		var p = _top_poly[i]
		_grass_dark_poly.append(Vector2(p.x, p.y + GRASS_THICK + GRASS_DARK_THICK))

	# Outline path
	_outline_top = _top_poly.duplicate()

func _draw() -> void:
	if not owner_strip: return
	if not _ready_built: return

	var drawn_style: bool = owner_strip.drawn_style
	var w: float = owner_strip.get_world_width()
	var depth: float = owner_strip.depth_tiles * owner_strip.tile_size.y

	if not drawn_style:
		# Primitive look: flat warm stone rectangle + top highlight.
		var rect = Rect2(Vector2.ZERO, Vector2(w, depth))
		draw_rect(rect, Color(0.35, 0.32, 0.28), true)
		draw_rect(rect, Color(0.22, 0.20, 0.17), false, 2.0)
		draw_line(Vector2(0, 0), Vector2(w, 0), Color(0.55, 0.52, 0.46), 3.0)
	else:
		# 1) Earth body with vertical gradient (per-vertex colours)
		draw_polygon(_earth_poly, _earth_cols)
		# 2) Grass body (yellow-green band)
		draw_colored_polygon(_grass_band_poly, owner_strip._strip_color_grass)
		# 3) Highlight wash at very top — narrow so spikes/enemies on the
		#    surface aren't visually clipped.
		var hi_poly = PackedVector2Array()
		for p in _top_poly:
			hi_poly.append(p)
		for i in range(_top_poly.size() - 1, -1, -1):
			var p = _top_poly[i]
			hi_poly.append(Vector2(p.x, p.y + 3.0))
		draw_colored_polygon(hi_poly, owner_strip._strip_color_top)
		# 4) Darker grass underline
		draw_colored_polygon(_grass_dark_poly, owner_strip._strip_color_grass_dark)
		# 5) Inky outline along the top
		draw_polyline(_outline_top, owner_strip._strip_color_ink, 3.0, true)
		# 6) Foliage tufts when unlocked.
		if Global.is_unlocked("foliage"):
			_draw_foliage(w)

	# Debug rect
	if Global.debug_toggles.get("show_collisions", false):
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, depth)), Color.GREEN, false, 2.0)

func _draw_foliage(w: float) -> void:
	# Deterministic sprinkle along the top wave: choose tuft positions by a
	# world-x hash so neighbouring strips stay consistent.
	var world_x_origin: float = owner_strip.position.x + position.x
	var step := 42.0
	var x = (-fposmod(world_x_origin, step))
	while x < w:
		var wx = world_x_origin + x
		# Pseudo-random in [0,1) from world x.
		var r = fposmod(sin(wx * 0.231) * 43758.5453,1)
		if r > 0.55:
			x += step
			continue
		# Find the wave y at x by interpolating _top_poly.
		var ty := _interp_top_y(x)
		var tuft_h = 8.0 + r * 6.0
		var col_a := Color(0.36, 0.50, 0.20)
		var col_b := Color(0.55, 0.72, 0.28)
		# Two blades + occasional flower.
		draw_line(Vector2(x - 3, ty), Vector2(x - 4, ty - tuft_h), col_a, 1.6, true)
		draw_line(Vector2(x, ty), Vector2(x + 1, ty - tuft_h - 2), col_b, 1.6, true)
		draw_line(Vector2(x + 3, ty), Vector2(x + 5, ty - tuft_h + 1), col_a, 1.6, true)
		if fposmod(r * 9.13,1) < 0.18:
			# Flower head
			var fc = Color(1.0, 0.92, 0.40)
			draw_circle(Vector2(x + 1, ty - tuft_h - 3.0), 2.2, fc)
			draw_circle(Vector2(x + 1, ty - tuft_h - 3.0), 0.9, Color(0.95, 0.55, 0.10))
		x += step

func _interp_top_y(x: float) -> float:
	if _top_poly.size() < 2: return 0.0
	# Linear search; segments are small.
	for i in range(_top_poly.size() - 1):
		var a = _top_poly[i]
		var b = _top_poly[i + 1]
		if x >= a.x and x <= b.x:
			var t = (x - a.x) / max(0.0001, (b.x - a.x))
			return lerp(a.y, b.y, t)
	if x < _top_poly[0].x: return _top_poly[0].y
	return _top_poly[_top_poly.size() - 1].y
