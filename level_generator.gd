extends Node2D

static var current_seed: int = 0

@export var level_width_blocks: int = 40
@export var tile_scene: PackedScene = preload("res://tile_object.tscn")
@export var player_scene: PackedScene = preload("res://player.tscn")
@export var spike_scene: PackedScene = preload("res://spike.tscn")
@export var smasher_scene: PackedScene = preload("res://smasher.tscn")
@export var ramp_scene: PackedScene = preload("res://ramp.tscn")
@export var ui_scene: PackedScene = preload("res://ui.tscn")
@export var tile_size: Vector2 = Vector2(128, 128)

@export var frog_scene: PackedScene = preload("res://enemies/frog.tscn")
@export var big_frog_scene: PackedScene = preload("res://enemies/big_frog.tscn")
@export var bat_scene: PackedScene = preload("res://enemies/bat.tscn")
@export var bomb_scene: PackedScene = preload("res://enemies/bomb.tscn")
@export var rock_scene: PackedScene = preload("res://enemies/rock.tscn")
@export var kobold_scene: PackedScene = preload("res://enemies/kobold.tscn")
@export var shooter_scene: PackedScene = preload("res://enemies/shooter.tscn")

# Key: char in pattern string → value: entity id string or "spike"/"smasher" etc.
var TEMPLATES: Array = [
	# ─── SAFE START (always index 0) ───────────────────────────────────────────
	{ "pattern": ["................", "................", "################"] },

	# ─── FLAT RUNS ─────────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "########"] },
	{ "pattern": ["............", "............", "############"] },

	# ─── SIMPLE PIT ────────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "##aaaa##"] },
	{ "pattern": ["........", "........", "###aa###"] },
	{ "pattern": [".........", ".........", "####a####"] },

	# ─── SPIKES ────────────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "..s.s.s.", "########"], "s": "spike" },
	{ "pattern": ["........", "........", "s.....s.", "########"], "s": "spike" },
	{ "pattern": ["............", "............", "s..s....s..s", "############"], "s": "spike" },

	# ─── SPIKES OVER PIT ───────────────────────────────────────────────────────
	{ "pattern": ["............", "............", "##s.aaaa.s##"], "s": "spike" },
	{ "pattern": ["............", "............", "##.s.aa.s.##"], "s": "spike" },

	# ─── STAIRS UP / DOWN ──────────────────────────────────────────────────────
	{ "pattern": ["......##", "....####", "..######", "########"] },
	{ "pattern": ["##......", "####....", "######..", "########"] },
	{ "pattern": ["....##..", "..######", "########"] },
	{ "pattern": ["..####..", "########"] },

	# ─── ELEVATED PLATFORM ─────────────────────────────────────────────────────
	{ "pattern": ["...####.", "........", "........", "########"] },
	{ "pattern": ["..####..", "........", "........", "########"] },
	{ "pattern": ["....##.....", "...........", "...........", "###########"] },

	# ─── SMASHERS ──────────────────────────────────────────────────────────────
	{ "pattern": ["..T.....", "........", "........", "........", "########"],               "T": "smasher" },
	{ "pattern": [".T.......T...", "..............", ".............", ".............", "#############"],               "T": "smasher" },
	{ "pattern": ["....T...", "........", "........", "##....##", "########"],               "T": "smasher" },
	{ "pattern": ["..T.....", "........", "........", "..s.s.s.", "########"],               "T": "smasher", "s": "spike" },

	# ─── FROGS ─────────────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "....f...", "########"],                           "f": "frog" },
	{ "pattern": ["........", "........", ".f....f.", "########"],                           "f": "frog" },
	{ "pattern": ["........", "........", "...f....", "..####..", "........", "########"],   "f": "frog" },
	{ "pattern": ["............", "............", "f....f....f.", "############"],           "f": "frog" },

	# ─── BIG FROG ──────────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "....F...", "########"],                           "F": "big_frog" },
	{ "pattern": ["............", "............", "....F.......", "############"],            "F": "big_frog" },

	# ─── BATS ──────────────────────────────────────────────────────────────────
	{ "pattern": ["..b.....", "........", "........", "########"],                           "b": "bat" },
	{ "pattern": [".b....b.", "........", "........", "########"],                           "b": "bat" },
	{ "pattern": ["....b...", "........", "##aaaa##"],                                      "b": "bat" },
	{ "pattern": ["...b...b...", "...........", "###.aaaa.##"],                             "b": "bat" },

	# ─── BOMBS ─────────────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "......B.", "########"],                           "B": "bomb" },
	{ "pattern": ["........", "........", "...B....", "########"],                           "B": "bomb" },
	{ "pattern": ["........", "........", "B......B", "########"],                           "B": "bomb" },

	# ─── SPRING BOARDERS (replacing rock) ──────────────────────────────────────
	{ "pattern": ["............", "............", ".....r......", "############"],            "r": "rock" },
	{ "pattern": ["............", "............", ".....r......", "##aaaaaa####"],            "r": "rock" },

	# ─── SHOOTERS ──────────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "........", "...S....", "########"],               "S": "shooter" },
	{ "pattern": ["........", "........", "S.......", "........", "########"],               "S": "shooter" },
	{ "pattern": ["............", "............", "............", ".......S....", "############"], "S": "shooter" },

	# ─── KOBOLD PATROLS ────────────────────────────────────────────────────────
	{ "pattern": ["........", "........", "..k.....", ".######."],                           "k": "kobold" },
	{ "pattern": ["........", "........", ".k....k.", "########"],                           "k": "kobold" },
	{ "pattern": ["....####", "........", ".k......", "########"],                           "k": "kobold" },

	# ─── COMBOS ────────────────────────────────────────────────────────────────
	{ "pattern": ["....b...", "........", "..k.....", "########"],                           "b": "bat", "k": "kobold" },
	{ "pattern": ["........", "........", ".f....B.", "########"],                           "f": "frog", "B": "bomb" },
	{ "pattern": ["............", "............", "s.f.s...s.f.", "############"],           "s": "spike", "f": "frog" },
	{ "pattern": [".b.......b..", "............", "###.aaaa.###"],                          "b": "bat" },
	{ "pattern": ["....b...", "........", ".k..s.k.", "########"],                          "b": "bat", "k": "kobold", "s": "spike" },
	{ "pattern": ["............", ".b.......b..", "............", "s...s...s...", "############"], "b": "bat", "s": "spike" },
]

