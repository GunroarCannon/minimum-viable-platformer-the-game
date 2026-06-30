extends Node

## Data-only skills database.
## Adding a new skill = appending one Dictionary entry. UI + gating discover it.
##
## Required fields:
##   id, name, desc, cost, requires, branch, tree_pos
## Optional:
##   feature   – override gating key if it differs from id
##   icon      – single glyph drawn on the node

const ROOT_ID := "ui"

var SKILLS: Dictionary = {

	# ═══════════════════════════════════════════════════════════════════
	# ROOT
	# ═══════════════════════════════════════════════════════════════════
	"ui": {
		"id": "ui", "name": "Unlock UI",
		"desc": "Adds the main menu, shop and settings screens.\nWithout this you only see the game world.",
		"cost": 1, "requires": [], "branch": "ui",
		"tree_pos": Vector2(0, 0), "icon": "▣",
	},

	# ═══════════════════════════════════════════════════════════════════
	# UI BRANCH (NW)
	# ═══════════════════════════════════════════════════════════════════
	"ui_polished": {
		"id": "ui_polished", "name": "Polished UI",
		"desc": "Rounded panels, smooth hover animations, custom colours.",
		"cost": 4, "requires": ["ui"], "branch": "ui",
		"tree_pos": Vector2(-2.0, -1.2), "icon": "✦",
	},
	"main_menu_extras": {
		"id": "main_menu_extras", "name": "Menu Polish",
		"desc": "Animated title intro, button SFX hooks.",
		"cost": 3, "requires": ["ui_polished"], "branch": "ui",
		"tree_pos": Vector2(-3.5, -2.2), "icon": "♫",
	},
	"hud": {
		"id": "hud", "name": "In-Game HUD",
		"desc": "Distance and token counters appear during play.",
		"cost": 2, "requires": ["ui"], "branch": "ui",
		"tree_pos": Vector2(-3.4, -0.4), "icon": "▤",
	},
	"pause_menu": {
		"id": "pause_menu", "name": "Pause Menu",
		"desc": "Press Esc to pause and access shop / menu mid-run.",
		"cost": 2, "requires": ["hud"], "branch": "ui",
		"tree_pos": Vector2(-4.6, -1.4), "icon": "▥",
	},

	# ═══════════════════════════════════════════════════════════════════
	# JUICE BRANCH (SW)
	# ═══════════════════════════════════════════════════════════════════
	"juice_squash": {
		"id": "juice_squash", "name": "Squash & Stretch",
		"desc": "Player squishes on jump and lands with a satisfying squash.\nFloors squish on landing too.",
		"cost": 2, "requires": ["ui"], "branch": "juice",
		"tree_pos": Vector2(-1.6, 1.4), "icon": "▽",
	},
	"hit_flash": {
		"id": "hit_flash", "name": "Hit Flash",
		"desc": "Things flash white when stomped or stunned.",
		"cost": 1, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-3.0, 1.4), "icon": "✺",
	},
	"impact_freeze": {
		"id": "impact_freeze", "name": "Impact Freeze",
		"desc": "Time briefly pauses on heavy impacts. Feels chunky.",
		"cost": 2, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-2.4, 2.4), "icon": "❄",
	},
	"motion_trail": {
		"id": "motion_trail", "name": "Motion Trail",
		"desc": "A trailing afterimage follows the running player.",
		"cost": 2, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-1.0, 2.6), "icon": "≈",
	},
	"footstep_dust": {
		"id": "footstep_dust", "name": "Footstep Dust",
		"desc": "Small puffs kick up while you sprint along the ground.",
		"cost": 1, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-4.2, 2.2), "icon": "˙",
	},
	"tear_effects": {
		"id": "tear_effects", "name": "Tear Effects",
		"desc": "Things shatter into rigid-body pieces when destroyed.",
		"cost": 3, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-3.4, 3.2), "icon": "✸",
	},
	"blood_splats": {
		"id": "blood_splats", "name": "Blood Splats",
		"desc": "Death is messy. Red splatter on enemy and player death.",
		"cost": 2, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-2.0, 3.6), "icon": "✚",
	},

	# ═══════════════════════════════════════════════════════════════════
	# CAMERA EFFECTS BRANCH (S)
	# ═══════════════════════════════════════════════════════════════════
	"camera_shake": {
		"id": "camera_shake", "name": "Camera Shake",
		"desc": "Big impacts shake the camera. More game-feel.",
		"cost": 2, "requires": ["ui"], "branch": "camera",
		"tree_pos": Vector2(-0.6, 2.4), "icon": "≋",
	},
	"dynamic_zoom": {
		"id": "dynamic_zoom", "name": "Dynamic Zoom",
		"desc": "Camera zooms out over wide gaps so you can see what's coming.",
		"cost": 3, "requires": ["camera_shake"], "branch": "camera",
		"tree_pos": Vector2(-0.6, 3.6), "icon": "⊙",
	},

	# ═══════════════════════════════════════════════════════════════════
	# SHADERS BRANCH (SE)
	# ═══════════════════════════════════════════════════════════════════
	"vignette": {
		"id": "vignette", "name": "Vignette",
		"desc": "Darkened corners for cinematic framing.",
		"cost": 2, "requires": ["ui_polished"], "branch": "shaders",
		"tree_pos": Vector2(1.6, 3.0), "icon": "◐",
	},
	"chromatic_aberration": {
		"id": "chromatic_aberration", "name": "Chromatic Aberration",
		"desc": "RGB channels split at the edges, exaggerated under impact.",
		"cost": 2, "requires": ["vignette"], "branch": "shaders",
		"tree_pos": Vector2(2.8, 3.8), "icon": "◑",
	},
	"color_grading": {
		"id": "color_grading", "name": "Color Grading",
		"desc": "Warm filmic tint and punchier saturation.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "shaders",
		"tree_pos": Vector2(0.6, 4.0), "icon": "◧",
	},
	"crt_filter": {
		"id": "crt_filter", "name": "CRT Filter",
		"desc": "Scanlines and screen curvature.",
		"cost": 3, "requires": ["chromatic_aberration"], "branch": "shaders",
		"tree_pos": Vector2(3.2, 5.0), "icon": "▦",
	},
	"outline": {
		"id": "outline", "name": "Sprite Outline",
		"desc": "Dark ink outline around the player sprite.",
		"cost": 2, "requires": ["player_sprite"], "branch": "shaders",
		"tree_pos": Vector2(3.6, 1.6), "icon": "◌",
	},

	# ═══════════════════════════════════════════════════════════════════
	# MOVES BRANCH (E)
	# ═══════════════════════════════════════════════════════════════════
	"sprint": {
		"id": "sprint", "name": "Sprint",
		"desc": "Higher top speed when auto-running.",
		"cost": 2, "requires": ["ui"], "branch": "moves",
		"tree_pos": Vector2(1.4, 0.6), "icon": "➤",
	},
	"double_jump": {
		"id": "double_jump", "name": "Double Jump",
		"desc": "Press jump again in mid-air to leap a second time.",
		"cost": 3, "requires": ["sprint"], "branch": "moves",
		"tree_pos": Vector2(2.6, 0.0), "icon": "⇈",
	},
	"dash_move": {
		"id": "dash_move", "name": "Dash",
		"desc": "Press Shift to dash horizontally.",
		"cost": 3, "requires": ["sprint"], "branch": "moves",
		"tree_pos": Vector2(2.2, 1.6), "icon": "↦",
	},
	"wall_jump": {
		"id": "wall_jump", "name": "Wall Jump",
		"desc": "Jump again off walls during a slide.",
		"cost": 3, "requires": ["double_jump"], "branch": "moves",
		"tree_pos": Vector2(3.8, 0.6), "icon": "⤴",
	},

	# ═══════════════════════════════════════════════════════════════════
	# GRAPHICS BRANCH (NE → E)
	# ═══════════════════════════════════════════════════════════════════
	"drawn_floors": {
		"id": "drawn_floors", "name": "Drawn Floors",
		"desc": "Replaces primitive blocks with hand-drawn wavy yellow-green platforms.",
		"cost": 2, "requires": ["ui"], "branch": "graphics",
		"tree_pos": Vector2(-0.4, -1.0), "icon": "▰",
	},
	"foliage": {
		"id": "foliage", "name": "Foliage",
		"desc": "Little tufts of grass and flowers along the floor edge.",
		"cost": 1, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(-1.2, -0.2), "icon": "❀",
	},
	"player_sprite": {
		"id": "player_sprite", "name": "Player Sprite",
		"desc": "Replaces the player rectangle with proper character art.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(0.4, -2.0), "icon": "☺",
	},
	"sprite_animations": {
		"id": "sprite_animations", "name": "Sprite Animations",
		"desc": "Idle, run, jump and hurt animations play for the player.",
		"cost": 3, "requires": ["player_sprite"], "branch": "graphics",
		"tree_pos": Vector2(1.6, -2.6), "icon": "▷",
	},
	"parallax": {
		"id": "parallax", "name": "Parallax Backdrop",
		"desc": "Multi-layer scrolling background hills.",
		"cost": 3, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(0.0, 0.6), "icon": "≣",
	},
	"clouds": {
		"id": "clouds", "name": "Clouds",
		"desc": "Soft clouds drift across the sky.",
		"cost": 2, "requires": ["parallax"], "branch": "graphics",
		"tree_pos": Vector2(-1.0, 1.2), "icon": "☁",
	},
	"particles": {
		"id": "particles", "name": "Particles",
		"desc": "Dust on landing, smoke on death, sparks on stomp.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(1.4, -1.6), "icon": "✶",
	},

	# ═══════════════════════════════════════════════════════════════════
	# ENEMIES BRANCH (N)
	# ═══════════════════════════════════════════════════════════════════
	"enemies_basic": {
		"id": "enemies_basic", "name": "Basic Enemies",
		"desc": "Frogs and kobolds start appearing in levels.",
		"cost": 2, "requires": ["ui"], "branch": "enemies",
		"tree_pos": Vector2(0.0, -3.6), "icon": "▼",
	},
	"enemy_sprites": {
		"id": "enemy_sprites", "name": "Enemy Sprites",
		"desc": "Enemies, spikes and smashers get their proper sprite art.",
		"cost": 2, "requires": ["enemies_basic"], "branch": "enemies",
		"tree_pos": Vector2(-1.8, -4.0), "icon": "☻",
	},
	"enemies_more": {
		"id": "enemies_more", "name": "More Enemies",
		"desc": "Bats and big frogs join the party.",
		"cost": 3, "requires": ["enemies_basic"], "branch": "enemies",
		"tree_pos": Vector2(0.8, -4.6), "icon": "⩥",
	},
	"enemies_advanced": {
		"id": "enemies_advanced", "name": "Advanced Enemies",
		"desc": "Bombs, shooters, drills and jumpers.",
		"cost": 4, "requires": ["enemies_more"], "branch": "enemies",
		"tree_pos": Vector2(2.2, -5.4), "icon": "✕",
	},
	"smashers": {
		"id": "smashers", "name": "Smashers",
		"desc": "Ceiling hammers that drop when you walk under them.",
		"cost": 3, "requires": ["enemies_more"], "branch": "enemies",
		"tree_pos": Vector2(-0.6, -5.6), "icon": "▮",
	},

	# ═══════════════════════════════════════════════════════════════════
	# LEVEL BRANCH (NE)
	# ═══════════════════════════════════════════════════════════════════
	"procgen": {
		"id": "procgen", "name": "Full Procedural",
		"desc": "Unlocks the full library of level templates: stairs, elevated platforms, combos.\nWithout this you only run on flat ground.",
		"cost": 4, "requires": ["ui"], "branch": "level",
		"tree_pos": Vector2(2.6, -1.0), "icon": "⌬",
	},
	"coins": {
		"id": "coins", "name": "Coins",
		"desc": "Golden coins appear in levels. Collect them for bonus tokens.",
		"cost": 3, "requires": ["procgen"], "branch": "level",
		"tree_pos": Vector2(3.8, -1.8), "icon": "◉",
	},
}

