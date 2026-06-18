extends StaticBody2D
class_name TileObject

# --- EXPORTS ---
@export_category("Debug Settings")
## Toggles the custom visual drawing for hitboxes in the game
@export var debug: bool = false:
	set(value):
		debug = value
		queue_redraw()

@export_category("Sizing Controls")
## Set the uniform size footprint of this entire object (Scales sprite & solid collision)
@export var base_size: Vector2 = Vector2(128, 128):
	set(value):
		base_size = value
		if is_inside_tree(): update_sizes()

## Set the custom size footprint of the Area2D trigger zone
@export var trigger_zone_size: Vector2 = Vector2(140, 140):
	set(value):
		trigger_zone_size = value
		if is_inside_tree(): update_sizes()

@export_category("Visuals")
@export var visual_texture: Texture2D:
	set(value):
		visual_texture = value
		if is_inside_tree() and sprite:
			sprite.texture = value
			update_sizes()

# --- NODE REFERENCES ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var solid_collision: CollisionShape2D = $CollisionShape2D
@onready var trigger_area: Area2D = $Area2D
@onready var area_collision: CollisionShape2D = $Area2D/CollisionShape2D

# --- JUICE VARIABLES ---
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _original_sprite_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if sprite:
		_original_sprite_position = sprite.position
		if visual_texture:
			sprite.texture = visual_texture

	update_sizes()
	queue_redraw()

func _process(delta: float) -> void:
	if _shake_timer > 0:
		_shake_timer -= delta
		sprite.position = _original_sprite_position + Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		if _shake_timer <= 0:
			sprite.position = _original_sprite_position

# --- SIZING FUNCTIONS ---

## Dynamically adjusts the sprite scaling and collision shapes to match specified sizes
func update_sizes() -> void:
	if not sprite or not solid_collision or not area_collision:
		return

	# Scale Sprite to fit base_size if a texture is set
	if sprite.texture:
		var tex_size = sprite.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			sprite.scale = base_size / tex_size

	# Solid Collision (RectangleShape2D)
	if not solid_collision.shape:
		solid_collision.shape = RectangleShape2D.new()
	if solid_collision.shape is RectangleShape2D:
		solid_collision.shape.size = base_size

	# Area2D Trigger Collision (RectangleShape2D)
	if not area_collision.shape:
		area_collision.shape = RectangleShape2D.new()
	if area_collision.shape is RectangleShape2D:
		area_collision.shape.size = trigger_zone_size

	queue_redraw()

# --- JUICE / ANIMATION FUNCTIONS ---

func squash(squish_factor: Vector2 = Vector2(1.3, 0.7), duration: float = 0.15) -> void:
	if not sprite: return
	var normal_scale = Vector2.ONE
	if sprite.texture:
		normal_scale = base_size / sprite.texture.get_size()
	var squished_scale = normal_scale * squish_factor
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", squished_scale, duration)
	tween.tween_property(sprite, "scale", normal_scale, duration * 1.5)

func shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

# --- DRAWING ---
# Always draw a coloured placeholder rectangle so tiles are visible
# even without a texture assigned. Debug mode adds extra outlines.
func _draw() -> void:
	var half = base_size * 0.5

	if not visual_texture:
		# Solid fill — a warm stone/grey colour
		var fill_rect = Rect2(-half, base_size)
		draw_rect(fill_rect, Color(0.35, 0.32, 0.28), true)
		# Subtle border to distinguish individual tiles
		draw_rect(fill_rect, Color(0.22, 0.20, 0.17), false, 2.0)
		# Small highlight on top edge
		draw_line(-half, Vector2(half.x, -half.y), Color(0.55, 0.52, 0.46), 2.0)

	if debug:
		# Blue: solid physics box
		var solid_rect = Rect2(-half, base_size)
		draw_rect(solid_rect, Color(0, 0.5, 1, 0.7), false, 2.0)
		draw_rect(solid_rect, Color(0, 0.5, 1, 0.15), true)
		# Green: trigger area box
		var trigger_half = trigger_zone_size * 0.5
		var trigger_rect = Rect2(-trigger_half, trigger_zone_size)
		draw_rect(trigger_rect, Color(0, 1, 0.4, 0.7), false, 2.0)
		draw_rect(trigger_rect, Color(0, 1, 0.4, 0.1), true)
