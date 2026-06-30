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
