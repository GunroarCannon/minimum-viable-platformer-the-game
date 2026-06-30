extends Control

## Mouse-navigable skill-tree drawer. Emits skill_selected(id) and skill_purchased(id).

signal skill_selected(skill_id: String)
signal skill_purchased(skill_id: String)

const NODE_RADIUS := 38.0
const GRID_SCALE  := Vector2(140.0, 110.0)

@export var pan_speed_keyboard: float = 480.0

var _camera_offset: Vector2 = Vector2.ZERO
var _panning: bool = false
var _pressed_inside: bool = false
var _press_pos: Vector2
var _drag_start_offset: Vector2
var _moved_since_press: bool = false
var _press_hit_id: String = ""
var _hover_id: String = ""
var _selected_id: String = ""
const DRAG_THRESHOLD := 6.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Centre the view on the root skill on first show.
	_centre_on_root.call_deferred()

func _centre_on_root() -> void:
	_camera_offset = size * 0.5

func _process(delta: float) -> void:
	var pan = Vector2.ZERO
	if Input.is_action_pressed("right"): pan.x -= 1
	if Input.is_action_pressed("left"):  pan.x += 1
	if Input.is_action_pressed("up"):    pan.y += 1
	if Input.is_action_pressed("down"):  pan.y -= 1
	if pan != Vector2.ZERO:
		_camera_offset += pan * pan_speed_keyboard * delta
		queue_redraw()

func _world_pos(skill_id: String) -> Vector2:
	var d = SkillsDB.SKILLS[skill_id]
	var p: Vector2 = d["tree_pos"]
	return _camera_offset + p * GRID_SCALE

func _gui_input(event: InputEvent) -> void:
	# ─── MOUSE ─────────────────────────────────────────────────────────
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_pressed_inside = true
				_panning = true
				_press_pos = event.position
				_drag_start_offset = _camera_offset
				_moved_since_press = false
				_press_hit_id = _hit_test(event.position)
			else:
				# Release: if mouse didn't move much, treat as a click.
				if _pressed_inside and not _moved_since_press and _press_hit_id != "":
					_selected_id = _press_hit_id
					emit_signal("skill_selected", _press_hit_id)
				_pressed_inside = false
				_panning = false
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if event.shift_pressed:
				_camera_offset.x += 80
			else:
				_camera_offset.y += 80
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if event.shift_pressed:
				_camera_offset.x -= 80
			else:
				_camera_offset.y -= 80
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_LEFT and event.pressed:
			_camera_offset.x += 80
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_RIGHT and event.pressed:
			_camera_offset.x -= 80
			queue_redraw()
	elif event is InputEventMouseMotion:
		if _panning:
			var delta = event.position - _press_pos
			if not _moved_since_press and delta.length() > DRAG_THRESHOLD:
				_moved_since_press = true
			if _moved_since_press:
				_camera_offset = _drag_start_offset + delta
				queue_redraw()
		var prev_hover = _hover_id
		_hover_id = _hit_test(event.position)
		if prev_hover != _hover_id:
			queue_redraw()
	# ─── TOUCH ─────────────────────────────────────────────────────────
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pressed_inside = true
			_panning = true
			_press_pos = event.position
			_drag_start_offset = _camera_offset
			_moved_since_press = false
			_press_hit_id = _hit_test(event.position)
		else:
			if _pressed_inside and not _moved_since_press and _press_hit_id != "":
				_selected_id = _press_hit_id
				emit_signal("skill_selected", _press_hit_id)
			_pressed_inside = false
			_panning = false
			queue_redraw()
	elif event is InputEventScreenDrag:
		if _panning:
			var delta = event.position - _press_pos
			if not _moved_since_press and delta.length() > DRAG_THRESHOLD:
				_moved_since_press = true
			if _moved_since_press:
				_camera_offset = _drag_start_offset + delta
				queue_redraw()

func _hit_test(local_pos: Vector2) -> String:
	for sid in SkillsDB.SKILLS.keys():
		var wp = _world_pos(sid)
		if local_pos.distance_to(wp) <= NODE_RADIUS + 2:
			return sid
	return ""

func set_selected(sid: String) -> void:
	_selected_id = sid
	queue_redraw()

func selected_id() -> String:
	return _selected_id

func _draw() -> void:
	# Background grid for navigability
	_draw_grid()

	# Edges first (under nodes)
	for sid in SkillsDB.SKILLS.keys():
		var d = SkillsDB.SKILLS[sid]
		var to_p = _world_pos(sid)
		for r in d.get("requires", []):
			if not SkillsDB.SKILLS.has(r): continue
			var from_p = _world_pos(r)
			var purchased_to = SkillsDB.is_purchased(sid)
			var purchased_from = SkillsDB.is_purchased(r)
			var col = Color(0.30, 0.25, 0.18, 0.7)
			var w = 4.0
			if purchased_from and purchased_to:
				col = Color(0.95, 0.78, 0.30); w = 6.0
			elif purchased_from:
				col = Color(0.55, 0.50, 0.40, 0.95); w = 5.0
			draw_line(from_p, to_p, col, w, true)

	# Nodes
	for sid in SkillsDB.SKILLS.keys():
		_draw_node(sid)

	# Navigation hint pill
	_draw_hint()

