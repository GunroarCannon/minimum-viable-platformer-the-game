extends CanvasLayer

@onready var root: Control = $Root
@onready var dist_label: Label = $Root/Bar/Distance
@onready var tokens_label: Label = $Root/Bar/Tokens
@onready var best_label: Label = $Root/Bar/Best

var _shown: bool = false
var _last_tokens: int = 0

func _ready() -> void:
	layer = 30
	_shown = Global.is_unlocked("hud")
	visible = _shown
	if not _shown: return
	UITheme.apply_current(self)
	_last_tokens = Global.tokens
	# Slide-in
	root.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.35).set_delay(0.10)

	if _is_touch_platform():
		_build_touch_controls()

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
