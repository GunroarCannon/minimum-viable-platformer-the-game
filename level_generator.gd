extends Node2D

static var current_seed: int = 0

@export var level_width_blocks: int = 40
@export var tile_scene: PackedScene = preload("res://tile_object.tscn")
@export var tile_strip_scene: PackedScene = preload("res://tile_strip.tscn")
@export var player_scene: PackedScene = preload("res://player.tscn")
@export var spike_scene: PackedScene = preload("res://spike.tscn")
@export var smasher_scene: PackedScene = preload("res://smasher.tscn")
@export var ramp_scene: PackedScene = preload("res://ramp.tscn")
@export var ui_scene: PackedScene = preload("res://ui.tscn")
@export var bg_scene: PackedScene = preload("res://game_bg.tscn")
@export var hud_scene: PackedScene = preload("res://hud.tscn")
@export var pause_scene: PackedScene = preload("res://pause_menu.tscn")
@export var coin_scene: PackedScene = preload("res://coin.tscn")
@export var tile_size: Vector2 = Vector2(128, 128)

@export var frog_scene: PackedScene = preload("res://enemies/frog.tscn")
@export var big_frog_scene: PackedScene = preload("res://enemies/big_frog.tscn")
@export var bat_scene: PackedScene = preload("res://enemies/bat.tscn")
@export var bomb_scene: PackedScene = preload("res://enemies/bomb.tscn")
@export var rock_scene: PackedScene = preload("res://enemies/rock.tscn")
@export var kobold_scene: PackedScene = preload("res://enemies/kobold.tscn")
@export var shooter_scene: PackedScene = preload("res://enemies/shooter.tscn")
@export var drill_scene: PackedScene = preload("res://enemies/drill.tscn")
@export var jumper_scene: PackedScene = preload("res://enemies/jumper.tscn")

# ─── FEATURE GATES PER PATTERN CHARACTER ────────────────────────────────
# Maps an entity id (the value side of TEMPLATES' character dict) to the
# unlock feature key required for it to actually appear in-game.
const ENTITY_GATES := {
	"spike":     "",                  # always allowed
	"frog":      "enemies_basic",
	"kobold":    "enemies_basic",
	"bat":       "enemies_more",
	"big_frog":  "enemies_more",
	"bomb":      "enemies_advanced",
	"shooter":   "enemies_advanced",
	"drill":     "enemies_advanced",
	"jumper":    "enemies_advanced",
	"rock":      "enemies_advanced",
	"smasher":   "smashers",
}

const TEMPLATE_STARTER_IDX := 0

