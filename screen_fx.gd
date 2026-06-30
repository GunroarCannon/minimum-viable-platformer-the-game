extends CanvasLayer

## Autoloaded screen-space post-process stack. Each pass is a full-screen
## ColorRect with a ShaderMaterial. Stacking order is fixed; passes only run
## when their respective unlock is owned and `Global.use_primitives` is off.
##
## Order: color_grading → chromatic_aberration → vignette → crt_filter
## (outline is per-sprite, applied directly to player anim, not here)
##
## Pulses (for chromatic):  call ScreenFX.kick_chromatic(amount, duration)
## from the player when something violent happens.

var passes: Dictionary = {}      # feature_key → ColorRect
var _chromatic_decay: float = 0.0
var _chromatic_kick: float = 0.0
const CHROMATIC_BASE := 0.006
const CHROMATIC_MAX  := 0.028

func _ready() -> void:
	layer = 90
	_add_pass("color_grading",        preload("res://shaders/color_grading.gdshader"))
	_add_pass("chromatic_aberration", preload("res://shaders/chromatic.gdshader"))
	_add_pass("vignette",             preload("res://shaders/vignette.gdshader"))
	_add_pass("crt_filter",           preload("res://shaders/crt.gdshader"))
	set_process(true)

func _add_pass(feature_key: String, sh: Shader) -> void:
	var r = ColorRect.new()
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = sh
	r.material = mat
	add_child(r)
	passes[feature_key] = r

func _process(delta: float) -> void:
	for key in passes.keys():
		var enabled = Global.is_unlocked(key) and not Global.use_primitives
		var r: ColorRect = passes[key]
		if r.visible != enabled:
			r.visible = enabled

	# Decay chromatic kick
	if _chromatic_kick > 0.0:
		_chromatic_kick = max(0.0, _chromatic_kick - delta * _chromatic_decay)
		var r2: ColorRect = passes.get("chromatic_aberration", null)
		if r2 and r2.material:
			r2.material.set_shader_parameter("amount", CHROMATIC_BASE + _chromatic_kick)
	else:
		var r2b: ColorRect = passes.get("chromatic_aberration", null)
		if r2b and r2b.material:
			r2b.material.set_shader_parameter("amount", CHROMATIC_BASE)

## Briefly bump the chromatic-aberration amount toward CHROMATIC_MAX.
func kick_chromatic(amount: float = 0.022, duration: float = 0.35) -> void:
	if duration <= 0.0: duration = 0.001
	_chromatic_kick = clamp(amount, 0.0, CHROMATIC_MAX - CHROMATIC_BASE)
	_chromatic_decay = _chromatic_kick / duration
