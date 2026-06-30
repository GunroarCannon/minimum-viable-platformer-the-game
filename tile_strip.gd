extends StaticBody2D
class_name TileStrip

## Efficient single-StaticBody2D representation for a contiguous run of N tiles.
##
## Position convention (matches original per-tile spawn):
##   strip.position == centre of the FIRST surface tile in the run.
##   Collision shape sits below the surface row and extends `depth_tiles` rows deep.

@export var tile_size: Vector2 = Vector2(128, 128)
@export var length_tiles: int = 1
@export var depth_tiles: int = 3
@export var drawn_style: bool = true

var _col_shape: CollisionShape2D
var _visual: Node2D

var _strip_color_top := Color(0.85, 0.92, 0.45)
var _strip_color_grass := Color(0.60, 0.78, 0.32)
var _strip_color_grass_dark := Color(0.36, 0.50, 0.20)
var _strip_color_earth_top := Color(0.96, 0.78, 0.50)
var _strip_color_earth_bot := Color(0.74, 0.50, 0.34)
var _strip_color_ink := Color(0.18, 0.14, 0.10)

func _ready() -> void:
	add_to_group("solid_tiles")
	collision_layer = 1
	collision_mask  = 0

	drawn_style = Global.is_unlocked("drawn_floors")

	_col_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(length_tiles * tile_size.x, depth_tiles * tile_size.y)
	_col_shape.shape = rect
	# Shape is centred. Strip.position is the centre of the FIRST surface tile,
	# so move the centre to (cols*tile/2 - tile/2,  depth*tile/2 - tile/2).
	_col_shape.position = Vector2(
		(length_tiles - 1) * tile_size.x * 0.5,
		(depth_tiles - 1) * tile_size.y * 0.5
	)
	add_child(_col_shape)

	_visual = Node2D.new()
	_visual.set_script(preload("res://tile_strip_visual.gd"))
	# Shift the visual so its local origin is the TOP-LEFT of the strip's
	# surface tile. A small extra upward offset makes the surface art read
	# as slightly raised above the collision plane (graphic only).
	_visual.position = Vector2(-tile_size.x * 0.5, -tile_size.y * 0.5 - 6.0)
	# Draw below all hazards (spikes, enemies, the player) so the grass
	# never clips over the surface entities.
	_visual.z_index = -10
	# CRITICAL: set owner_strip BEFORE add_child so the visual's _ready can
	# build its geometry on first frame.
	_visual.set("owner_strip", self)
	add_child(_visual)

func get_world_width() -> float:
	return length_tiles * tile_size.x

func squash(squish_factor: Vector2 = Vector2(1.0, 0.85), duration: float = 0.12) -> void:
	# Tied to the general "Squash & Stretch" juice unlock now that tile_bounce is gone.
	if not Global.is_unlocked("juice_squash"): return
	if not _visual: return
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", squish_factor, duration)
	tw.tween_property(_visual, "scale", Vector2.ONE, duration * 1.6).set_trans(Tween.TRANS_BACK)
