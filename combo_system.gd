extends CanvasLayer

## Airtime + stomp combo system. Autoloaded.
##
## Tracks how long the player has been airborne without touching a solid,
## non-auto-jump surface. Each enemy stomp while airborne raises a multiplier.
## Both events spawn a floating popup with a random funky font.

const FONTS := [
	preload("res://assets/fonts/funkymuskrat.ttf"),
	preload("res://assets/fonts/FOO.ttf"),
	preload("res://assets/fonts/orange juice 2.0.ttf"),
]

const STOMP_WORDS := ["STOMP!", "BOOM!", "POW!", "GOTCHA!", "ZAP!", "WHACK!", "OJ!", "SPLAT!"]
const AIR_MIN_TIME := 0.85  # seconds airborne before the payoff popup triggers on landing

var _airborne: bool = false
var _air_start_ms: int = 0
var _multiplier: int = 0

func _ready() -> void:
	layer = 80

func notify_airborne(is_air: bool) -> void:
	if is_air and not _airborne:
		_airborne = true
		_air_start_ms = Time.get_ticks_msec()
		_multiplier = 0
	elif not is_air and _airborne:
		_airborne = false
		var duration := (Time.get_ticks_msec() - _air_start_ms) / 1000.0
		if duration >= AIR_MIN_TIME or _multiplier > 0:
			_spawn_air_summary(duration)
		_multiplier = 0

func notify_stomp(world_pos: Vector2) -> void:
	if not _airborne:
		# First hop out of ground; treat this stomp as beginning the combo.
		_airborne = true
		_air_start_ms = Time.get_ticks_msec()
	_multiplier += 1
	_track_longest_combo(_multiplier)
	var word: String = STOMP_WORDS[randi() % STOMP_WORDS.size()]
	var text: String = word if _multiplier < 2 else "%s x%d" % [word, _multiplier]
	_spawn_popup(world_pos, text, Color(1.0, 0.85, 0.2))

func _spawn_air_summary(seconds: float) -> void:
	# Air summary lives in the TOP-RIGHT of the screen, not on the player.
	# Keeps it out of the play area so the player can see where they're going.
	var head: String
	if _multiplier >= 3:
		head = "MEGA COMBO"
	elif _multiplier == 2:
		head = "DOUBLE!"
	elif _multiplier == 1:
		head = "COMBO"
	else:
		head = "AIR TIME"
	var text := "%s\n%.2fs" % [head, seconds]
	_spawn_popup(Vector2.ZERO, text, Color(0.4, 0.95, 1.0), "top_right")

func _spawn_popup(world_pos: Vector2, text: String, col: Color, mode: String = "above_player") -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = FONTS[randi() % FONTS.size()]
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 100

	# Anchor the popup either above the player's head (stomps) or pinned to the
	# top-right corner (air summaries). Never in the middle of the screen.
	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size
	label.size = Vector2(320, 96)
	label.pivot_offset = label.size * 0.5
	var target_pos: Vector2
	if mode == "top_right":
		target_pos = Vector2(vp_size.x - label.size.x - 24, 90)
	else:
		# Above the player head in screen space.
		var canvas_xform := vp.get_canvas_transform()
		var screen_pos := canvas_xform * (world_pos + Vector2(0, -180))
		target_pos = screen_pos - Vector2(label.size.x * 0.5, label.size.y * 0.5)
		# Clamp so the popup doesn't fly off the sides.
		target_pos.x = clamp(target_pos.x, 24, vp_size.x - label.size.x - 24)
		target_pos.y = clamp(target_pos.y, 60, vp_size.y - label.size.y - 60)
	label.position = target_pos
	label.scale = Vector2(0.3, 0.3)
	label.modulate.a = 0.0
	add_child(label)

	# Random slight rotation for character.
	label.rotation_degrees = randf_range(-8.0, 8.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 1.0, 0.12)
	var tw2 := create_tween()
	tw2.tween_interval(0.55)
	tw2.tween_property(label, "position:y", label.position.y - 80.0, 0.55)
	var tw3 := create_tween()
	tw3.tween_interval(0.55)
	tw3.tween_property(label, "modulate:a", 0.0, 0.35)
	tw3.tween_callback(label.queue_free)

func _track_longest_combo(value: int) -> void:
	Global.stat_max("longest_combo", value)
