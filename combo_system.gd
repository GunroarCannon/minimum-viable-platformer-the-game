extends CanvasLayer

## Airtime + stomp combo system. Autoloaded.
##
## Multiplier is time-based: every COMBO_TICK_SECS of an active combo adds +1.
## Stomping enemies with a combo_bonus adds instantly (bouncy +2, super +10).
## While active, tokens earned are scaled by the multiplier (via
## Global.token_multiplier).
##
## The floating "xN / airtime" popup pins to the top-right and is gated behind
## the `combo_system` skill. Bounce transition is opt-in via `combo_bounce`.

const FONT_KA1  := preload("res://assets/fonts/ka1.ttf")
const FONT_FUNK := preload("res://assets/fonts/funkymuskrat.ttf")

const COMBO_TICK_SECS := 1.5
const STOMP_WORDS := ["STOMP!", "BOOM!", "POW!", "GOTCHA!", "ZAP!", "WHACK!", "OJ!", "SPLAT!"]

var _airborne: bool = false
var _combo_active: bool = false
var _combo_start_ms: int = 0
var _bonus: int = 0            # accumulated stomp bonuses this combo
var _multiplier: int = 0       # last computed integer multiplier
var _last_tick_shown: int = 0

var _live_popup: Label = null  # persistent big-xN popup while active

func _ready() -> void:
	layer = 80
	set_process(true)

func _gated() -> bool:
	return Global.is_unlocked("combo_system")

## External read for HUD / token scaling.
func current_multiplier() -> int:
	return _multiplier if _combo_active else 0

## Multiplicative bonus applied to earned tokens while a combo is live.
func token_multiplier() -> int:
	return max(1, current_multiplier())

func notify_airborne(is_air: bool) -> void:
	if not _gated(): return
	if is_air and not _airborne:
		_airborne = true
		if not _combo_active:
			_begin_combo()
	elif not is_air and _airborne:
		_airborne = false
		# End combo on landing.
		_end_combo()

func notify_stomp(world_pos: Vector2, combo_bonus: int = 0) -> void:
	if not _gated(): return
	if not _combo_active:
		_begin_combo()
	_bonus += combo_bonus
	# Stomping mid-combo re-arms the "airborne" state so a bounce continues it.
	_airborne = true
	_recompute_multiplier()
	_track_longest_combo(_multiplier)
	# Score bonus from the stomp itself, scaled by mult.
	Global.add_run_score(50 * token_multiplier())
	var word: String = STOMP_WORDS[randi() % STOMP_WORDS.size()]
	_spawn_side_popup(world_pos, word)

## Hard reset. Called on player death and new-run start so combo state never
## leaks across lives or runs.
func reset() -> void:
	_airborne = false
	_bonus = 0
	_multiplier = 0
	_last_tick_shown = 0
	_combo_active = false
	if _live_popup and is_instance_valid(_live_popup):
		_live_popup.queue_free()
	_live_popup = null

func _begin_combo() -> void:
	_combo_active = true
	_combo_start_ms = Time.get_ticks_msec()
	_bonus = 0
	_multiplier = 0
	_last_tick_shown = 0

func _end_combo() -> void:
	_combo_active = false
	_multiplier = 0
	_bonus = 0
	_last_tick_shown = 0
	if _live_popup and is_instance_valid(_live_popup):
		var pop = _live_popup
		_live_popup = null
		var tw = create_tween()
		tw.tween_property(pop, "modulate:a", 0.0, 0.25)
		tw.tween_callback(pop.queue_free)

func _elapsed_secs() -> float:
	return (Time.get_ticks_msec() - _combo_start_ms) / 1000.0

func _recompute_multiplier() -> void:
	var mult = int(floor(_elapsed_secs() / COMBO_TICK_SECS)) + _bonus
	if mult > _multiplier:
		var jumped = mult - _multiplier
		_multiplier = mult
		# Frame freeze on tick if impact_freeze is unlocked.
		if Global.is_unlocked("impact_freeze"):
			Engine.time_scale = 0.05
			var t = get_tree().create_timer(0.045, true, false, true)
			t.timeout.connect(func(): Engine.time_scale = 1.0)
		_last_tick_shown = _multiplier
	else:
		_multiplier = mult

func _process(_delta: float) -> void:
	if not _combo_active: return
	_recompute_multiplier()
	if _multiplier >= 1:
		if _live_popup == null or not is_instance_valid(_live_popup):
			_live_popup = _make_live_popup()
			add_child(_live_popup)
		_update_live_popup()
	# End combo if grace period elapses without airborne / bonus refresh.
	if not _airborne and _elapsed_secs() > 0.35 and _bonus == 0:
		_end_combo()

func _make_live_popup() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_override("font", FONT_KA1)
	label.add_theme_font_size_override("font_size", 60)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 100
	label.modulate.a = 0.0
	var vp := get_viewport().get_visible_rect().size
	label.size = Vector2(360, 130)
	label.pivot_offset = label.size * 0.5
	label.position = Vector2(vp.x - label.size.x - 32, 90)
	if Global.is_unlocked("combo_bounce"):
		label.scale = Vector2(0.6, 0.6)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(label, "modulate:a", 1.0, 0.15)
		tw.tween_property(label, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tw = create_tween()
		tw.tween_property(label, "modulate:a", 1.0, 0.15)
	return label

func _update_live_popup() -> void:
	if _live_popup == null: return
	var big := "x%d" % _multiplier
	var small := "%.1fs" % _elapsed_secs()
	# Two-line label: big on top, smaller time underneath. Uses BBCode-free
	# Label so we approximate size difference with newline + note.
	_live_popup.text = "%s\n%s" % [big, small]

func _spawn_side_popup(world_pos: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT_FUNK)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 100

	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size
	label.size = Vector2(280, 84)
	label.pivot_offset = label.size * 0.5
	var canvas_xform := vp.get_canvas_transform()
	var screen_pos := canvas_xform * (world_pos + Vector2(0, -160))
	var target_pos: Vector2 = screen_pos - Vector2(label.size.x * 0.5, label.size.y * 0.5)
	target_pos.x = clamp(target_pos.x, 24, vp_size.x - label.size.x - 24)
	target_pos.y = clamp(target_pos.y, 60, vp_size.y - label.size.y - 60)
	label.position = target_pos
	label.rotation_degrees = randf_range(-8.0, 8.0)
	label.modulate.a = 0.0
	add_child(label)

	var tw := create_tween().set_parallel(true)
	if Global.is_unlocked("combo_bounce"):
		label.scale = Vector2(0.4, 0.4)
		tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 1.0, 0.12)
	var tw2 := create_tween()
	tw2.tween_interval(0.45)
	tw2.tween_property(label, "position:y", label.position.y - 80.0, 0.45)
	var tw3 := create_tween()
	tw3.tween_interval(0.45)
	tw3.tween_property(label, "modulate:a", 0.0, 0.30)
	tw3.tween_callback(label.queue_free)

func _track_longest_combo(value: int) -> void:
	Global.stat_max("longest_combo", value)
