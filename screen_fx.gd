extends CanvasLayer

## Autoloaded screen-space post-process stack. Each pass is a full-screen
## ColorRect with a ShaderMaterial. Stacking order is fixed; passes only run
## when their respective unlock is owned and `Global.use_primitives` is off.
##
## Order: color_grading → chromatic_aberration → vignette → crt_filter → wobble_shader
## (outline is per-sprite, applied directly to player anim, not here)
##
## Pulses (for chromatic):  call ScreenFX.kick_chromatic(amount, duration)
## Wobble intensity:        set ScreenFX.wobble_intensity from player each frame

var passes: Dictionary = {}      # feature_key → ColorRect
var _chromatic_decay: float = 0.0
var _chromatic_kick: float = 0.0
const CHROMATIC_BASE := 0.006
const CHROMATIC_MAX  := 0.028

## Set each frame by player.gd when "wobble_shader" is unlocked.
var wobble_intensity: float = 0.0
var _wobble_time: float = 0.0

func _ready() -> void:
	layer = 90
	_add_pass("color_grading",        preload("res://shaders/color_grading.gdshader"))
	_add_pass("chromatic_aberration", preload("res://shaders/chromatic.gdshader"))
	_add_pass("fog_cover",            preload("res://shaders/fog_cover.gdshader"))
	_add_pass("vignette",             preload("res://shaders/vignette.gdshader"))
	# Skip screen-sampling shaders on lightweight targets (web + mobile) — they
	# tank the frame rate and don't compose well with the GL Compat renderer's
	# framebuffer round-trips on those platforms.
	if not _is_lightweight_target():
		_add_pass("crt_filter",       preload("res://shaders/crt.gdshader"))
		_add_pass("wobble_shader",    preload("res://shaders/wobble.gdshader"))
	set_process(true)

func _is_lightweight_target() -> bool:
	var name := OS.get_name()
	return name in ["Web", "Android", "iOS"]

func _add_pass(feature_key: String, sh: Shader) -> void:
	var r = ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Transparent base so that if the shader ever fails to compile or fails to
	# sample screen_tex, we get "no visible effect" instead of a full white flash.
	r.color = Color(1, 1, 1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = sh
	r.material = mat
	add_child(r)
	passes[feature_key] = r

func _process(delta: float) -> void:
	_wobble_time += delta

	for key in passes.keys():
		var r: ColorRect = passes[key]
		# Wobble stays visible whenever unlocked. Toggling it on/off mid-frame
		# based on intensity was causing a one-frame white flash on some drivers
		# because screen_tex was sampled before the backbuffer had been populated
		# for this pass. Intensity=0 is now a proper identity in the shader, so
		# leaving it visible is cheap and safe.
		var enabled: bool = Global.is_unlocked(key) and not Global.use_primitives
		if r.visible != enabled:
			r.visible = enabled

	# Update wobble shader uniforms each frame.
	var wobble_r: ColorRect = passes.get("wobble_shader", null)
	if wobble_r and wobble_r.material:
		wobble_r.material.set_shader_parameter("intensity", wobble_intensity)
		wobble_r.material.set_shader_parameter("time_sec", _wobble_time)

	# Decay chromatic kick.
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
