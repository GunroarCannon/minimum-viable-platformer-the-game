extends Node

@export_multiline var README: String = "IMPORTANT: This script automatically initializes the Input Map configuration for 'left', 'right', 'jump', 'dash', 'up', and 'down' at boot. Physical keys are assigned programmatically."

# ─── CAMERA ZOOM SETTINGS ──────────────────────────────────────────────────
## 1 = Zoom out when a hazard is further than camera_hazard_distance from the player
## 2 = Zoom out when fewer than camera_tile_threshold solid tiles are visible on screen
@export_enum("Hazard Distance:1", "Tile Count:2") var camera_zoom_mode: int = 2

@export var debugText: bool = true

## How much to multiply the base zoom by when zoomed out (< 1.0 = further out)
@export var camera_zoom_out_factor: float = 0.62

## [Mode 1] If a hazard is beyond this many pixels ahead, zoom out
@export var camera_hazard_distance: float = 900.0

## [Mode 2] If fewer than this many solid tiles are visible, zoom out
@export var camera_tile_threshold: int = 12	

## Tween duration for zoom transitions in seconds
@export var camera_zoom_tween_duration: float = 0.55

# ─── DEBUG ──────────────────────────────────────────────────────────────
## Show debug overlay (FPS, memory, velocity, zoom, momentum, stun)
@export var debug_text: bool = false

## Persistent dictionary of debug toggles, easy to extend with new features.
@export var debug_toggles: Dictionary = {
	"auto_restart": false,
	"keep_seed": false,
}


func _ready() -> void:
	print("[Global] _ready() called — initialising input map")
	_initialize_input_map()
	print("[Global] _ready() complete")

## Safely registers custom input strings and links them to standard default keys
func _initialize_input_map() -> void:
	var input_configs: Dictionary = {
		"left":  KEY_A,
		"right": KEY_D,
		"up":    KEY_W,
		"down":  KEY_S,
		"jump":  KEY_SPACE,
		"dash":  KEY_SHIFT
	}

	print("[Global] Registering ", input_configs.size(), " input actions...")

	for action_name in input_configs:
		var already_existed = InputMap.has_action(action_name)
		if not already_existed:
			InputMap.add_action(action_name)

		var events = InputMap.action_get_events(action_name)
		if events.is_empty():
			var key_event = InputEventKey.new()
			key_event.physical_keycode = input_configs[action_name]
			InputMap.action_add_event(action_name, key_event)
			print("[Global]   '", action_name, "' -> key ", input_configs[action_name],
				  "  (action was new: ", not already_existed, ")")
		else:
			print("[Global]   '", action_name, "' already has ", events.size(),
				  " event(s) — skipped (action existed: ", already_existed, ")")

	# Register stub actions the platformer controller references
	# so Input.is_action_pressed() doesn't spam errors
	var stub_actions = ["run", "latch", "roll", "twirl"]
	for action_name in stub_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			print("[Global]   Stub action registered: '", action_name, "'")
		else:
			print("[Global]   Stub action already exists: '", action_name, "'")

	print("[Global] Input map fully initialised.")
	print("[Global] All registered actions: ", InputMap.get_actions())