# Full template library (same as before).
var TEMPLATES: Array = [
	# 0 — safe start (always available)
	{ "pattern": ["................", "................", "################"] },

	# Flat runs
	{ "pattern": ["........", "........", "########"] },
	{ "pattern": ["............", "............", "############"] },

	# Simple pits
	{ "pattern": ["........", "........", "##aaaa##"] },
	{ "pattern": ["........", "........", "###aa###"] },
	{ "pattern": [".........", ".........", "####a####"] },

	# Spikes
	{ "pattern": ["........", "........", "..s.s.s.", "########"], "s": "spike" },
	{ "pattern": ["........", "........", "s.....s.", "########"], "s": "spike" },
	{ "pattern": ["............", "............", "s..s....s..s", "############"], "s": "spike" },

	# Spikes over pit
	{ "pattern": ["............", "............", "##s.aaaa.s##"], "s": "spike" },
	{ "pattern": ["............", "............", "##.s.aa.s.##"], "s": "spike" },

	# Stairs
	{ "pattern": ["......##", "....####", "..######", "########"] },
	{ "pattern": ["##......", "####....", "######..", "########"] },
	{ "pattern": ["....##..", "..######", "########"] },
	{ "pattern": ["..####..", "########"] },

	# Elevated platform
	{ "pattern": ["...####.", "........", "........", "########"] },
	{ "pattern": ["..####..", "........", "........", "########"] },
	{ "pattern": ["....##.....", "...........", "...........", "###########"] },

	# Smashers
	{ "pattern": ["....T.....", "..........", "..........", "..........", "##########"], "T": "smasher" },
	{ "pattern": [".T.......T...", "..............", ".............", ".............", "#############"], "T": "smasher" },
	{ "pattern": ["....T...", "........", "........", "##....##", "########"], "T": "smasher" },
	{ "pattern": ["..T.....", "........", "........", "..s.s.s.", "########"], "T": "smasher", "s": "spike" },

	# Frogs
	{ "pattern": ["........", "........", "....f...", "########"], "f": "frog" },
	{ "pattern": ["........", "........", ".f....f.", "########"], "f": "frog" },
	{ "pattern": ["........", "........", "...f....", "..####..", "........", "########"], "f": "frog" },
	{ "pattern": ["............", "............", "f....f....f.", "############"], "f": "frog" },

	# Big frog
	{ "pattern": ["........", "........", "....F...", "########"], "F": "big_frog" },
	{ "pattern": ["............", "............", "....F.......", "############"], "F": "big_frog" },

	# Bats
	{ "pattern": ["..b.....", "........", "........", "########"], "b": "bat" },
	{ "pattern": [".b....b.", "........", "........", "########"], "b": "bat" },
	{ "pattern": ["....b...", "........", "##aaaa##"], "b": "bat" },
	{ "pattern": ["...b...b...", "...........", "###.aaaa.##"], "b": "bat" },

	# Bombs
	{ "pattern": ["........", "........", "......B.", "########"], "B": "bomb" },
	{ "pattern": ["........", "........", "...B....", "########"], "B": "bomb" },
	{ "pattern": ["........", "........", "B......B", "########"], "B": "bomb" },

	# Rock springs
	{ "pattern": ["............", "............", ".....r......", "############"], "r": "rock" },
	{ "pattern": ["............", "............", ".....r......", "##aaaaaa####"], "r": "rock" },

	# Shooters
	{ "pattern": ["........", "........", "........", "...S....", "########"], "S": "shooter" },
	{ "pattern": ["........", "........", "S.......", "........", "########"], "S": "shooter" },
	{ "pattern": ["............", "............", "............", ".......S....", "############"], "S": "shooter" },

	# Kobold patrols
	{ "pattern": ["........", "........", "..k.....", ".######."], "k": "kobold" },
	{ "pattern": ["........", "........", ".k....k.", "########"], "k": "kobold" },
	{ "pattern": ["....####", "........", ".k......", "########"], "k": "kobold" },

	# Combos
	{ "pattern": ["....b...", "........", "..k.....", "########"], "b": "bat", "k": "kobold" },
	{ "pattern": ["........", "........", ".f....B.", "########"], "f": "frog", "B": "bomb" },
	{ "pattern": ["............", "............", "s.f.s...s.f.", "############"], "s": "spike", "f": "frog" },
	{ "pattern": [".b.......b..", "............", "###.aaaa.###"], "b": "bat" },
	{ "pattern": ["....b...", "........", ".k..s.k.", "########"], "b": "bat", "k": "kobold", "s": "spike" },
	{ "pattern": ["............", ".b.......b..", "............", "s...s...s...", "############"], "b": "bat", "s": "spike" },

	# Drill & jumper
	{ "pattern": ["..d.....", "........", "........", "........", "########"], "d": "drill" },
	{ "pattern": [".d.......d...", "..............", ".............", ".............", "#############"], "d": "drill" },
	{ "pattern": ["........", "........", "....j...", "########"], "j": "jumper" },
	{ "pattern": ["........", "........", ".j....j.", "########"], "j": "jumper" },
]

# Templates available BEFORE procgen is unlocked.
const PRE_PROCGEN_INDICES := [0, 1, 6, 7, 4]
# index 0 = safe start, 1/4 = flat / pit, 6/7 = spike rows

var player: Node = null
var dirt_tex = preload("res://assets/dirt_floor.png")
var top_dirt_tex = preload("res://assets/top_dirt_floor.png")

func _ready() -> void:
	# Reset the per-run distance counter so token awards stay correct.
	Global.last_run_distance = 0
	generate_level()
	setup_camera()


# ─── ENTITY SPAWNING ────────────────────────────────────────────────────

func _is_entity_allowed(entity_id: String) -> bool:
	var gate: String = ENTITY_GATES.get(entity_id, "")
	if gate == "":
		return true
	return Global.is_unlocked(gate)

func _spawn_entity(id: String, world_pos: Vector2) -> void:
	if not _is_entity_allowed(id):
		return
	var inst = null
	match id:
		"smasher":  inst = smasher_scene.instantiate()
		"frog":     inst = frog_scene.instantiate()
		"big_frog": inst = big_frog_scene.instantiate()
		"bat":      inst = bat_scene.instantiate()
		"bomb":     inst = bomb_scene.instantiate()
		"rock":     inst = rock_scene.instantiate()
		"kobold":   inst = kobold_scene.instantiate()
		"shooter":  inst = shooter_scene.instantiate()
		"drill":    inst = drill_scene.instantiate()
		"jumper":   inst = jumper_scene.instantiate()
	if inst:
		inst.position = world_pos
		add_child(inst)
		inst.add_to_group("hazards")


# ─── TILE STRIP SPAWN ───────────────────────────────────────────────────

