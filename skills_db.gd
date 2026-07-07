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

# ─── COST FORMULA ─────────────────────────────────────────────────────────
# Cost is looked up by shortest-path depth from ROOT_ID.
# Edit PATH_COSTS to reshape the whole economy in one line.
# Depths beyond the table use the last value * PATH_TAIL_MULT^extra.
# A skill dict may set "cost_override" to pin a bespoke price.
const PATH_COSTS := [1, 2, 4, 10, 20, 50]
const PATH_TAIL_MULT := 2.0
const COST_MAX  := 999

var _cost_cache: Dictionary = {}
var _depth_cache: Dictionary = {}

func compute_cost(skill_id: String) -> int:
	if _cost_cache.has(skill_id): return int(_cost_cache[skill_id])
	var d = SKILLS.get(skill_id, null)
	if d != null and d.has("cost_override"):
		var over := int(d["cost_override"])
		_cost_cache[skill_id] = over
		return over
	if skill_id == ROOT_ID:
		_cost_cache[skill_id] = 1
		return 1
	var depth := depth_from_root(skill_id)
	var idx: int = clamp(depth, 0, PATH_COSTS.size() - 1)
	var raw: float = float(PATH_COSTS[idx])
	if depth >= PATH_COSTS.size():
		raw *= pow(PATH_TAIL_MULT, float(depth - PATH_COSTS.size() + 1))
	var cost = min(COST_MAX, max(1, int(round(raw))))
	_cost_cache[skill_id] = cost
	return cost

func depth_from_root(skill_id: String) -> int:
	if skill_id == ROOT_ID: return 0
	if _depth_cache.has(skill_id): return int(_depth_cache[skill_id])
	# BFS over the `requires` DAG.
	var visited := {ROOT_ID: 0}
	var queue: Array = [ROOT_ID]
	var found := -1
	while queue.size() > 0 and found < 0:
		var cur: String = queue.pop_front()
		var cur_depth: int = visited[cur]
		for other_id in SKILLS.keys():
			if visited.has(other_id): continue
			var reqs: Array = SKILLS[other_id].get("requires", [])
			if reqs.has(cur):
				visited[other_id] = cur_depth + 1
				if other_id == skill_id:
					found = cur_depth + 1
					break
				queue.append(other_id)
	var d := found if found >= 0 else 1
	_depth_cache[skill_id] = d
	return d