func _draw_hint() -> void:
	var font = ThemeDB.fallback_font
	var fs := 13
	var hint := "drag to pan  ·  wheel to scroll  ·  shift+wheel = horizontal  ·  WASD pans  ·  click a node"
	var ts = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad = Vector2(10, 6)
	var rect = Rect2(Vector2(12, 12), Vector2(ts.x + pad.x * 2, ts.y + pad.y * 2))
	draw_rect(rect, Color(0.10, 0.10, 0.12, 0.75), true)
	draw_rect(rect, Color(0.95, 0.78, 0.30, 0.5), false, 1.0)
	draw_string(font, Vector2(rect.position.x + pad.x, rect.position.y + pad.y + ts.y * 0.85),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.90, 0.75))

func _draw_grid() -> void:
	var step = 60.0
	var col = Color(0, 0, 0, 0.06)
	var sz = size
	var ox = fposmod(_camera_offset.x, step)
	var oy = fposmod(_camera_offset.y, step)
	var x = ox
	while x < sz.x:
		draw_line(Vector2(x, 0), Vector2(x, sz.y), col, 1.0)
		x += step
	var y = oy
	while y < sz.y:
		draw_line(Vector2(0, y), Vector2(sz.x, y), col, 1.0)
		y += step

func _draw_node(sid: String) -> void:
	var d = SkillsDB.SKILLS[sid]
	var p = _world_pos(sid)
	if p.x < -120 or p.x > size.x + 120 or p.y < -120 or p.y > size.y + 120:
		return
	var branch_col: Color = SkillsDB.get_branch_color(d.get("branch", "ui"))
	var purchased := SkillsDB.is_purchased(sid)
	var prereq := SkillsDB.prereqs_met(sid)
	var affordable := SkillsDB.can_afford(sid)

	var r := NODE_RADIUS
	if sid == _hover_id: r += 4
	if sid == _selected_id: r += 2

	# Shadow
	draw_circle(p + Vector2(0, 4), r, Color(0, 0, 0, 0.25))

	# Body
	var bg: Color
	if purchased:
		bg = branch_col
	elif prereq:
		if affordable:
			bg = branch_col.lerp(Color.WHITE, 0.55)
		else:
			bg = Color(0.85, 0.80, 0.70)
	else:
		bg = Color(0.40, 0.36, 0.30)
	draw_circle(p, r, bg)

	# Ring
	var ring_col := Color(0.18, 0.14, 0.10)
	if sid == _selected_id: ring_col = Color(1, 1, 1)
	draw_arc(p, r, 0.0, TAU, 64, ring_col, 3.5, true)

	# Glyph
	var icon: String = d.get("icon", "•")
	var font = ThemeDB.fallback_font
	var fs := 30
	var ts = font.get_string_size(icon, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, p - ts * 0.5 + Vector2(0, ts.y * 0.32), icon,
		HORIZONTAL_ALIGNMENT_CENTER, -1, fs, ring_col)

	# Label below
	var name_str: String = d.get("name", sid)
	var lfs := 16
	var lts = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, lfs)
	# Cream pill behind label for readability
	var pad := Vector2(8, 4)
	var rect = Rect2(p + Vector2(-lts.x * 0.5 - pad.x, r + 8 - pad.y),
					 Vector2(lts.x + pad.x * 2, lts.y + pad.y * 2))
	draw_rect(rect, Color(1, 0.95, 0.85, 0.9), true)
	draw_rect(rect, Color(0.18, 0.14, 0.10, 0.6), false, 1.0)
	draw_string(font, p + Vector2(-lts.x * 0.5, r + 8 + lts.y * 0.85), name_str,
		HORIZONTAL_ALIGNMENT_CENTER, -1, lfs, Color(0.18, 0.14, 0.10))

	# Cost badge
	if not purchased:
		var cost = int(d.get("cost", 0))
		var cs := "%d ★" % cost
		var cfs := 14
		var cts = font.get_string_size(cs, HORIZONTAL_ALIGNMENT_CENTER, -1, cfs)
		var crect = Rect2(p + Vector2(-cts.x * 0.5 - 6, -r - cts.y - 12),
						  Vector2(cts.x + 12, cts.y + 6))
		var badge_col = Color(0.95, 0.78, 0.30) if affordable and prereq else Color(0.50, 0.45, 0.40)
		draw_rect(crect, badge_col, true)
		draw_rect(crect, Color(0.18, 0.14, 0.10), false, 1.5)
		draw_string(font, p + Vector2(-cts.x * 0.5, -r - 8), cs,
			HORIZONTAL_ALIGNMENT_CENTER, -1, cfs, Color(0.18, 0.14, 0.10))