## Spawns ONE TileStrip representing a contiguous horizontal run of N tiles.
## The strip's depth_tiles handles the "3 columns deep" we used to emit per #.
func _spawn_strip(start_world: Vector2, length_tiles: int) -> void:
	var strip = tile_strip_scene.instantiate()
	strip.tile_size = tile_size
	strip.length_tiles = length_tiles
	# strip local 0,0 = top-left corner of the surface row
	strip.position = start_world - Vector2(tile_size.x * 0.5, tile_size.y * 0.5)
	add_child(strip)


func _spawn_spike(world_pos: Vector2) -> void:
	var spike = spike_scene.instantiate()
	spike.position = world_pos
	add_child(spike)
	spike.add_to_group("hazards")


# ─── TEMPLATE GATING ────────────────────────────────────────────────────

## Decide whether `tmpl` can appear given the current unlock state.
## A template is admitted if:
##   * It has no ramp glyphs.
##   * All entity glyphs (excluding 'spike' which is always allowed) refer to
##     enemies that are individually unlocked.
##   * If procgen is NOT unlocked, the template must additionally be "simple":
##     the bottom row is the only row containing '#' or 's' characters — i.e.
##     no stairs, no elevated platforms, no pit-combos.
func _template_admissible(tmpl: Dictionary) -> bool:
	var pattern: Array = tmpl["pattern"]
	# Ramps disqualify.
	for row in pattern:
		if "/" in row or "\\" in row: return false
	# Entity gating.
	for key in tmpl.keys():
		if key == "pattern": continue
		var entity_id: String = tmpl[key]
		if entity_id == "spike": continue
		if not _is_entity_allowed(entity_id): return false
	# Simple-floor check when procgen locked. Spikes ('s') are hazards on the
	# floor, not walls, so they don't disqualify a row from being "simple".
	if not Global.is_unlocked("procgen"):
		var floor_rows := 0
		for i in pattern.size():
			var row: String = pattern[i]
			if "#" in row:
				if i != pattern.size() - 1:
					return false                 # # above the bottom row → stairs / platforms
				floor_rows += 1
		if floor_rows == 0: return false
	return true

func _build_active_template_indices() -> Array:
	var out: Array = []
	for i in TEMPLATES.size():
		if _template_admissible(TEMPLATES[i]):
			out.append(i)
	if out.is_empty():
		out.append(TEMPLATE_STARTER_IDX)
	return out


# ─── MAIN GENERATION ────────────────────────────────────────────────────