const BRANCH_COLORS := {
	"ui":       Color(0.55, 0.78, 0.95),
	"juice":    Color(1.00, 0.55, 0.40),
	"graphics": Color(0.55, 0.85, 0.50),
	"enemies":  Color(0.95, 0.45, 0.55),
	"level":    Color(0.85, 0.75, 0.40),
	"camera":   Color(0.70, 0.55, 0.95),
	"shaders":  Color(0.40, 0.85, 0.85),
	"moves":    Color(0.95, 0.85, 0.45),
}

const BRANCH_NAMES := {
	"ui":       "Interface",
	"juice":    "Juice",
	"graphics": "Graphics",
	"enemies":  "Enemies",
	"level":    "Level",
	"camera":   "Camera FX",
	"shaders":  "Shaders",
	"moves":    "Moves",
}

func get_feature_key(skill_id: String) -> String:
	var d = SKILLS.get(skill_id, null)
	if d == null: return skill_id
	return d.get("feature", skill_id)

func get_branch_color(branch: String) -> Color:
	return BRANCH_COLORS.get(branch, Color.WHITE)

func can_afford(skill_id: String) -> bool:
	var d = SKILLS.get(skill_id, null)
	if d == null: return false
	return Global.tokens >= int(d["cost"])

func prereqs_met(skill_id: String) -> bool:
	var d = SKILLS.get(skill_id, null)
	if d == null: return false
	for r in d.get("requires", []):
		if not Global.is_unlocked(get_feature_key(r)):
			return false
	return true

func is_purchased(skill_id: String) -> bool:
	return Global.is_unlocked(get_feature_key(skill_id))

## Attempt to purchase. Returns true on success.
func purchase(skill_id: String) -> bool:
	if is_purchased(skill_id): return false
	if not prereqs_met(skill_id): return false
	var d = SKILLS.get(skill_id, null)
	if d == null: return false
	var cost = int(d["cost"])
	if not Global.spend(cost): return false
	Global.grant(get_feature_key(skill_id))
	return true
