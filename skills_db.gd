extends Node

## Data-only skills database.
## Adding a new skill = appending one Dictionary entry. UI + gating discover it.
##
## Required fields:
##   id, name, desc, cost, requires, branch
## Optional:
##   feature   – override gating key if it differs from id
##   icon      – single glyph drawn on the node
## Positions on the skill tree are computed dynamically — see LAYOUT below.

const ROOT_ID := "ui"

# ─── COST FORMULA ─────────────────────────────────────────────────────────
# Cost is looked up by shortest-path depth from ROOT_ID.
# Edit PATH_COSTS to reshape the whole economy in one line.
# Depths beyond the table use the last value * PATH_TAIL_MULT^extra.
# A skill dict may set "cost_override" to pin a bespoke price.
const PATH_COSTS := [1, 3, 9, 27, 81, 243]
const PATH_TAIL_MULT := 3.0
const COST_MAX  := 999

var _cost_cache: Dictionary = {}
var _depth_cache: Dictionary = {}

# ─── LAYOUT ───────────────────────────────────────────────────────────────
# Positions are computed radially: each branch owns an angular sector,
# depth from root maps to ring radius, and siblings split their parent's
# angular slice proportional to their subtree leaf count. No hardcoded
# coordinates in the SKILLS dict.
const LAYOUT_BASE_RADIUS := 2.4
const LAYOUT_RING_STEP := 2.1
const LAYOUT_MIN_ARC := 0.24   # radians; guards against ultra-thin slices

# Force-directed relaxation (Fruchterman-Reingold) settles the seeded radial
# layout so nodes are evenly spaced and cross-branch edges don't crush the
# graph. Runs once on first tree open, then cached.
# Tightened: shorter ideal spring + stronger branch pull keeps branches
# radiating out cleanly instead of curling into each other.
const FR_ITERATIONS := 260
const FR_IDEAL_LENGTH := 1.9
const FR_INITIAL_TEMP := 2.0
const FR_COOL := 0.985
const FR_MIN_TEMP := 0.02
const FR_BRANCH_PULL := 0.10   # stronger per-iter pull toward each node's branch ray
const BRANCH_ANGLES := {
	"moves":    0.0,
	"level":    PI / 6.0,
	"graphics": PI / 3.0,
	"enemies":  PI / 2.0,
	"ui":       PI,
	"juice":    PI * 1.25,
	"camera":   PI * 1.5,
	"shaders":  PI * 1.75,
}
const BRANCH_SECTOR_HALF := PI / 8.0  # 22.5° half-width per branch

var _layout_positions: Dictionary = {}
var _layout_dirty: bool = true
var _tree_children_cache: Dictionary = {}

func get_tree_pos(sid: String) -> Vector2:
	if _layout_dirty:
		_compute_layout()
	return _layout_positions.get(sid, Vector2.ZERO)

func _tree_parent(sid: String) -> String:
	if sid == ROOT_ID: return ""
	var d = SKILLS.get(sid, null)
	if d == null: return ""
	var reqs: Array = d.get("requires", [])
	if reqs.is_empty(): return ""
	return String(reqs[0])

func _tree_children(sid: String) -> Array:
	if _tree_children_cache.has(sid):
		return _tree_children_cache[sid]
	var out: Array = []
	for other in SKILLS.keys():
		if other == sid: continue
		if _tree_parent(other) == sid:
			out.append(other)
	_tree_children_cache[sid] = out
	return out

func _leaf_count(sid: String, cache: Dictionary) -> int:
	if cache.has(sid): return int(cache[sid])
	var kids := _tree_children(sid)
	var n: int
	if kids.is_empty():
		n = 1
	else:
		n = 0
		for k in kids:
			n += _leaf_count(k, cache)
	cache[sid] = n
	return n

func _compute_layout() -> void:
	_layout_positions.clear()
	_tree_children_cache.clear()
	_seed_radial()
	_relax_forces()
	_layout_dirty = false