func generate_level() -> void:
	var rng = RandomNumberGenerator.new()
	if current_seed == 0:
		rng.randomize()
		current_seed = rng.seed
	else:
		rng.seed = current_seed

	# In-game background goes in BEFORE the UI so it sits visually behind.
	add_child(bg_scene.instantiate())
	add_child(hud_scene.instantiate())
	add_child(pause_scene.instantiate())

	var ui_instance = ui_scene.instantiate()
	add_child(ui_instance)

	var active_indices := _build_active_template_indices()

	var next_x := 0
	var next_y := 0
	var spawn_pos := Vector2.ZERO
	var lowest_y := -99999.0

	for i in range(level_width_blocks):
		var tmpl_idx: int
		if i == 0:
			tmpl_idx = TEMPLATE_STARTER_IDX
		else:
			tmpl_idx = active_indices[rng.randi() % active_indices.size()]
		var tmpl: Dictionary = TEMPLATES[tmpl_idx]

		var pattern: Array = tmpl["pattern"]
		var block_w: int = pattern[0].length()
		var block_h: int = pattern.size()

		# Find left edge solid row (for y-alignment with previous block)
		var left_solid_y := 0
		for y in range(block_h):
			var ch = pattern[y][0]
			if ch == '#' or ch == 's':
				left_solid_y = y
				break
		var y_offset := next_y - left_solid_y

		# ── 1) Spawn floor strips: group contiguous runs of '#' along each row.
		#         '#' creates a 3-deep strip starting at the same row.
		#         's' (spike) creates the spike sprite at that row and a
		#         1-wide strip ONE ROW LOWER, exactly matching the original
		#         per-tile spawn semantics (spike rests on top of its tile).
		for ty in range(block_h):
			var grid_y := y_offset + ty
			var row: String = pattern[ty]
			var rx := 0
			while rx < block_w:
				var ch_here: String = row[rx]
				if ch_here == '#':
					var run_start := rx
					while rx < block_w and row[rx] == '#':
						rx += 1
					var run_len := rx - run_start
					var world_start := Vector2(
						(next_x + run_start) * tile_size.x + tile_size.x * 0.5,
						grid_y * tile_size.y + tile_size.y * 0.5
					)
					_spawn_strip(world_start, run_len)
					var strip_bottom := world_start.y + (3 * tile_size.y)
					if strip_bottom > lowest_y: lowest_y = strip_bottom
				elif ch_here == 's':
					# Lift the spike a few pixels so its base sits clearly above
					# the wavy grass band instead of being clipped by it.
					var spike_world := Vector2(
						(next_x + rx) * tile_size.x + tile_size.x * 0.5,
						grid_y * tile_size.y + tile_size.y * 0.5 - 14.0
					)
					_spawn_spike(spike_world)
					var strip_world := Vector2(
						spike_world.x,
						grid_y * tile_size.y + tile_size.y * 0.5 + tile_size.y
					)
					_spawn_strip(strip_world, 1)
					var sb := strip_world.y + (3 * tile_size.y)
					if sb > lowest_y: lowest_y = sb
					rx += 1
				else:
					rx += 1

		# ── 1b) Coin sprinkle. Empty cells above any '#' in the column get a
		#         small chance of holding a coin, only when the skill is owned.
		if Global.is_unlocked("coins") and i > 0:
			for ty in range(block_h):
				var grid_y_c := y_offset + ty
				var row_c: String = pattern[ty]
				for tx in range(block_w):
					if row_c[tx] != '.': continue
					# Need solid ground somewhere below in this column.
					var has_floor_below := false
					for yy in range(ty + 1, block_h):
						if pattern[yy][tx] == '#':
							has_floor_below = true; break
					if not has_floor_below: continue
					if rng.randf() > 0.06: continue
					var cp = coin_scene.instantiate()
					cp.position = Vector2(
						(next_x + tx) * tile_size.x + tile_size.x * 0.5,
						grid_y_c * tile_size.y + tile_size.y * 0.5
					)
					add_child(cp)

		# ── 2) Spawn non-tile entities (ramps + enemies)
		for ty in range(block_h):
			var grid_y2 := y_offset + ty
			var row2: String = pattern[ty]
			for tx in range(block_w):
				var ch: String = row2[tx]
				var grid_x := next_x + tx
				var world_pos := Vector2(
					grid_x * tile_size.x + tile_size.x * 0.5,
					grid_y2 * tile_size.y + tile_size.y * 0.5
				)
				if ch == '/' or ch == '\\':
					# Ramps removed from the game — skip.
					continue
				elif ch in ['.', ' ', 'a', '#', 's']:
					pass
				elif tmpl.has(ch):
					var entity_id: String = tmpl[ch]
					var spawn_world := world_pos
					# Shooters must sit on top of the ground — snap their Y to
					# the row immediately above the nearest '#' or 's' below.
					if entity_id == "shooter":
						var floor_grid_y := -1
						for yy in range(ty + 1, block_h):
							var rrow: String = pattern[yy]
							if ("#" in rrow) or ("s" in rrow):
								floor_grid_y = y_offset + yy
								break
						if floor_grid_y != -1:
							spawn_world.y = floor_grid_y * tile_size.y - tile_size.y * 0.5
					_spawn_entity(entity_id, spawn_world)

		if i == 0:
			spawn_pos = Vector2(next_x * tile_size.x + tile_size.x * 2.0, next_y * tile_size.y - 55)

		next_x += block_w

		# Find right-edge solid row to align next block's Y
		var right_solid_y := -1
		for y in range(block_h):
			var ch = pattern[y][block_w - 1]
			if ch == '#' or ch == 's':
				right_solid_y = y
				break
		if right_solid_y != -1:
			next_y = y_offset + right_solid_y

	var p = player_scene.instantiate()
	p.position = spawn_pos
	p.set("game_over_ui", ui_instance)
	p.set("death_y_limit", lowest_y + tile_size.y * 2)
	add_child(p)
	player = p


# ─── CAMERA ─────────────────────────────────────────────────────────────

func setup_camera() -> void:
	if not player: return
	var cam = Camera2D.new()
	cam.make_current()
	cam.position = Vector2.ZERO
	player.add_child(cam)

	cam.limit_left = 0
	cam.limit_top = -10000000
	cam.limit_bottom = 10000000
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0

	var viewport_size = get_viewport_rect().size
	var base_zoom := 1.0
	if viewport_size.x > 0 and viewport_size.y > 0:
		var zoom_x = viewport_size.x / (tile_size.x * 14.0)
		var zoom_y = viewport_size.y / (tile_size.y * 8.0)
		base_zoom = min(zoom_x, zoom_y)
		cam.zoom = Vector2.ONE * base_zoom
	player.set("_base_zoom", base_zoom)
