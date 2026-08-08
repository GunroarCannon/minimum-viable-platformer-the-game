extends CanvasLayer
## The onboarding pointing hand. Parks itself outside a target, points at it,
## and (optionally) blocks every press that lands anywhere else — so a guided
## step has exactly one possible next action.
##
##   var f = preload("res://guide_finger.gd").new()
##   get_tree().root.add_child(f)          # added last → sees _input first
##   f.point_at_control(some_button)
##
## assets/pointing-finger.png is authored pointing up-and-left. TIP_UV is where
## the fingertip sits inside the texture and DEFAULT_ANGLE is the direction it
## points at rotation 0 — nudge these two if the art is ever redrawn.

signal target_pressed

const FINGER_TEX := preload("res://assets/pointing-finger.png")
const TIP_UV := Vector2(0.12, 0.02)
const DEFAULT_ANGLE := deg_to_rad(-114.0)
const FINGER_LENGTH := 132.0    ## on-screen size of the hand, long axis
const GAP := 14.0               ## fingertip clearance from the target edge
const BOB := 11.0               ## bob travel along the pointing axis
const RING_PAD := 10.0
const RING_COLOR := Color(1.0, 0.85, 0.35)
const FINGER_LAYER := 215

var _sprite: Sprite2D
var _ring: Panel
var _ring_style: StyleBoxFlat

var _target_control: Control = null
var _target_rect: Rect2 = Rect2()
var _has_target: bool = false
var _gating: bool = true
var _time: float = 0.0

func _ready() -> void:
	layer = FINGER_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ring_style = StyleBoxFlat.new()
	_ring_style.bg_color = Color(1, 1, 1, 0)
	_ring_style.border_color = RING_COLOR
	_ring_style.set_border_width_all(3)
	_ring_style.set_corner_radius_all(40)
	_ring = Panel.new()
	_ring.add_theme_stylebox_override("panel", _ring_style)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	add_child(_ring)

	_sprite = Sprite2D.new()
	_sprite.texture = FINGER_TEX
	_sprite.centered = false
	var tex_size: Vector2 = FINGER_TEX.get_size()
	_sprite.offset = -Vector2(tex_size.x * TIP_UV.x, tex_size.y * TIP_UV.y)
	var long_axis: float = max(tex_size.x, tex_size.y)
	if long_axis > 0.0:
		_sprite.scale = Vector2.ONE * (FINGER_LENGTH / long_axis)
	_sprite.visible = false
	add_child(_sprite)

## Point at a fixed screen rectangle (used for skill-tree nodes).
func point_at_rect(rect: Rect2) -> void:
	_target_control = null
	_target_rect = rect
	_has_target = true
	_reveal()

## Point at a live Control — its rect is re-read every frame, so the finger
## follows buttons that are still tweening into place.
func point_at_control(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		clear_target()
		return
	_target_control = c
	_target_rect = c.get_global_rect()
	_has_target = true
	_reveal()

func clear_target() -> void:
	_has_target = false
	_target_control = null
	_sprite.visible = false
	_ring.visible = false

## When false the finger still shows but stops blocking input elsewhere.
func set_gating(on: bool) -> void:
	_gating = on

func allowed_rect() -> Rect2:
	return _target_rect.grow(6.0)

func _reveal() -> void:
	_sprite.visible = true
	_ring.visible = true
	_update_placement()
	_sprite.modulate.a = 0.0
	_ring.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "modulate:a", 1.0, 0.25)
	tw.tween_property(_ring, "modulate:a", 1.0, 0.25)

func _process(delta: float) -> void:
	if not _has_target: return
	_time += delta
	if _target_control != null:
		if not is_instance_valid(_target_control) or not _target_control.is_visible_in_tree():
			clear_target()
			return
		_target_rect = _target_control.get_global_rect()
	_update_placement()

func _update_placement() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var centre: Vector2 = _target_rect.get_center()

	# Prefer sitting below the target (the hand's natural pose points up-left);
	# flip above it when there is no room for the hand at the bottom.
	var anchor_x: float = clamp(centre.x + _target_rect.size.x * 0.22, _target_rect.position.x, _target_rect.end.x)
	var anchor := Vector2(anchor_x, _target_rect.end.y + GAP)
	if anchor.y + FINGER_LENGTH > vp.y:
		anchor = Vector2(anchor_x, _target_rect.position.y - GAP)

	var dir: Vector2 = (centre - anchor)
	if dir.length() < 0.001:
		dir = Vector2.UP
	dir = dir.normalized()

	var bob: float = sin(_time * 3.4) * BOB
	_sprite.position = anchor - dir * bob
	_sprite.rotation = dir.angle() - DEFAULT_ANGLE

	var ring_rect: Rect2 = _target_rect.grow(RING_PAD)
	_ring.position = ring_rect.position
	_ring.size = ring_rect.size
	_ring.pivot_offset = ring_rect.size * 0.5
	var pulse: float = 1.0 + 0.035 * sin(_time * 3.4)
	_ring.scale = Vector2(pulse, pulse)
	_ring_style.set_corner_radius_all(int(min(ring_rect.size.x, ring_rect.size.y) * 0.5))

func _input(event: InputEvent) -> void:
	if not _gating or not _has_target:
		return

	var pos := Vector2.ZERO
	var positional := false
	if event is InputEventScreenTouch:
		pos = event.position
		positional = true
	elif event is InputEventMouseButton:
		pos = event.position
		positional = true
	elif event is InputEventScreenDrag:
		pos = event.position
		positional = true
	elif event is InputEventMouseMotion:
		return  # hover feedback stays alive
	elif event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		return
	else:
		return

	if not positional:
		return
	if allowed_rect().has_point(pos):
		if event is InputEventScreenTouch and event.pressed:
			target_pressed.emit()
		elif event is InputEventMouseButton and event.pressed:
			target_pressed.emit()
		return  # falls through to the real Button / Control
	get_viewport().set_input_as_handled()