func _seed_radial() -> void:
	_layout_positions[ROOT_ID] = Vector2.ZERO
	var leaves := {}
	_leaf_count(ROOT_ID, leaves)

	# Group root's direct children by branch so each branch owns a sector.
	var roots := _tree_children(ROOT_ID)
	var by_branch: Dictionary = {}
	for r in roots:
		var b: String = SKILLS[r].get("branch", "ui")
		if not by_branch.has(b): by_branch[b] = []
		by_branch[b].append(r)

	for b in by_branch.keys():
		var center: float = float(BRANCH_ANGLES.get(b, 0.0))
		var half: float = BRANCH_SECTOR_HALF
		var siblings: Array = by_branch[b]
		var total: int = 0
		for s in siblings:
			total += _leaf_count(s, leaves)
		var cur: float = center - half
		for s in siblings:
			var lc: int = _leaf_count(s, leaves)
			var w: float = 2.0 * half * float(lc) / float(max(1, total))
			_place_subtree(s, cur + w * 0.5, w * 0.5, 1, leaves)
			cur += w

func _all_edges() -> Array:
	# Every `requires` link becomes a spring, including cross-branch ones.
	var out: Array = []
	for sid in SKILLS.keys():
		var reqs: Array = SKILLS[sid].get("requires", [])
		for r in reqs:
			if SKILLS.has(r):
				out.append([String(sid), String(r)])
	return out

func _relax_forces() -> void:
	var edges := _all_edges()
	var ids: Array = SKILLS.keys()
	var disp: Dictionary = {}
	var k := FR_IDEAL_LENGTH
	var k2 := k * k
	var temp := FR_INITIAL_TEMP
	for _iter in range(FR_ITERATIONS):
		for id in ids:
			disp[id] = Vector2.ZERO
		# Repulsion — every pair pushes apart.
		var n := ids.size()
		for i in range(n):
			var a: String = ids[i]
			var pa: Vector2 = _layout_positions[a]
			for j in range(i + 1, n):
				var b: String = ids[j]
				var pb: Vector2 = _layout_positions[b]
				var d: Vector2 = pa - pb
				var dist: float = max(0.05, d.length())
				var f: float = k2 / dist
				var push: Vector2 = (d / dist) * f
				disp[a] += push
				disp[b] -= push
		# Attraction along edges — springs.
		for e in edges:
			var u: String = e[0]
			var v: String = e[1]
			var d2: Vector2 = _layout_positions[u] - _layout_positions[v]
			var dist2: float = max(0.05, d2.length())
			var f2: float = (dist2 * dist2) / k
			var pull: Vector2 = (d2 / dist2) * f2
			disp[u] -= pull
			disp[v] += pull
		# Weak anchor pulling each node toward its branch ray at its own depth,
		# so branches stay pointed outward instead of curling into a blob.
		for sid in ids:
			if sid == ROOT_ID: continue
			var branch: String = SKILLS[sid].get("branch", "ui")
			var ang: float = float(BRANCH_ANGLES.get(branch, 0.0))
			var depth: int = depth_from_root(sid)
			var target_r: float = LAYOUT_BASE_RADIUS + LAYOUT_RING_STEP * float(depth - 1)
			var target: Vector2 = Vector2(cos(ang), -sin(ang)) * target_r
			disp[sid] += (target - _layout_positions[sid]) * FR_BRANCH_PULL
		# Apply, clamped to temperature. Root stays pinned at origin.
		for sid in ids:
			if sid == ROOT_ID:
				_layout_positions[sid] = Vector2.ZERO
				continue
			var d3: Vector2 = disp[sid]
			var dl: float = d3.length()
			if dl > temp:
				d3 = d3 * (temp / dl)
			_layout_positions[sid] += d3
		temp = max(FR_MIN_TEMP, temp * FR_COOL)