var SKILLS: Dictionary = {

	# ═══════════════════════════════════════════════════════════════════
	# ROOT  (centre)
	# ═══════════════════════════════════════════════════════════════════
	"ui": {
		"id": "ui", "name": "Unlock UI",
		"desc": "Adds the main menu, shop and settings screens.\nWithout this you only see the game world.",
		"cost": 1, "requires": [], "branch": "ui",
		"tree_pos": Vector2(0, 0), "icon": "UI",
	},

	# ═══════════════════════════════════════════════════════════════════
	# UI BRANCH  (left / NW)
	# ═══════════════════════════════════════════════════════════════════
	"ui_polished": {
		"id": "ui_polished", "name": "Polished UI",
		"desc": "Rounded panels, smooth hover animations, custom colours.",
		"cost": 4, "requires": ["ui"], "branch": "ui",
		"tree_pos": Vector2(-3.0, -1.5), "icon": "PL",
	},
	"main_menu_extras": {
		"id": "main_menu_extras", "name": "Menu Polish",
		"desc": "Animated title intro, button SFX hooks.",
		"cost": 3, "requires": ["ui_polished"], "branch": "ui",
		"tree_pos": Vector2(-5.0, -2.5), "icon": "MP",
	},
	"hud": {
		"id": "hud", "name": "In-Game HUD",
		"desc": "Distance and token counters appear during play.",
		"cost": 2, "requires": ["ui"], "branch": "ui",
		"tree_pos": Vector2(-3.0, 1.5), "icon": "HD",
	},
	"pause_menu": {
		"id": "pause_menu", "name": "Pause Menu",
		"desc": "Press Esc to pause and access shop / menu mid-run.",
		"cost": 2, "requires": ["hud"], "branch": "ui",
		"tree_pos": Vector2(-5.0, 2.5), "icon": "PS",
	},

	# ═══════════════════════════════════════════════════════════════════
	# JUICE BRANCH  (SW)
	# ═══════════════════════════════════════════════════════════════════
	"juice_squash": {
		"id": "juice_squash", "name": "Squash & Stretch",
		"desc": "Player squishes on jump and lands with a satisfying squash.\nFloors squish on landing too.",
		"cost": 2, "requires": ["ui"], "branch": "juice",
		"tree_pos": Vector2(-3.0, 4.5), "icon": "SS",
	},
	"hit_flash": {
		"id": "hit_flash", "name": "Hit Flash",
		"desc": "Things flash white when stomped or stunned.",
		"cost": 1, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-5.0, 4.0), "icon": "HF",
	},
	"impact_freeze": {
		"id": "impact_freeze", "name": "Impact Freeze",
		"desc": "Time briefly pauses on heavy impacts. Feels chunky.",
		"cost": 2, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-4.0, 6.0), "icon": "IF",
	},
	"motion_trail": {
		"id": "motion_trail", "name": "Motion Trail",
		"desc": "A trailing afterimage follows the running player.",
		"cost": 2, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-1.5, 6.0), "icon": "MT",
	},
	"footstep_dust": {
		"id": "footstep_dust", "name": "Footstep Dust",
		"desc": "Small puffs kick up while you sprint along the ground.",
		"cost": 1, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-6.5, 3.0), "icon": "FD",
	},
	"tear_effects": {
		"id": "tear_effects", "name": "Tear Effects",
		"desc": "Things shatter into rigid-body pieces when destroyed.",
		"cost": 3, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-6.5, 5.5), "icon": "TE",
	},
	"blood_splats": {
		"id": "blood_splats", "name": "Blood Splats",
		"desc": "Death is messy. Circular red splatter on enemy and player death.\nBlood trail direction follows impact velocity.",
		"cost": 2, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-2.5, 8.0), "icon": "BS",
	},
	"blood_marks": {
		"id": "blood_marks", "name": "Blood Stains",
		"desc": "Blood splatters leave persistent circular marks on the level floor.\nMarks persist for the whole run. Toggle blood trail in Settings.",
		"cost": 2, "requires": ["blood_splats"], "branch": "juice",
		"tree_pos": Vector2(-3.5, 10.0), "icon": "BM",
	},

	# ═══════════════════════════════════════════════════════════════════
	# CAMERA BRANCH  (S)
	# ═══════════════════════════════════════════════════════════════════
	"camera_shake": {
		"id": "camera_shake", "name": "Camera Shake",
		"desc": "Big impacts shake the camera. More game-feel.",
		"cost": 2, "requires": ["ui"], "branch": "camera",
		"tree_pos": Vector2(0.5, 3.0), "icon": "CS",
	},
	"dynamic_zoom": {
		"id": "dynamic_zoom", "name": "Dynamic Zoom",
		"desc": "Camera zooms out over wide gaps so you can see what's coming.",
		"cost": 3, "requires": ["camera_shake"], "branch": "camera",
		"tree_pos": Vector2(1.0, 5.0), "icon": "DZ",
	},

	# ═══════════════════════════════════════════════════════════════════
	# SHADERS BRANCH  (SE)
	# ═══════════════════════════════════════════════════════════════════
	"vignette": {
		"id": "vignette", "name": "Vignette",
		"desc": "Darkened corners for cinematic framing.",
		"cost": 2, "requires": ["ui_polished"], "branch": "shaders",
		"tree_pos": Vector2(3.0, 3.0), "icon": "VG",
	},
	"chromatic_aberration": {
		"id": "chromatic_aberration", "name": "Chromatic Aber.",
		"desc": "RGB channels split at the edges, exaggerated under impact.",
		"cost": 2, "requires": ["vignette"], "branch": "shaders",
		"tree_pos": Vector2(5.0, 4.5), "icon": "CA",
	},
	"color_grading": {
		"id": "color_grading", "name": "Color Grading",
		"desc": "Warm filmic tint and punchier saturation.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "shaders",
		"tree_pos": Vector2(3.5, -1.0), "icon": "CG",
	},
	"crt_filter": {
		"id": "crt_filter", "name": "CRT Filter",
		"desc": "Scanlines and screen curvature.",
		"cost": 3, "requires": ["chromatic_aberration"], "branch": "shaders",
		"tree_pos": Vector2(7.0, 5.5), "icon": "CR",
	},
	"wobble_shader": {
		"id": "wobble_shader", "name": "Air Warp",
		"desc": "The screen warps as the player falls — intensity scales with vertical speed.",
		"cost": 3, "requires": ["crt_filter"], "branch": "shaders",
		"tree_pos": Vector2(6.5, 7.5), "icon": "AW",
	},

	# ═══════════════════════════════════════════════════════════════════
	# MOVES BRANCH  (E)
	# ═══════════════════════════════════════════════════════════════════
	"sprint": {
		"id": "sprint", "name": "Sprint",
		"desc": "Higher top speed when auto-running.",
		"cost": 2, "requires": ["ui"], "branch": "moves",
		"tree_pos": Vector2(2.5, 0.5), "icon": "SP",
	},
	"double_jump": {
		"id": "double_jump", "name": "Double Jump",
		"desc": "Press jump again in mid-air to leap a second time.",
		"cost": 3, "requires": ["sprint"], "branch": "moves",
		"tree_pos": Vector2(4.5, 0.0), "icon": "DJ",
	},
	"wall_jump": {
		"id": "wall_jump", "name": "Wall Jump",
		"desc": "Jump again off walls during a slide.",
		"cost": 3, "requires": ["double_jump"], "branch": "moves",
		"tree_pos": Vector2(6.5, -0.5), "icon": "WJ",
	},

	# ═══════════════════════════════════════════════════════════════════
	# GRAPHICS BRANCH  (NE)
	# ═══════════════════════════════════════════════════════════════════
	"drawn_floors": {
		"id": "drawn_floors", "name": "Drawn Floors",
		"desc": "Replaces primitive blocks with hand-drawn wavy yellow-green platforms.",
		"cost": 2, "requires": ["ui"], "branch": "graphics",
		"tree_pos": Vector2(2.0, -2.5), "icon": "DF",
	},
	"foliage": {
		"id": "foliage", "name": "Foliage",
		"desc": "Little tufts of grass and flowers along the floor edge.\nOnly appears on grounded platforms, not floating ones.",
		"cost": 1, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(0.5, -4.0), "icon": "FO",
	},
	"palette_switcher": {
		"id": "palette_switcher", "name": "Palette Switcher",
		"desc": "Unlocks colour palette options in Settings.\nChoose from Default, Warm, Cool, Night, and Neon themes.",
		"cost": 3, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(2.5, -4.5), "icon": "PA",
	},
	"particles": {
		"id": "particles", "name": "Particles",
		"desc": "Dust on landing, smoke on death, sparks on stomp.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(4.5, -3.5), "icon": "PT",
	},
	"player_sprite": {
		"id": "player_sprite", "name": "Player Sprite",
		"desc": "Replaces the player rectangle with proper character art.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(5.5, -2.0), "icon": "PX",
	},
	"sprite_animations": {
		"id": "sprite_animations", "name": "Sprite Anims",
		"desc": "Idle, run, jump and hurt animations play for the player.",
		"cost": 3, "requires": ["player_sprite"], "branch": "graphics",
		"tree_pos": Vector2(7.0, -2.5), "icon": "SA",
	},
	"outline": {
		"id": "outline", "name": "Sprite Outline",
		"desc": "Dark ink outline around the player sprite.",
		"cost": 2, "requires": ["player_sprite"], "branch": "shaders",
		"tree_pos": Vector2(8.0, -4.5), "icon": "OL",
	},
	"parallax": {
		"id": "parallax", "name": "Parallax Backdrop",
		"desc": "Multi-layer scrolling background hills.",
		"cost": 3, "requires": ["drawn_floors"], "branch": "graphics",
		"tree_pos": Vector2(1.0, -6.0), "icon": "PB",
	},
	"clouds": {
		"id": "clouds", "name": "Clouds",
		"desc": "Soft clouds drift across the sky.",
		"cost": 2, "requires": ["parallax"], "branch": "graphics",
		"tree_pos": Vector2(-0.5, -7.5), "icon": "CL",
	},
	"sky_color": {
		"id": "sky_color", "name": "Sky Colours",
		"desc": "Unlocks sky colour options in Settings.\nChoose from Default, Sunset, Night, Dawn, and Overcast skies.",
		"cost": 2, "requires": ["parallax"], "branch": "graphics",
		"tree_pos": Vector2(2.5, -7.5), "icon": "SK",
	},

	# ═══════════════════════════════════════════════════════════════════
	# ENEMIES BRANCH  (N)
	# ═══════════════════════════════════════════════════════════════════
	"enemies_basic": {
		"id": "enemies_basic", "name": "Basic Enemies",
		"desc": "Frogs and kobolds start appearing in levels.",
		"cost": 2, "requires": ["ui"], "branch": "enemies",
		"tree_pos": Vector2(-1.5, -3.5), "icon": "BE",
	},
	"enemy_sprites": {
		"id": "enemy_sprites", "name": "Enemy Sprites",
		"desc": "Enemies, spikes and smashers get their proper sprite art.",
		"cost": 2, "requires": ["enemies_basic"], "branch": "enemies",
		"tree_pos": Vector2(-3.5, -4.5), "icon": "ES",
	},
	"enemies_more": {
		"id": "enemies_more", "name": "More Enemies",
		"desc": "Bats and big frogs join the party.",
		"cost": 3, "requires": ["enemies_basic"], "branch": "enemies",
		"tree_pos": Vector2(-2.0, -5.5), "icon": "ME",
	},
	"enemies_advanced": {
		"id": "enemies_advanced", "name": "Adv. Enemies",
		"desc": "Bombs, shooters, drills and jumpers.",
		"cost": 4, "requires": ["enemies_more"], "branch": "enemies",
		"tree_pos": Vector2(-2.5, -7.5), "icon": "AE",
	},
	"smashers": {
		"id": "smashers", "name": "Smashers",
		"desc": "Ceiling hammers that drop when you walk under them.",
		"cost": 3, "requires": ["enemies_more"], "branch": "enemies",
		"tree_pos": Vector2(-4.5, -6.5), "icon": "SM",
	},

	# ═══════════════════════════════════════════════════════════════════
	# LEVEL BRANCH  (far NE)
	# ═══════════════════════════════════════════════════════════════════
	"procgen": {
		"id": "procgen", "name": "Full Procedural",
		"desc": "Unlocks the full library of level templates: stairs, elevated platforms, combos.\nWithout this you only run on flat ground.",
		"cost": 4, "requires": ["ui"], "branch": "level",
		"tree_pos": Vector2(7.5, -6.0), "icon": "PG",
	},
	"coins": {
		"id": "coins", "name": "Coins",
		"desc": "Golden coins appear in levels. Collect them for bonus tokens.",
		"cost": 3, "requires": ["procgen"], "branch": "level",
		"tree_pos": Vector2(9.0, -7.0), "icon": "CO",
	},
	"level_library": {
		"id": "level_library", "name": "Level Library",
		"desc": "Each run's seed is saved so you can replay favourites.\nUnlocks the Level Library in the main menu.\nFavourite levels are never evicted. Best distances are tracked per seed.",
		"cost": 5, "requires": ["coins"], "branch": "level",
		"tree_pos": Vector2(10.5, -8.5), "icon": "LL",
	},
	"stats_menu": {
		"id": "stats_menu", "name": "Stats Menu",
		"desc": "Unlocks the Stats screen — playtime, jumps, longest run, longest combo, deaths, and more.",
		"cost": 2, "requires": ["ui"], "branch": "ui",
		"tree_pos": Vector2(-2.0, 3.5), "icon": "ST",
	},
	"fast_mode": {
		"id": "fast_mode", "name": "Fast Mode",
		"desc": "Unlocks a toggle in Settings: run faster and earn more points per tile.",
		"cost": 3, "requires": ["sprint"], "branch": "moves",
		"tree_pos": Vector2(4.0, 2.0), "icon": "FM",
	},
	"font_select": {
		"id": "font_select", "name": "Font Select",
		"desc": "Adds a font picker in Settings — cycles through all fonts in assets/fonts.",
		"cost": 2, "requires": ["ui"], "branch": "ui",
		"tree_pos": Vector2(-1.5, -2.0), "icon": "FT",
	},
	"sprite_explosion": {
		"id": "sprite_explosion", "name": "Sprite Explosions",
		"desc": "Bombs use a frame-animation explosion instead of a particle poof.",
		"cost": 2, "requires": ["enemies_advanced"], "branch": "enemies",
		"tree_pos": Vector2(-1.5, -9.0), "icon": "SX",
	},
	"daily_level": {
		"id": "daily_level", "name": "Daily Level",
		"desc": "Unlocks the Daily Level — one seed per calendar day, shared by everyone.",
		"cost": 4, "requires": ["level_library"], "branch": "level",
		"tree_pos": Vector2(11.5, -10.0), "icon": "DL",
	},
	"home_polish": {
		"id": "home_polish", "name": "Nicer Home",
		"desc": "Redesigns the main menu with polished layout and animations.",
		"cost": 3, "requires": ["main_menu_extras"], "branch": "ui",
		"tree_pos": Vector2(-7.0, -3.5), "icon": "HP",
	},
	"adaptive_sky": {
		"id": "adaptive_sky", "name": "Adaptive Sky",
		"desc": "Sky colour and palette shift over the course of a run.",
		"cost": 3, "requires": ["sky_color"], "branch": "graphics",
		"tree_pos": Vector2(2.5, -9.0), "icon": "AS",
	},

	# ═══════════════════════════════════════════════════════════════════
	# COMBO BRANCH (juice, deep SW)
	# ═══════════════════════════════════════════════════════════════════
	"combo_system": {
		"id": "combo_system", "name": "Combo System",
		"desc": "Chained air-time & stomp combos build a token multiplier.\nA big xN pops on-screen while the streak is alive.",
		"cost": 4, "requires": ["juice_squash"], "branch": "juice",
		"tree_pos": Vector2(-8.5, 4.5), "icon": "CM",
	},
	"combo_bounce": {
		"id": "combo_bounce", "name": "Bouncy Combo Text",
		"desc": "Combo popups spring in with a bouncy scale instead of a plain fade.",
		"cost": 2, "requires": ["combo_system"], "branch": "juice",
		"tree_pos": Vector2(-10.0, 5.5), "icon": "BT",
	},
	"skill_tree_polish": {
		"id": "skill_tree_polish", "name": "Skill Tree Polish",
		"desc": "Curved bezier connections, animated pulse on active paths.",
		"cost": 2, "requires": ["main_menu_extras"], "branch": "ui",
		"tree_pos": Vector2(-7.0, -1.5), "icon": "TP",
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
	if not SKILLS.has(skill_id): return false
	return Global.tokens >= compute_cost(skill_id)

func prereqs_met(skill_id: String) -> bool:
	if Global.debug_toggles.get("unlock_all", false): return true
	var d = SKILLS.get(skill_id, null)
	if d == null: return false
	for r in d.get("requires", []):
		# Check raw purchase state (not the override toggle) so a disabled skill
		# still counts as a prerequisite for its children.
		if not Global.unlocked.get(get_feature_key(r), false):
			return false
	return true

func is_purchased(skill_id: String) -> bool:
	return Global.unlocked.get(get_feature_key(skill_id), false)

## Attempt to purchase. Returns true on success.
func purchase(skill_id: String) -> bool:
	if is_purchased(skill_id): return false
	if not prereqs_met(skill_id): return false
	if not SKILLS.has(skill_id): return false
	var cost := compute_cost(skill_id)
	if not Global.spend(cost): return false
	Global.grant(get_feature_key(skill_id))
	_on_purchase_hook(skill_id)
	return true

## Post-purchase side effects that shouldn't live in Global.grant (which is
## used for admin/debug flows too). Add per-skill hooks here.
func _on_purchase_hook(skill_id: String) -> void:
	match skill_id:
		"font_select":
			var fonts := list_font_files()
			if fonts.size() > 0:
				var pick: String = fonts[randi() % fonts.size()].get_file()
				Global.settings_cfg["font_choice"] = pick
				Global.save_state()

## Shared font-file enumeration used by both purchase-hook and Settings.
static func list_font_files() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://assets/fonts")
	if dir == null: return out
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "": break
		if f.begins_with("."): continue
		var lower := f.to_lower()
		if lower.ends_with(".ttf") or lower.ends_with(".otf"):
			out.append("res://assets/fonts/%s" % f)
	dir.list_dir_end()
	out.sort()
	return out
