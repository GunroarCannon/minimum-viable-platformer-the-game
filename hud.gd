extends CanvasLayer

const FONT_KA1 := preload("res://assets/fonts/ka1.ttf")

@onready var root: Control = $Root
@onready var dist_label: Label = $Root/Bar/Distance
@onready var tokens_label: Label = $Root/Bar/Tokens
@onready var best_label: Label = $Root/Bar/Best

var _shown: bool = false
var _last_tokens: int = 0
var _mult_label: Label = null
var _best_flag: Label = null   # rotated side indicator

func _ready() -> void:
	layer = 30
	_shown = Global.is_unlocked("hud")
	visible = _shown
	if not _shown: return
	UITheme.apply_current(self)
	_last_tokens = Global.tokens
	root.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(0.10)

	_build_mult_label()
	_build_best_flag()

	if _is_touch_platform():
		_build_touch_controls()

func _build_mult_label() -> void:
	_mult_label = Label.new()
	_mult_label.add_theme_font_override("font", FONT_KA1)
	_mult_label.add_theme_font_size_override("font_size", 34)
	_mult_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
	_mult_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	_mult_label.add_theme_constant_override("outline_size", 6)
	_mult_label.text = ""
	_mult_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root/Bar.add_child(_mult_label)

func _build_best_flag() -> void:
	_best_flag = Label.new()
	_best_flag.text = ""
	_best_flag.add_theme_font_override("font", FONT_KA1)
	_best_flag.add_theme_font_size_override("font_size", 28)
	_best_flag.add_theme_color_override("font_color", Color(1, 1, 1))
	_best_flag.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	_best_flag.add_theme_constant_override("outline_size", 6)
	_best_flag.rotation_degrees = -90.0
	_best_flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_best_flag.custom_minimum_size = Vector2(240, 40)
	_best_flag.position = Vector2(48, get_viewport().get_visible_rect().size.y * 0.5 + 120)
	_best_flag.visible = false
	root.add_child(_best_flag)

func _is_touch_platform() -> bool:
	return OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()

func _build_touch_controls() -> void:
	var pad := Control.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pad)

	var jump := Button.new()
	jump.text = "▲"
	jump.custom_minimum_size = Vector2(160, 160)
	jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump.position = Vector2(-200, -200)
	jump.modulate.a = 0.55
	jump.button_down.connect(func(): Input.action_press("jump"))
	jump.button_up.connect(func():   Input.action_release("jump"))
	pad.add_child(jump)

	var left := Button.new()
	left.text = "◀"
	left.custom_minimum_size = Vector2(140, 140)
	left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	left.position = Vector2(40, -180)
	left.modulate.a = 0.55
	left.button_down.connect(func(): Input.action_press("left"))
	left.button_up.connect(func():   Input.action_release("left"))
	pad.add_child(left)

	var right := Button.new()
	right.text = "▶"
	right.custom_minimum_size = Vector2(140, 140)
	right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	right.position = Vector2(200, -180)
	right.modulate.a = 0.55
	right.button_down.connect(func(): Input.action_press("right"))
	right.button_up.connect(func():   Input.action_release("right"))
	pad.add_child(right)

func _process(_delta: float) -> void:
	if not _shown: return
	dist_label.text = "▶ %d m" % Global.last_run_distance
	tokens_label.text = "★ %d" % Global.tokens
	best_label.text = "best %d m" % Global.best_distance
	if Global.tokens != _last_tokens:
		_last_tokens = Global.tokens
		var tw = create_tween()
		tw.tween_property(tokens_label, "scale", Vector2(1.4, 1.4), 0.10).set_trans(Tween.TRANS_BACK)
		tw.tween_property(tokens_label, "scale", Vector2.ONE, 0.20)

	# Combo multiplier chip.
	if _mult_label:
		var m: int = ComboSystem.current_multiplier() if has_node("/root/ComboSystem") else 0
		if m >= 1:
			_mult_label.text = "x%d" % m
			_mult_label.visible = true
		else:
			_mult_label.text = ""
			_mult_label.visible = false

	_update_best_flag()

func _update_best_flag() -> void:
	if _best_flag == null: return
	var score := Global.current_run_score
	var ever := Global.best_score_ever
	var seed_best := Global.current_seed_best_score
	# Priority: beat ever > beat seed > almost either.
	var state := ""
	var beat := false
	if ever > 0 and score > ever:
		state = "NEW BEST!"; beat = true
	elif seed_best > 0 and score > seed_best:
		state = "NEW BEST!"; beat = true
	elif ever > 0 and score >= int(ever * 0.9):
		state = "ALMOST!"
	elif seed_best > 0 and score >= int(seed_best * 0.9):
		state = "ALMOST!"
	if state == "":
		_best_flag.visible = false
		return
	_best_flag.visible = true
	_best_flag.text = state
	var t = Time.get_ticks_msec() * 0.001
	if beat:
		var hue = fmod(t * 0.4, 1.0)
		_best_flag.add_theme_color_override("font_color", Color.from_hsv(hue, 0.85, 1.0))
	else:
		_best_flag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
	var scale_factor = 1.0 + 0.06 * sin(t * (5.0 if beat else 3.0))
	_best_flag.scale = Vector2(scale_factor, scale_factor)