func _place_subtree(sid: String, angle: float, half_width: float, depth: int, leaves: Dictionary) -> void:
	var r: float = LAYOUT_BASE_RADIUS + LAYOUT_RING_STEP * float(depth - 1)
	_layout_positions[sid] = Vector2(cos(angle) * r, -sin(angle) * r)
	var kids := _tree_children(sid)
	if kids.is_empty(): return
	# Widen the sector for branchy subtrees so children don't crowd the parent
	# angle. Falls back to the parent's own slice for single-child chains.
	var desired: float = max(half_width, min(PI / 5.0, LAYOUT_MIN_ARC * float(kids.size())))
	var total: int = 0
	for k in kids:
		total += _leaf_count(k, leaves)
	var cur: float = angle - desired
	for k in kids:
		var lc: int = _leaf_count(k, leaves)
		var w: float = 2.0 * desired * float(lc) / float(max(1, total))
		_place_subtree(k, cur + w * 0.5, w * 0.5, depth + 1, leaves)
		cur += w

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
		"icon": "UI",
		"priority": 100, "non_toggleable": true,
	},

	# ═══════════════════════════════════════════════════════════════════
	# UI BRANCH  (left / NW)
	# ═══════════════════════════════════════════════════════════════════
	"ui_polished": {
		"id": "ui_polished", "name": "Polished UI",
		"desc": "Rounded panels, smooth hover animations, custom colours.",
		"cost": 4, "requires": ["ui"], "branch": "ui",
		"icon": "PL",
		"priority": 70,
	},
	"main_menu_extras": {
		"id": "main_menu_extras", "name": "Menu Polish",
		"desc": "Animated title intro, button SFX hooks.",
		"cost": 3, "requires": ["ui_polished"], "branch": "ui",
		"icon": "MP",
		"priority": 55,
	},
	"hud": {
		"id": "hud", "name": "In-Game HUD",
		"desc": "Distance and token counters appear during play.",
		"cost": 2, "requires": ["ui"], "branch": "ui",
		"icon": "HD",
		"priority": 95, "non_toggleable": true,
	},
	"pause_menu": {
		"id": "pause_menu", "name": "Pause Menu",
		"desc": "Press Esc to pause and access shop / menu mid-run.",
		"cost": 2, "requires": ["hud"], "branch": "ui",
		"icon": "PS",
		"priority": 80,
	},

	# ═══════════════════════════════════════════════════════════════════
	# JUICE BRANCH  (SW)
	# ═══════════════════════════════════════════════════════════════════
	"juice_squash": {
		"id": "juice_squash", "name": "Squash & Stretch",
		"desc": "Player squishes on jump and lands with a satisfying squash.\nFloors squish on landing too.",
		"cost": 2, "requires": ["ui"], "branch": "juice",
		"icon": "SS",
		"priority": 85,
	},
	"hit_flash": {
		"id": "hit_flash", "name": "Hit Flash",
		"desc": "Things flash white when stomped or stunned.",
		"cost": 1, "requires": ["juice_squash"], "branch": "juice",
		"icon": "HF",
		"priority": 72,
	},
	"impact_freeze": {
		"id": "impact_freeze", "name": "Impact Freeze",
		"desc": "Time briefly pauses on heavy impacts. Feels chunky.",
		"cost": 2, "requires": ["juice_squash", "camera_shake"], "branch": "juice",
		"icon": "IF",
		"priority": 60,
	},
	"motion_trail": {
		"id": "motion_trail", "name": "Motion Trail",
		"desc": "A trailing afterimage follows the running player.",
		"cost": 2, "requires": ["juice_squash", "sprint"], "branch": "juice",
		"icon": "MT",
		"priority": 45,
	},
	"footstep_dust": {
		"id": "footstep_dust", "name": "Footstep Dust",
		"desc": "Small puffs kick up while you sprint along the ground.",
		"cost": 1, "requires": ["juice_squash"], "branch": "juice",
		"icon": "FD",
		"priority": 42,
	},
	"tear_effects": {
		"id": "tear_effects", "name": "Tear Effects",
		"desc": "Things shatter into rigid-body pieces when destroyed.",
		"cost": 3, "requires": ["juice_squash"], "branch": "juice",
		"icon": "TE",
		"priority": 40,
	},
	"blood_splats": {
		"id": "blood_splats", "name": "Blood Splats",
		"desc": "Death is messy. Circular red splatter on enemy and player death.\nBlood trail direction follows impact velocity.",
		"cost": 2, "requires": ["juice_squash"], "branch": "juice",
		"icon": "BS",
		"priority": 50,
	},
	"blood_marks": {
		"id": "blood_marks", "name": "Blood Stains",
		"desc": "Blood splatters leave persistent circular marks on the level floor.\nMarks persist for the whole run. Toggle blood trail in Settings.",
		"cost": 2, "requires": ["blood_splats"], "branch": "juice",
		"icon": "BM",
		"priority": 35,
	},

	# ═══════════════════════════════════════════════════════════════════
	# CAMERA BRANCH  (S)
	# ═══════════════════════════════════════════════════════════════════
	"camera_shake": {
		"id": "camera_shake", "name": "Camera Shake",
		"desc": "Big impacts shake the camera. More game-feel.",
		"cost": 2, "requires": ["ui"], "branch": "camera",
		"icon": "CS",
		"priority": 78,
	},
	"dynamic_zoom": {
		"id": "dynamic_zoom", "name": "Dynamic Zoom",
		"desc": "Camera zooms out over wide gaps so you can see what's coming.",
		"cost": 3, "requires": ["camera_shake", "parallax"], "branch": "camera",
		"icon": "DZ",
		"priority": 55,
	},

	# ═══════════════════════════════════════════════════════════════════
	# SHADERS BRANCH  (SE)
	# ═══════════════════════════════════════════════════════════════════
	"vignette": {
		"id": "vignette", "name": "Vignette",
		"desc": "Darkened corners for cinematic framing.",
		"cost": 2, "requires": ["ui_polished"], "branch": "shaders",
		"icon": "VG",
		"priority": 48,
	},
	"chromatic_aberration": {
		"id": "chromatic_aberration", "name": "Chromatic Aber.",
		"desc": "RGB channels split at the edges, exaggerated under impact.",
		"cost": 2, "requires": ["vignette"], "branch": "shaders",
		"icon": "CA",
		"priority": 38,
	},
	"color_grading": {
		"id": "color_grading", "name": "Color Grading",
		"desc": "Warm filmic tint and punchier saturation.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "shaders",
		"icon": "CG",
		"priority": 44,
	},
	"crt_filter": {
		"id": "crt_filter", "name": "CRT Filter",
		"desc": "Scanlines and screen curvature.",
		"cost": 3, "requires": ["chromatic_aberration"], "branch": "shaders",
		"icon": "CR",
		"priority": 30,
	},
	"wobble_shader": {
		"id": "wobble_shader", "name": "Air Warp",
		"desc": "The screen warps as the player falls — intensity scales with vertical speed.",
		"cost": 3, "requires": ["crt_filter"], "branch": "shaders",
		"icon": "AW",
		"priority": 28,
	},

	# ═══════════════════════════════════════════════════════════════════
	# MOVES BRANCH  (E)
	# ═══════════════════════════════════════════════════════════════════
	"sprint": {
		"id": "sprint", "name": "Sprint",
		"desc": "Higher top speed when auto-running.",
		"cost": 2, "requires": ["ui"], "branch": "moves",
		"icon": "SP",
		"priority": 82,
	},
	"double_jump": {
		"id": "double_jump", "name": "Double Jump",
		"desc": "Press jump again in mid-air to leap a second time.",
		"cost": 3, "requires": ["sprint"], "branch": "moves",
		"icon": "DJ",
		"priority": 75,
	},
	"wall_jump": {
		"id": "wall_jump", "name": "Wall Jump",
		"desc": "Jump again off walls during a slide.",
		"cost": 3, "requires": ["double_jump"], "branch": "moves",
		"icon": "WJ",
		"priority": 60,
	},

	# ═══════════════════════════════════════════════════════════════════
	# GRAPHICS BRANCH  (NE)
	# ═══════════════════════════════════════════════════════════════════
	"drawn_floors": {
		"id": "drawn_floors", "name": "Drawn Floors",
		"desc": "Replaces primitive blocks with hand-drawn wavy yellow-green platforms.",
		"cost": 2, "requires": ["ui"], "branch": "graphics",
		"icon": "DF",
		"priority": 84,
	},
	"foliage": {
		"id": "foliage", "name": "Foliage",
		"desc": "Little tufts of grass and flowers along the floor edge.\nOnly appears on grounded platforms, not floating ones.",
		"cost": 1, "requires": ["drawn_floors"], "branch": "graphics",
		"icon": "FO",
		"priority": 40,
	},
	"palette_switcher": {
		"id": "palette_switcher", "name": "Palette Switcher",
		"desc": "Unlocks colour palette options in Settings.\nChoose from Default, Warm, Cool, Night, and Neon themes.",
		"cost": 3, "requires": ["drawn_floors"], "branch": "graphics",
		"icon": "PA",
		"priority": 38,
	},
	"particles": {
		"id": "particles", "name": "Particles",
		"desc": "Dust on landing, smoke on death, sparks on stomp.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "graphics",
		"icon": "PT",
		"priority": 62,
	},
	"player_sprite": {
		"id": "player_sprite", "name": "Player Sprite",
		"desc": "Replaces the player rectangle with proper character art.",
		"cost": 2, "requires": ["drawn_floors"], "branch": "graphics",
		"icon": "PX",
		"priority": 68,
	},
	"sprite_animations": {
		"id": "sprite_animations", "name": "Sprite Anims",
		"desc": "Idle, run, jump and hurt animations play for the player.",
		"cost": 3, "requires": ["player_sprite"], "branch": "graphics",
		"icon": "SA",
		"priority": 58,
	},
	"outline": {
		"id": "outline", "name": "Sprite Outline",
		"desc": "Dark ink outline around the player sprite.",
		"cost": 2, "requires": ["player_sprite"], "branch": "shaders",
		"icon": "OL",
		"priority": 32,
	},
	"parallax": {
		"id": "parallax", "name": "Parallax Backdrop",
		"desc": "Multi-layer scrolling background hills.",
		"cost": 3, "requires": ["drawn_floors"], "branch": "graphics",
		"icon": "PB",
		"priority": 65,
	},
	"clouds": {
		"id": "clouds", "name": "Clouds",
		"desc": "Soft clouds drift across the sky.",
		"cost": 2, "requires": ["parallax"], "branch": "graphics",
		"icon": "CL",
		"priority": 34,
	},
	"sky_color": {
		"id": "sky_color", "name": "Sky Colours",
		"desc": "Unlocks sky colour options in Settings.\nChoose from Default, Sunset, Night, Dawn, and Overcast skies.",
		"cost": 2, "requires": ["parallax"], "branch": "graphics",
		"icon": "SK",
		"priority": 36,
	},

	# ═══════════════════════════════════════════════════════════════════
	# ENEMIES BRANCH  (N)
	# ═══════════════════════════════════════════════════════════════════
	"enemies_basic": {
		"id": "enemies_basic", "name": "Basic Enemies",
		"desc": "Frogs and kobolds start appearing in levels.",
		"cost": 2, "requires": ["ui"], "branch": "enemies",
		"icon": "BE",
		"priority": 90, "non_toggleable": true,
	},
	"enemy_sprites": {
		"id": "enemy_sprites", "name": "Enemy Sprites",
		"desc": "Enemies, spikes and smashers get their proper sprite art.",
		"cost": 2, "requires": ["enemies_basic"], "branch": "enemies",
		"icon": "ES",
		"priority": 60,
	},
	"enemies_more": {
		"id": "enemies_more", "name": "More Enemies",
		"desc": "Bats and big frogs join the party.",
		"cost": 3, "requires": ["enemies_basic"], "branch": "enemies",
		"icon": "ME",
		"priority": 66,
	},
	"enemies_advanced": {
		"id": "enemies_advanced", "name": "Adv. Enemies",
		"desc": "Bombs, shooters, drills and jumpers.",
		"cost": 4, "requires": ["enemies_more"], "branch": "enemies",
		"icon": "AE",
		"priority": 52,
	},
	"smashers": {
		"id": "smashers", "name": "Smashers",
		"desc": "Ceiling hammers that drop when you walk under them.",
		"cost": 3, "requires": ["enemies_more"], "branch": "enemies",
		"icon": "SM",
		"priority": 48,
	},

	# ═══════════════════════════════════════════════════════════════════
	# LEVEL BRANCH  (far NE)
	# ═══════════════════════════════════════════════════════════════════
	"procgen": {
		"id": "procgen", "name": "Full Procedural",
		"desc": "Unlocks the full library of level templates: stairs, elevated platforms, combos.\nWithout this you only run on flat ground.",
		"cost": 4, "requires": ["ui"], "branch": "level",
		"icon": "PG",
		"priority": 92, "non_toggleable": true,
	},
	"coins": {
		"id": "coins", "name": "Coins",
		"desc": "Golden coins appear in levels. Collect them for bonus tokens.",
		"cost": 3, "requires": ["procgen"], "branch": "level",
		"icon": "CO",
		"priority": 78,
	},
	"level_library": {
		"id": "level_library", "name": "Level Library",
		"desc": "Each run's seed is saved so you can replay favourites.\nUnlocks the Level Library in the main menu.\nFavourite levels are never evicted. Best distances are tracked per seed.",
		"cost": 5, "requires": ["coins"], "branch": "level",
		"icon": "LL",
		"priority": 62,
	},
	"stats_menu": {
		"id": "stats_menu", "name": "Stats Menu",
		"desc": "Unlocks the Stats screen — playtime, jumps, longest run, longest combo, deaths, and more.",
		"cost": 2, "requires": ["ui"], "branch": "ui",
		"icon": "ST",
		"priority": 55,
	},
	"fast_mode": {
		"id": "fast_mode", "name": "Fast Mode",
		"desc": "Unlocks a toggle in Settings: run faster and earn more points per tile.",
		"cost": 3, "requires": ["sprint"], "branch": "moves",
		"icon": "FM",
		"priority": 58,
	},
	"font_select": {
		"id": "font_select", "name": "Font Select",
		"desc": "Adds a font picker in Settings — cycles through all fonts in assets/fonts.",
		"cost": 2, "requires": ["ui"], "branch": "ui",
		"icon": "FT",
		"priority": 30,
	},
	"sprite_explosion": {
		"id": "sprite_explosion", "name": "Sprite Explosions",
		"desc": "Bombs use a frame-animation explosion instead of a particle poof.",
		"cost": 2, "requires": ["enemies_advanced", "particles"], "branch": "enemies",
		"icon": "SX",
		"priority": 30,
	},
	"daily_level": {
		"id": "daily_level", "name": "Daily Level",
		"desc": "Unlocks the Daily Level — one seed per calendar day, shared by everyone.",
		"cost": 4, "requires": ["level_library"], "branch": "level",
		"icon": "DL",
		"priority": 46,
	},
	"home_polish": {
		"id": "home_polish", "name": "Nicer Home",
		"desc": "Redesigns the main menu with polished layout and animations.",
		"cost": 3, "requires": ["main_menu_extras"], "branch": "ui",
		"icon": "HP",
		"priority": 32,
	},
	"adaptive_sky": {
		"id": "adaptive_sky", "name": "Adaptive Sky",
		"desc": "Sky colour and palette shift over the course of a run.",
		"cost": 3, "requires": ["sky_color"], "branch": "graphics",
		"icon": "AS",
		"priority": 30,
	},

	# ═══════════════════════════════════════════════════════════════════
	# COMBO BRANCH (juice, deep SW)
	# ═══════════════════════════════════════════════════════════════════
	"combo_system": {
		"id": "combo_system", "name": "Combo System",
		"desc": "Chained air-time & stomp combos build a token multiplier.\nA big xN pops on-screen while the streak is alive.",
		"cost": 4, "requires": ["juice_squash"], "branch": "juice",
		"icon": "CM",
		"priority": 70,
	},
	"combo_bounce": {
		"id": "combo_bounce", "name": "Bouncy Combo Text",
		"desc": "Combo popups spring in with a bouncy scale instead of a plain fade.",
		"cost": 2, "requires": ["combo_system", "main_menu_extras"], "branch": "juice",
		"icon": "BT",
		"priority": 28,
	},
	"skill_tree_polish": {
		"id": "skill_tree_polish", "name": "Skill Tree Polish",
		"desc": "Curved bezier connections, animated pulse on active paths.",
		"cost": 2, "requires": ["main_menu_extras"], "branch": "ui",
		"icon": "TP",
		"priority": 34,
	},
	"fog_cover": {
		"id": "fog_cover", "name": "Fog Cover",
		"desc": "A dark fog swallows the lower part of the screen — floors below fade into blackness.",
		"cost": 3, "requires": ["vignette"], "branch": "shaders",
		"icon": "FG",
		"priority": 30,
	},
	"near_miss_slowmo": {
		"id": "near_miss_slowmo", "name": "Near-Miss Slow-Mo",
		"desc": "Brushing past an enemy triggers a brief cinematic slow-motion.\nFires 30% of the time.",
		"cost": 3, "requires": ["impact_freeze"], "branch": "camera",
		"icon": "NM",
		"priority": 42,
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

## Recommendation priority: higher = surfaced first. Defaults to 50.
func get_priority(skill_id: String) -> int:
	var d = SKILLS.get(skill_id, null)
	if d == null: return 0
	return int(d.get("priority", 50))

## Load-bearing skills that must stay on once bought (basic UI, HUD, enemies,
## procgen). Users can't disable them from the shop toggle.
func is_toggleable(skill_id: String) -> bool:
	var d = SKILLS.get(skill_id, null)
	if d == null: return true
	return not bool(d.get("non_toggleable", false))

## Purchasable RIGHT NOW: not owned, prereqs met, affordable.
func purchasable_now(skill_id: String) -> bool:
	if is_purchased(skill_id): return false
	if not prereqs_met(skill_id): return false
	return can_afford(skill_id)

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
