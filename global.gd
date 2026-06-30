extends Node

@export_multiline var README: String = "IMPORTANT: This script automatically initializes the Input Map configuration for 'left', 'right', 'jump', 'dash', 'up', and 'down' at boot. Physical keys are assigned programmatically."

# ─── CAMERA ZOOM SETTINGS ──────────────────────────────────────────────────
## 1 = Zoom out when a hazard is further than camera_hazard_distance from the player
## 2 = Zoom out when fewer than camera_tile_threshold solid tiles are visible on screen
@export_enum("Hazard Distance:1", "Tile Count:2") var camera_zoom_mode: int = 2

@export var debugText: bool = true
## When true, ALL entities ignore their unlock flags and draw primitives.
## Default false — visual unlocks then control what's drawn.
@export var use_primitives: bool = false


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
@export var debug_text: bool = true

## Persistent dictionary of debug toggles, easy to extend with new features.
@export var debug_toggles: Dictionary = {
	"auto_restart": false,
	"keep_seed": false,
	"show_collisions": false,
	"show_overlay": true,
	"unlock_all": false,
}

# ─── META-PROGRESSION ──────────────────────────────────────────────────
## Currency the player earns from running.
var tokens: int = 0

## Dictionary of unlocked feature keys. e.g. { "ui": true, "juice_squash": true }
var unlocked: Dictionary = {}

## True the first time the player has died at least once.
var first_death_done: bool = false

## Best distance ever (in tile-units).
var best_distance: int = 0

## Tracks last awarded distance so we don't double-award mid-run.
var last_run_distance: int = 0

## Persisted settings (audio, theme, etc.)
var settings_cfg: Dictionary = {
	"master_volume": 0.8,
	"sfx_volume": 0.8,
	"theme": "polished",
}

const META_SAVE_PATH := "user://meta.dat"
const TOKEN_PER_TILES := 25       # 1 token per 25 tiles ran
const FIRST_DEATH_BONUS := 1      # free token on first death so player can buy UI


func _ready() -> void:
	print("[Global] _ready() called — initialising input map")
	_initialize_input_map()
	load_state()
	print("[Global] _ready() complete | tokens=", tokens, " unlocked=", unlocked)


## ─── PERSISTENCE ────────────────────────────────────────────────────────

func save_state() -> void:
	var f = FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if not f: return
	var blob = {
		"tokens": tokens,
		"unlocked": unlocked,
		"first_death_done": first_death_done,
		"best_distance": best_distance,
		"settings_cfg": settings_cfg,
	}
	f.store_var(blob)
	f.close()

func load_state() -> void:
	if not FileAccess.file_exists(META_SAVE_PATH): return
	var f = FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if not f: return
	var blob = f.get_var()
	f.close()
	if typeof(blob) != TYPE_DICTIONARY: return
	tokens = int(blob.get("tokens", 0))
	unlocked = blob.get("unlocked", {})
	first_death_done = bool(blob.get("first_death_done", false))
	best_distance = int(blob.get("best_distance", 0))
	for k in blob.get("settings_cfg", {}).keys():
		settings_cfg[k] = blob["settings_cfg"][k]


## ─── FEATURE QUERIES ───────────────────────────────────────────────────

func is_unlocked(feature_key: String) -> bool:
	if debug_toggles.get("unlock_all", false):
		return true
	return bool(unlocked.get(feature_key, false))

## Graphics-gate helper used by every sprite-loading entity.
## Returns true when "use sprite art" is wanted for the given unlock key.
func gfx(feature_key: String) -> bool:
	if use_primitives: return false
	return is_unlocked(feature_key)

func grant(feature_key: String) -> void:
	unlocked[feature_key] = true
	save_state()

## Spend N tokens. Returns true if successful.
func spend(n: int) -> bool:
	if tokens < n: return false
	tokens -= n
	save_state()
	return true

func add_tokens(n: int) -> void:
	if n <= 0: return
	tokens += n
	save_state()

## Convenience for clearing all progress (used in settings reset).
func reset_progress() -> void:
	tokens = 0
	unlocked = {}
	first_death_done = false
	best_distance = 0
	save_state()


## ─── DEATH BOOKKEEPING ─────────────────────────────────────────────────

## Called by player.die().
## Returns the number of tokens awarded this death (for UI display).
func on_player_death(distance_tiles: int) -> int:
	var awarded := 0
	if distance_tiles > 0:
		awarded = max(1, distance_tiles / TOKEN_PER_TILES)
	if not first_death_done:
		first_death_done = true
		awarded += FIRST_DEATH_BONUS
	if distance_tiles > best_distance:
		best_distance = distance_tiles
	tokens += awarded
	last_run_distance = distance_tiles
	save_state()
	return awarded


## ─── INPUT MAP ─────────────────────────────────────────────────────────

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

	# Register stub actions the platformer controller references
	var stub_actions = ["run", "latch", "roll", "twirl"]
	for action_name in stub_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

	# F3 to toggle debug overlay
	if not InputMap.has_action("toggle_debug"):
		InputMap.add_action("toggle_debug")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event("toggle_debug", ev)

	# Esc to navigate back / pause
	if not InputMap.has_action("ui_back"):
		InputMap.add_action("ui_back")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("ui_back", ev)

	print("[Global] Input map fully initialised.")