var player: Node = null

func _ready() -> void:
	generate_level()
	setup_camera()

func _spawn_tile(world_pos: Vector2) -> void:
	var tile = tile_scene.instantiate()
	tile.position = world_pos
	if tile.get("base_size"):
		tile.base_size = tile_size
	if tile.has_method("update_sizes"):
		tile.update_sizes()
	add_child(tile)
	tile.add_to_group("solid_tiles")

func _spawn_entity(id: String, world_pos: Vector2) -> void:
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
	if inst:
		inst.position = world_pos
		add_child(inst)
		inst.add_to_group("hazards")

func generate_level() -> void:
	var rng = RandomNumberGenerator.new()
	if current_seed == 0:
		rng.randomize()
		current_seed = rng.seed
	else:
		rng.seed = current_seed


	var ui_instance = ui_scene.instantiate()
	add_child(ui_instance)

	var next_x := 0
	var next_y := 0
	var spawn_pos := Vector2.ZERO
	var lowest_y := -99999.0

	for i in range(level_width_blocks):
		var tmpl: Dictionary = TEMPLATES[rng.randi() % TEMPLATES.size()]
		if i == 0:
			tmpl = TEMPLATES[0]

		var pattern: Array = tmpl["pattern"]
		var block_w: int = pattern[0].length()
		var block_h: int = pattern.size()

		# Find left edge solid row to align y
		var left_solid_y := 0
		for y in range(block_h):
			var ch = pattern[y][0]
			if ch == '#' or ch == 's':
				left_solid_y = y
				break

		var y_offset := next_y - left_solid_y

		for ty in range(block_h):
			var grid_y := y_offset + ty
			for tx in range(block_w):
				var grid_x := next_x + tx
				var ch: String = pattern[ty][tx]
				var world_pos := Vector2(
					grid_x * tile_size.x + tile_size.x * 0.5,
					grid_y * tile_size.y + tile_size.y * 0.5
				)

				if ch == '#':
					for layer in range(3):
						var ly = world_pos.y + layer * tile_size.y
						_spawn_tile(Vector2(world_pos.x, ly))
						if ly > lowest_y: lowest_y = ly

				elif ch == 's' or (tmpl.has(ch) and tmpl[ch] == "spike"):
					var spike = spike_scene.instantiate()
					spike.position = world_pos
					add_child(spike)
					spike.add_to_group("hazards")
					for layer in range(1, 4):
						var ly = world_pos.y + layer * tile_size.y
						_spawn_tile(Vector2(world_pos.x, ly))
						if ly > lowest_y: lowest_y = ly

				elif ch == '/' or ch == '\\':
					var ramp = ramp_scene.instantiate()
					ramp.ramp_type = "up" if ch == '/' else "down"
					ramp.base_size = tile_size
					ramp.position = world_pos
					add_child(ramp)
					for layer in range(1, 4):
						var ly = world_pos.y + layer * tile_size.y
						_spawn_tile(Vector2(world_pos.x, ly))
						if ly > lowest_y: lowest_y = ly

				elif ch == 'a':
					pass # Abyss — no floor spawned

				elif tmpl.has(ch):
					_spawn_entity(tmpl[ch], world_pos)

		if i == 0:
			spawn_pos = Vector2(next_x * tile_size.x + tile_size.x * 2.0, next_y * tile_size.y - 55)

		next_x += block_w

		# Find right-edge solid row to set next_y
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

	# Pass the base zoom to the player so it can manage dynamic zoom tweening
	player.set("_base_zoom", base_zoom)
