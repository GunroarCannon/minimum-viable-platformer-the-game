# Minimum Viable Platformer — Developer Reference

> A procedurally generated, auto-running 2D platformer built in **Godot 4.4** (GL Compatibility renderer).
> This document is the authoritative reference for every file in the project, plus step-by-step guides for extending the game with new enemies, controls, obstacles, juice, parallax scrolling, menus, a skill tree, particles, and a leaderboard.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Directory and File Reference](#2-directory-and-file-reference)
3. [Collision Layer Map](#3-collision-layer-map)
4. [Core Systems Deep-Dive](#4-core-systems-deep-dive)
5. [How to Add a New Enemy](#5-how-to-add-a-new-enemy)
6. [How to Change or Add Controls](#6-how-to-change-or-add-controls)
7. [How to Add a New Obstacle](#7-how-to-add-a-new-obstacle)
8. [How to Add More Juice](#8-how-to-add-more-juice)
9. [How to Add Parallax Scrolling](#9-how-to-add-parallax-scrolling)
10. [How to Add More Menus](#10-how-to-add-more-menus)
11. [How to Add a Skill Tree](#11-how-to-add-a-skill-tree)
12. [How to Add Custom Particle Effects](#12-how-to-add-custom-particle-effects)
13. [How to Add a Leaderboard](#13-how-to-add-a-leaderboard)
14. [Debug Toggles Reference](#14-debug-toggles-reference)

---

## 1. Project Overview

| Setting | Value |
|---|---|
| Engine | Godot 4.4 |
| Renderer | GL Compatibility (runs on web, mobile, desktop) |
| Viewport | 1280 x 720, canvas_items stretch mode |
| Main Scene | leve.tscn (note: intentional short name) |
| Autoload | `Global` singleton (`global.gd`) |
| Entry Point | `level_generator.gd` runs inside `leve.tscn` |

The game generates a new level from ASCII-art templates every run. The player auto-runs to the right and presses Jump (Space / tap) to survive obstacles, enemies, and pits.

---

## 2. Directory and File Reference

### 2.1 Root Files

---

#### `project.godot`
The Godot project configuration file. Declares the main scene, autoloads, display settings, and rendering method. Use the Godot Editor Project Settings dialog rather than editing this directly. Key entries:
- **`run/main_scene`** points at `leve.tscn`.
- **`[autoload]`** registers `global.gd` as the `Global` singleton, accessible everywhere as `Global.something`.

---

#### `global.gd`
**Role:** Autoloaded singleton. The only script loaded at boot before any scene.

**What it does:**

1. **Input Map initialization** — Programmatically registers `left`, `right`, `up`, `down`, `jump`, `dash` actions pointing at A, D, W, S, Space, and Shift. Also registers stub actions (`run`, `latch`, `roll`, `twirl`) so the platformer controller does not spam errors. You never need to configure Input Map bindings in Project Settings by hand.

2. **Camera zoom exports** — Exposes `camera_zoom_mode`, `camera_zoom_out_factor`, `camera_hazard_distance`, `camera_tile_threshold`, and `camera_zoom_tween_duration` as inspector properties on the Global autoload node.

3. **Debug flags** — `debugText` (bool), `use_primitives` (bool — swaps all sprites with `_draw()` primitives for testing without assets), and a `debug_toggles` Dictionary containing `auto_restart`, `keep_seed`, `show_collisions`.

**Internal structure:**
```
global.gd
├── @export camera settings (zoom mode, factors, timing)
├── @export debug settings (debugText, use_primitives, debug_toggles dict)
└── _ready()
	└── _initialize_input_map()
		├── Registers primary actions (left, right, up, down, jump, dash)
		└── Registers stub actions (run, latch, roll, twirl)
```

---

#### `level_generator.gd`
**Role:** Attached to the root Node2D in `leve.tscn`. Generates the entire level procedurally.

**What it does:**

1. Holds a large `TEMPLATES` array of ASCII-art pattern strings. Each template is a Dictionary with a `"pattern"` key (array of strings, one string per row) and optional character-to-entity mappings.
2. Iterates `level_width_blocks` times (default 40), picking a random template per block.
3. Translates ASCII characters into spawned scenes: `#` = tile column, `a` = abyss (skip), `s` = spike + tiles, `/` or `\` = ramp + tiles, all other mapped characters = entity lookup via `_spawn_entity()`.
4. Spawns the player after all tiles, then calls `setup_camera()` which creates a Camera2D, attaches it to the player, and calculates `base_zoom` from the viewport size.

**Template character map:**

| Character | Entity |
|---|---|
| `#` | Solid tile column (3 tiles deep) |
| `a` | Abyss — no floor spawned |
| `s` | Spike (+ tile column below) |
| `/` | Up-ramp (RampObject) |
| `\` | Down-ramp (RampObject) |
| `T` | Smasher |
| `f` | Frog |
| `F` | BigFrog |
| `b` | Bat |
| `B` | Bomb |
| `r` | Rock (spring launcher) |
| `k` | Kobold |
| `S` | Shooter cannon |
| `d` | Drill (Mole) |
| `j` | Jumper |

**Internal structure:**
```
level_generator.gd
├── static var current_seed  ← shared across reloads for "same seed" retry
├── @export scenes (tile, player, spike, smasher, ramp, ui, all enemy scenes)
├── TEMPLATES[]              ← the full library of ASCII patterns
├── _ready()
│   ├── generate_level()
│   └── setup_camera()
├── _spawn_tile(world_pos, is_top)   creates TileObject
├── _spawn_entity(id, world_pos)     match-based entity factory
├── generate_level()
│   ├── Initializes RNG (fresh or from current_seed)
│   ├── Spawns UI
│   ├── Iterates templates → calls _spawn_tile / _spawn_entity
│   └── Spawns player at computed spawn_pos
└── setup_camera()
	├── Creates Camera2D, attaches to player
	├── Computes base_zoom (viewport / tile count ratio)
	└── Passes base_zoom to player._base_zoom
```

---

#### `player.gd`
**Role:** Extends `PlatformerController2D` (the addon). The central character script.

**What it does:**
- Calls `super._ready()` to initialize the controller, then sets up sprite frames, collision sensors, debug UI, and momentum variables.
- **Auto-run** — uses `auto_momentum` that ramps from 0 to `run_speed` governed by `auto_acceleration`. Simulates a gentle sprint ramp-up by pressing/releasing the `"right"` action programmatically each physics frame.
- **Stun system** — when `stun_timer > 0` the auto-run is suppressed and the player bleeds horizontal momentum back toward zero. Used for knockback from the Rock enemy.
- **Sensor setup** (all created at runtime in `_setup_sensors()`):
  - `_foot_sensor`: tiny Area2D just below the feet. When it overlaps an enemy area (layer 4), calls `enemy.stomp_by(self)`.
  - `_body_sensor`: full-body Area2D on layer 8. Enemies detect this layer and call `player.die()` on contact.
  - `_screen_sensor`: viewport-sized sensor on layer 1 (solid tiles). Used for dynamic zoom mode 2 tile counting only.
- **Squash and Stretch** — tween-based sprite scale manipulation on jump and land events.
- **Camera shake** — `shake_camera(intensity, duration)` offsets the Camera2D each frame for the duration.
- **Dynamic zoom** — `_update_dynamic_zoom()` checks either hazard proximity (mode 1) or visible tile count (mode 2) and smoothly tweens the camera zoom in or out.
- **Death** (`die(is_fall)`) — disables sensors, releases inputs, plays fall animation (camera detaches, sprite rotates 90°, poof particles) or tear animation (TearEffect shatters sprite into physics polygon pieces). After 1.8 seconds shows the game-over UI or auto-restarts.

**Internal structure:**
```
player.gd  (extends PlatformerController2D)
├── @export run_speed, auto_acceleration
├── _ready()
│   ├── super._ready()
│   ├── _auto_setup_sprite_frames()   ← loads all animation PNGs
│   ├── _setup_sensors()              ← foot, body, screen Area2Ds
│   └── _setup_debug_ui()            ← optional overlay + checkboxes
├── _draw()             primitives-mode rectangle
├── _physics_process()  death check, stun/momentum, super call, jump stretch, land squash
├── _squash_and_stretch(scale_modifier)
├── shake_camera(intensity, duration)
├── _process()          camera shake tick, dynamic zoom update, debug text update
├── _update_dynamic_zoom()
│   ├── Mode 1: hazard group distance check
│   └── Mode 2: PhysicsShapeQueryParameters2D tile count
├── _do_zoom_tween()
├── _get_camera() → Camera2D
├── die(is_fall)
│   ├── Disable sensors
│   ├── is_fall=true  → detach camera, rotate sprite, poof particles
│   └── is_fall=false → TearEffect.apply() circular shatter
└── get_local_lowest_y()   lowest nearby tile Y (for fall-death threshold)
```

---

#### `leve.tscn`
**Role:** The main scene. Root Node2D with `level_generator.gd` attached. Nearly empty — all content is spawned at runtime by the generator.

---

#### `tile_object.gd` / `tile_object.tscn`
**Role:** Represents a single 128×128 solid floor tile. Extends `StaticBody2D`, class name `TileObject`.

**What it does:**
- Scales its `Sprite2D` texture to fit `base_size`.
- Provides a `CollisionShape2D` (solid, layer 1) and an `Area2D` trigger (slightly larger, reserved for future use).
- `squash(factor, duration)` — tween that squishes the sprite down and bounces back. Called by the player when landing.
- `shake(intensity, duration)` — each `_process()` frame offsets the sprite by a random amount while the shake timer is running.
- `determine_exposed_sides()` — checks neighboring tiles and draws border lines on exposed edges.
- `_draw()` — when `Global.use_primitives` is true, draws a warm stone rectangle with a top highlight instead of the texture. Also draws debug outlines if `Global.debug_toggles["show_collisions"]` is true.

**Internal structure:**
```
tile_object.gd  (extends StaticBody2D — class_name TileObject)
├── @export base_size, trigger_zone_size, visual_texture, debug
├── @onready sprite, solid_collision, trigger_area, area_collision
├── _ready()          → update_sizes(), queue_redraw()
├── update_sizes()    → scales sprite, sets collision shape sizes
├── squash()          → Tween y-squish + bounce back
├── shake()           → random sprite offset for a duration
├── determine_exposed_sides()  → scans all neighbor tiles
└── _draw()           → primitive rect or debug outlines
```

---

#### `spike.gd` / `spike.tscn`
**Role:** Static instant-kill hazard area. Kills the player on touch and can also kill enemies. Extends `Area2D`, class name `Spike`.

- `body_entered` — kills `BaseEnemy` bodies via `die_torn(velocity)`, kills the player via `die()`.
- `area_entered` — specifically detects smasher areas and calls `die()` on them (so smasher + spike = smasher destroyed).
- Draws a triangle with `_draw()` in primitives mode. Loads `assets/spikes.png` otherwise.

---

#### `smasher.gd` / `smasher.tscn`
**Role:** A ceiling hazard that falls when the player approaches. Extends `Area2D`, class name `Smasher`.

**State machine:** `idle → falling → smashed → rising → idle`

- **idle**: polls player X distance against `trigger_distance`. Transitions to falling when close enough.
- **falling**: moves down at `fall_speed` px/s. Reads `$RayCast2D` for floor contact. Kills anything it hits via `body_entered`.
- **smashed**: waits `smashed_timer` seconds (default 1.0s) on the ground.
- **rising**: moves up at `rise_speed` px/s back to `original_y`.

Also builds a one-way `StaticBody2D` top-cap in `_ready()` so entities can safely stand on top without being killed. Changes its sprite between `tex_normal` and `tex_angry` depending on state. On spike contact: calls own `die()` → TearEffect shatter.

---

#### `ramp.gd` / `ramp.tscn`
**Role:** A triangular ramp tile. Extends `StaticBody2D`, class name `RampObject`.

- `ramp_type = "up"` → `/` shape; `ramp_type = "down"` → `\` shape.
- Builds a `CollisionPolygon2D` triangle at runtime.
- `squash()` — brief scale pop tweened with `TRANS_SPRING`.

---

#### `tear_effect.gd`
**Role:** Static utility class (no scene or node needed). Shatters any `Node2D` into physics polygon pieces on death. Class name `TearEffect` — callable anywhere as `TearEffect.apply(...)`.

**How it works:**
1. Builds a base polygon from `size` (rectangle, circle, or plain rect for "logs").
2. Applies jagged perturbation to edges (`_jag_polygon`).
3. Recursively cuts the polygon with random straight lines (`_subdivide` → `_cut`), biased by optional `hard_points`.
4. For each resulting piece: creates a `RigidBody2D` with `CollisionPolygon2D` and `Polygon2D`, tries to sample the original node's sprite texture for UVs; falls back to color variation.
5. Applies outward impulse, random angular velocity, gravity scale 2.0, then tweens alpha to 0 over 1.2–2.4 seconds and auto-frees.

**Tear types:**

| Type | Polygon Shape | Cut Behavior |
|---|---|---|
| `"default"` | Jagged rectangle | Random angle cuts |
| `"circular"` | 16-sided circle (jagged) | Random angle cuts |
| `"logs"` | Plain rectangle | Horizontal cuts only |

---

#### `ui.gd` / `ui.tscn`
**Role:** Game Over overlay. Extends `CanvasLayer`, class name `GameOverUI`.

- Hides itself on `_ready()` during normal gameplay.
- `show_game_over()` — makes itself visible. Called by the player 1.8 seconds after death.
- **Retry Random**: resets `level_generator.gd.current_seed = 0` then `reload_current_scene()`.
- **Retry Seed**: keeps `current_seed` intact then reloads (exact same layout).
- **Exit**: `get_tree().quit()`.

---

### 2.2 `enemies/` Directory

All enemy scenes share the same node structure in their `.tscn`:
- Root `CharacterBody2D` (or `Area2D`) with the enemy script attached.
- `$CollisionShape2D` — physics body collision rectangle.
- `$Hitbox` (`Area2D`) + `$Hitbox/CollisionShape2D` — the contact zone that kills the player when overlapped.

---

#### `enemies/base_enemy.gd`
**Role:** Base class for all mobile enemies. Class name `BaseEnemy`.

**Key properties:**
- `can_be_stomped` (default `true`) — whether the player's foot-sensor stomp kills it.
- `gravity_scale` (default `1.0`) — set to `0.0` for flying enemies like Bat and Bullet.
- `tear_size`, `tear_color`, `tear_type` — configure the TearEffect shatter on death. Set in each subclass `_ready()`.
- `tear_hard_points` — local-space `Vector2` array that biases cut angles; useful for limb-shaped characters.
- `tears_on_death` — set `false` (e.g. Bomb) to skip TearEffect and use a custom death effect instead.

**Key methods:**
- `_find_player()` — lazy search in parent for a node named `"Player"`. Cached after first find.
- `_physics_process(delta)` — applies gravity, calls `_custom_process(delta)`, calls `move_and_slide()`.
- `_custom_process(delta)` — the override point for subclass AI logic. Called every physics frame.
- `stomp_by(stomper)` — called by the player's foot sensor. Kills self, bounces player upward (−900 px/s).
- `_on_hitbox_area_entered(area)` — called when the player body sensor overlaps. Skips if player center is more than 30 px above enemy center (overhead / stomp intent). Otherwise calls `player.die()`.
- `die(torn, impact_vel)` — either TearEffect shatter or CPUParticles2D poof, then `queue_free()`.
- `die_torn(impact_vel)` — shorthand for `die(true, impact_vel)`.

---

#### `enemies/frog.gd` — Frog
Ground-based hopper. Idles until the player is within `hop_distance` (600 px), then launches with `hop_velocity` (400, −800) toward the player. `hop_cooldown` 1.5 s. Animates `idle` / `jump` states. Green, 64×64.

#### `enemies/big_frog.gd` — BigFrog
Identical structure to Frog but larger and with a longer, stronger hop. Typically placed to occupy wide platform spans.

#### `enemies/bat.gd` — Bat
Flying enemy (`gravity_scale = 0`). Idles until the player enters `trigger_distance` (1000 px), then dives in a steep downward direction. Once triggered, it never stops moving. Animates looping `fly`. Dark grey, 64×48.

#### `enemies/kobold.gd` — Kobold
Ground patrol. Walks at `walk_speed` (150 px/s) and uses `$RayCastLeft` / `$RayCastRight` to detect ledge edges and wall collisions, reversing direction on either. Brown/orange, 64×96.

#### `enemies/bomb.gd` — Bomb
Walking bomb. Approaches the player, enters `loading` state when within `trigger_distance` (400 px), pulses red via `_draw()` modulation, then explodes after `explosion_delay` (1.0 s). If the player is within `explosion_radius` (250 px) it calls `player.die()` and spawns a large CPUParticles2D burst. Does **not** use TearEffect (custom death). Triggers camera shake on explosion.

#### `enemies/rock.gd` — Rock (Spring Launcher)
Does **not** die from stomping — instead it launches the player incredibly high (`bounce_velocity = −1400`). Side-touching it triggers knockback (`stun_timer = 0.55`). Also bounces nearby enemy bodies horizontally via a separate `Area2D`. Red/grey spring block, 128×96.

#### `enemies/shooter.gd` — Shooter (Cannon)
Extends `StaticBody2D` (it is a static wall, not a mobile enemy). Fires a `bullet.tscn` every `shoot_interval` (3.0 s) in `direction` (−1 = left). Draws a cannon sprite or a primitive pillar.

#### `enemies/bullet.gd` — Bullet
Extends `BaseEnemy`. Flies horizontally (`gravity_scale = 0`) at `fly_speed` (400 px/s). Kills other enemy bodies it contacts (`_on_hit_enemy`). Destroys itself on wall contact. Tear type is `"logs"` (horizontal splits, looks like a broken cannonball). Can be stomped by the player for a small bounce reward.

#### `enemies/drill.gd` — Drill (Mole)
Extends `Area2D`. Drops from the ceiling when the player passes below it. Falls at `fall_speed` (600 px/s) indefinitely until hitting `death_y_limit`. Kills the player, enemies, and even **destroys** `TileObject` bodies it contacts while falling (unique behaviour in the codebase).

#### `enemies/jumper.gd` — Jumper
Like the Frog but stomping it launches the player to an extreme height (`launch_velocity = −2400`). Short camera shake on stomp. Purple, 64×64.

---

### 2.3 `assets/` Directory

```
assets/
├── animations/
│   ├── player/
│   │   ├── player_idle/   0–3.png   (4 frames, 160×220)
│   │   ├── player_run/    0–6.png   (7 frames)
│   │   ├── player_jump/   0–6.png   (7 frames)
│   │   ├── player_hurt_1/ 0–2.png   (3 frames)
│   │   └── player_hurt_2/ 0–2.png   (3 frames)
│   ├── frog_idle/         0.png     (1 frame)
│   ├── frog_jump/         0–3.png   (4 frames)
│   ├── bat/               0–3.png   (4 frames)
│   ├── kobold/            0–7.png   (8 frames)
│   ├── cannon/            0–15.png  (16 frames)
│   ├── bullet_bob/        0–3.png   (4 frames)
│   └── mole/              0–5.png   (6 frames)
├── smasher_sharp/
│   ├── normal.png
│   ├── angry.png
│   └── hurt.png
├── dirt_floor.png         (128×128 tile underside texture)
├── top_dirt_floor.png     (128×128 tile top-surface texture)
└── spikes.png             (spike sprite)
```

All animation frames are loaded at runtime in each script's `_ready()` using `load("res://assets/animations/...")`. Adding new animation frames only requires placing PNG files in the correct folder with sequential numbering starting at 0.

---

### 2.4 `addons/` Directory

#### `addons/UltimatePlatformerController.gd`
**Role:** Third-party open-source platformer controller. Class name `PlatformerController2D`. `player.gd` extends this class.

**What it provides:** Full-featured `CharacterBody2D` with:
- Acceleration / deceleration (configurable `timeToReachMaxSpeed`, `timeToReachZeroSpeed`)
- Coyote time + jump buffering
- Variable jump height (short-hop via `shortHopAkaVariableJumpHeight`)
- Wall jump, wall slide, wall latch (with optional modifier key)
- Multi-jump (up to 4 in the controller; player.gd uses 1 by default)
- Dashing (None, Horizontal, Vertical, Four-Way, Eight-Way)
- Crouching + rolling
- Ground pound with configurable hover pause
- Corner cutting with raycasts
- Sprite flip on direction change
- Animation state machine wiring (`idle`, `run`, `walk`, `jump`, `falling`, `slide`, `latch`, `crouch_idle`, `crouch_walk`, `roll`)

`player.gd` overrides `_physics_process` and `_process` (calling `super` each time) to layer auto-run momentum, stomp detection, squash-and-stretch, camera shake, and dynamic zoom on top.

---

## 3. Collision Layer Map

| Layer Number | Name | Used By |
|---|---|---|
| 1 | Solid tiles / floor | `TileObject` body, `_screen_sensor` mask, enemy movement mask |
| 2 | Enemy bodies | `BaseEnemy` body layer, Spike mask, Smasher mask |
| 3 | (unused) | — |
| 4 | Enemy hitboxes | `$Hitbox` Area2D in every enemy; player foot sensor mask |
| 5–7 | (unused) | — |
| 8 | Player body sensor | `_body_sensor` layer in Player; `$Hitbox` mask in enemies |

---

## 4. Core Systems Deep-Dive

### 4.1 Level Generation

The generator uses a **template-based** approach. Each "block" in `TEMPLATES` is one dictionary. Blocks snap together by matching the Y-level of the **right edge solid row** of the previous block to the **left edge solid row** of the next block. This creates seamless height transitions across stairs, platforms, and flat runs without any constraint-solving — just edge-matching.

Adding a new template is as simple as appending a new dictionary to `TEMPLATES` and mapping its characters:

```gdscript
{ "pattern": [
	"..X.....",
	"........",
	"........",
	"########"
  ],
  "X": "my_new_enemy"
}
```

Then register `"my_new_enemy"` in `_spawn_entity()`.

### 4.2 Player

The player is kept deliberately thin. It delegates all movement physics to the addon (`super._physics_process`) and only adds:
- Momentum simulation via `auto_momentum` + `Input.action_press("right")`.
- Sensor management for stomp detection, player death, and dynamic zoom.
- Visual juice via squash-and-stretch and camera shake.
- Death state with a 1.8-second delay for dramatic effect before scene reload.

### 4.3 Camera and Dynamic Zoom

The `Camera2D` lives inside the player node so it follows automatically via Godot's parent-relative positioning. On player death from falling, the camera is **reparented** to the level root so it stays in place while the player falls off-screen, preventing a jarring scroll down into the void.

Zoom is managed in `player.gd::_update_dynamic_zoom()`. Two modes are available:

- **Mode 1 (Hazard Distance)** — scans the `"hazards"` group each frame. If any hazard is farther ahead than `camera_hazard_distance`, zooms out. Simple, cheap.
- **Mode 2 (Tile Count)** — performs a `PhysicsShapeQueryParameters2D` query with a viewport-sized rectangle and counts overlapping bodies in the `"solid_tiles"` group. Zooms out if fewer than `camera_tile_threshold` tiles are visible. More accurate but slightly more expensive.

### 4.4 TearEffect

A fully self-contained static class. Call it from any dying entity:

```gdscript
TearEffect.apply(self, Vector2(80, 110), Color(0.4, 0.8, 1.0), velocity, [], "circular")
```

The resulting `RigidBody2D` pieces have `collision_layer = 0` (do not block gameplay) and `collision_mask = 1` (bounce on the floor visually). They auto-free after fading out.

### 4.5 TileObject

Every solid tile in the level is a `TileObject`. They are spawned in columns 3 tiles deep per `#` character. The topmost tile uses `top_dirt_tex`; the others use `dirt_tex`. The `squash()` method is called by the player on landing, making the floor feel physically responsive.

### 4.6 UI and Game Over

The UI is spawned by `level_generator.gd` at level start and passed to the player as `game_over_ui`. The player calls `game_over_ui.show_game_over()` 1.8 seconds after death. The scene is a `CanvasLayer` so it always renders on top regardless of camera position.

---

## 5. How to Add a New Enemy

### Step 1 — Create the scene

1. In Godot, duplicate `enemies/base_enemy.tscn` and rename it `enemies/my_enemy.tscn`.
2. The scene tree should look like:
   ```
   MyEnemy (CharacterBody2D)     ← root, with my_enemy.gd attached
   ├── CollisionShape2D           ← physics body collision
   └── Hitbox (Area2D)
	   └── CollisionShape2D       ← contact zone that kills the player
   ```
3. If your enemy flies, add `gravity_scale = 0.0` in your `_ready()`.

### Step 2 — Write the script

Create `enemies/my_enemy.gd`:

```gdscript
extends BaseEnemy

@export var my_speed: float = 200.0

func _ready() -> void:
	super._ready()    # REQUIRED — sets up collision layers and hitbox signal
	tear_size  = Vector2(64, 64)      # match your sprite's visual size
	tear_color = Color(1.0, 0.5, 0.0)
	# Resize collision shapes to match your art:
	var coll = $CollisionShape2D
	if coll and coll.shape is RectangleShape2D:
		coll.shape.size = Vector2(64, 64)
	var hitbox_coll = $Hitbox/CollisionShape2D
	if hitbox_coll and hitbox_coll.shape is RectangleShape2D:
		hitbox_coll.shape.size = Vector2(74, 74)   # slightly larger than body

func _custom_process(delta: float) -> void:
	# AI goes here — called every physics frame by BaseEnemy._physics_process()
	if not player: return
	var dir = sign(player.global_position.x - global_position.x)
	velocity.x = dir * my_speed

func _draw() -> void:
	if Global.use_primitives:
		draw_rect(Rect2(-32, -32, 64, 64), Color(1.0, 0.5, 0.0))
```

### Step 3 — Register in the level generator

In `level_generator.gd`:

1. Preload the scene at the top of the file:
   ```gdscript
   @export var my_enemy_scene: PackedScene = preload("res://enemies/my_enemy.tscn")
   ```

2. Add a case to `_spawn_entity()`:
   ```gdscript
   "my_enemy": inst = my_enemy_scene.instantiate()
   ```

3. Add to `TEMPLATES` with a new character (e.g. `M`):
   ```gdscript
   { "pattern": ["........", "........", "..M.....", "########"], "M": "my_enemy" },
   ```

### Step 4 — Add sprite animation (optional)

Place frames in `assets/animations/my_enemy/0.png`, `1.png`, … then in `_ready()`:

```gdscript
if not Global.use_primitives:
	var anim = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.add_animation("walk")
	for f in range(8):
		var tex = load("res://assets/animations/my_enemy/" + str(f) + ".png")
		if tex: frames.add_frame("walk", tex)
	frames.set_animation_speed("walk", 12.0)
	frames.set_animation_loop("walk", true)
	anim.sprite_frames = frames
	anim.scale = Vector2(0.4, 0.4)   # adjust to fit collision size
	add_child(anim)
	anim.play("walk")
```

### Step 5 — Override stomp behavior (optional)

```gdscript
func stomp_by(stomper: Node2D) -> void:
	if _is_dying: return
	die()
	stomper.set("velocity", Vector2(stomper.velocity.x, -1200))
	if stomper.has_method("shake_camera"):
		stomper.shake_camera(20.0, 0.4)
```

---

## 6. How to Change or Add Controls

### Changing existing key bindings

Bindings are set in `global.gd::_initialize_input_map()`. Change the values in `input_configs`:

```gdscript
var input_configs: Dictionary = {
	"left":  KEY_LEFT,    # was KEY_A
	"right": KEY_RIGHT,   # was KEY_D
	"jump":  KEY_Z,       # was KEY_SPACE
	"dash":  KEY_X,       # was KEY_SHIFT
}
```

Any `KEY_*` constant from Godot's `@GlobalScope` is valid.

### Adding a new action

1. Register it in `global.gd`:
   ```gdscript
   input_configs["glide"] = KEY_Q
   ```

2. Use it in `player.gd`:
   ```gdscript
   if Input.is_action_pressed("glide"):
	   velocity.y -= 200 * delta    # fight gravity while held
   ```

### Adding controller / gamepad support

After adding the keyboard event in `global.gd`, also add a joypad event:

```gdscript
var joy_event = InputEventJoypadButton.new()
joy_event.button_index = JOY_BUTTON_A   # South face button
InputMap.action_add_event("jump", joy_event)
```

For analog sticks use `InputEventJoypadMotion` and set `axis` and `axis_value`.

### Adding touch / mobile support

The player already handles `InputEventScreenTouch` in `_unhandled_input()` — any tap anywhere triggers a jump. For more complex mobile controls (left/right virtual buttons), add them as a `CanvasLayer` inside `ui.tscn` and call `Input.action_press("right")` / `Input.action_release("right")` from their button callbacks.

---

## 7. How to Add a New Obstacle

### Option A — Static instant-kill area (like Spike)

```gdscript
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is BaseEnemy:
		body.die_torn(body.velocity)
	elif body.has_method("die"):
		body.die()
```

Register a new character in `level_generator.gd` `TEMPLATES` and `_spawn_entity`.

### Option B — Triggered falling obstacle (like Smasher)

1. Extend `Area2D`.
2. Add a `RayCast2D` pointing downward to detect floor contact.
3. Use a `state` string variable and a `match state:` block in `_process()`.
4. Build a one-way `StaticBody2D` top-cap in `_ready()` if you want entities to safely stand on top.
5. Connect `body_entered` to your kill logic.

### Option C — Moving platform

```gdscript
extends StaticBody2D

@export var move_distance: float = 400.0
@export var move_speed: float = 100.0

var _direction: int = 1
var _start_x: float

func _ready() -> void:
	_start_x = global_position.x

func _physics_process(delta: float) -> void:
	global_position.x += _direction * move_speed * delta
	if abs(global_position.x - _start_x) > move_distance:
		_direction *= -1
```

Add it to the `"solid_tiles"` group so the camera zoom tile counter includes it.

### Option D — Projectile obstacle

Follow `bullet.gd` — extend `BaseEnemy` with `gravity_scale = 0`, set a constant horizontal velocity in `_custom_process()`, and call `die()` when `is_on_wall()`.

---

## 8. How to Add More Juice

### 8.1 Hit-flash on enemy death

In any enemy's `stomp_by` or `_on_hitbox_area_entered`, add a modulate flash before dying:

```gdscript
if anim:
	var tw = create_tween()
	tw.tween_property(anim, "modulate", Color.WHITE, 0.05)
	tw.tween_property(anim, "modulate", Color.TRANSPARENT, 0.1)
await get_tree().create_timer(0.12).timeout
die()
```

### 8.2 Screen-space vignette on player hit

Add a `ColorRect` with a shader material to the UI `CanvasLayer`. In `player.die()`:

```gdscript
vignette_rect.material.set_shader_parameter("intensity", 0.8)
var tw = create_tween()
tw.tween_method(
	func(v): vignette_rect.material.set_shader_parameter("intensity", v),
	0.8, 0.0, 0.6
)
```

The shader multiplies pixel color by `(1 - dot(uv_from_center, uv_from_center) * intensity * 4)` to darken edges.

### 8.3 Motion trail behind the player

Add a `Line2D` node to the player scene and record recent world positions:

```gdscript
@onready var trail: Line2D = $Trail
var _trail_points: Array = []

func _process(delta):
	super._process(delta)
	_trail_points.push_front(global_position)
	if _trail_points.size() > 12:
		_trail_points.pop_back()
	trail.clear_points()
	for p in _trail_points:
		trail.add_point(p)
```

Set `Line2D.width_curve` to taper from thick at index 0 to thin at the end for a natural look.

### 8.4 More camera shake

Call `player.shake_camera(intensity, duration)` from any entity with a player reference:

```gdscript
# From a bomb explosion:
if player.has_method("shake_camera"):
	player.shake_camera(35.0, 0.45)
```

### 8.5 Screen freeze on stomp

In `BaseEnemy.stomp_by()`:

```gdscript
Engine.time_scale = 0.05
await get_tree().create_timer(0.04).timeout
Engine.time_scale = 1.0
```

Place this before bouncing the player so the freeze happens at the moment of impact.

### 8.6 Tile ripple on player landing

In `TileObject.squash()`, also shake neighboring tiles proportionally to their distance:

```gdscript
# At the end of squash():
for tile in get_tree().get_nodes_in_group("solid_tiles"):
	if tile == self: continue
	var dist = tile.global_position.distance_to(global_position)
	if dist < 300:
		tile.shake(3.0 * (1.0 - dist / 300.0), 0.2)
```

---

## 9. How to Add Parallax Scrolling

Godot's built-in `ParallaxBackground` and `ParallaxLayer` nodes make this very straightforward.

### Step 1 — Add nodes to leve.tscn

Under the root `Node2D`, add:
```
ParallaxBackground
├── ParallaxLayer  (far — mountains)
│   └── Sprite2D
├── ParallaxLayer  (mid — hills)
│   └── Sprite2D
└── ParallaxLayer  (near — trees)
	└── Sprite2D
```

These must be added **before** `level_generator.gd` spawns tiles so they appear behind the level content. Alternatively give the `ParallaxBackground` a very low `CanvasItem` Z-index.

### Step 2 — Configure each ParallaxLayer

Set `motion_scale` to control scroll speed relative to the camera:

| Layer | motion_scale.x | Effect |
|---|---|---|
| Far (mountains) | 0.05–0.15 | Very slow — distant |
| Mid (hills) | 0.25–0.45 | Medium distance |
| Near (trees) | 0.6–0.8 | Fast — close to camera |

### Step 3 — Make it loop seamlessly

Set `motion_mirroring = Vector2(texture_width_in_pixels, 0)`. The engine will tile the layer automatically as the camera scrolls.

### Step 4 — Tint by distance

For depth atmosphere, add a `CanvasModulate` node and set a bluish-grey color on far layers to simulate atmospheric haze.

### Step 5 — Procedural layer content (advanced)

Generate layer textures at runtime to match the generated level's color palette:

```gdscript
var img = Image.create(2048, 720, false, Image.FORMAT_RGBA8)
# Call img.set_pixel(x, y, color) in a loop to draw your background pattern
var tex = ImageTexture.create_from_image(img)
parallax_sprite.texture = tex
```

---

## 10. How to Add More Menus

### 10.1 Main Menu

1. Create `main_menu.tscn` as a `CanvasLayer` with `Play`, `Settings`, and `Quit` buttons.
2. Create a new entry scene `main.tscn` that routes to the menu:
   ```gdscript
   extends Node
   func _ready():
	   get_tree().change_scene_to_file("res://main_menu.tscn")
   ```
3. Change `project.godot → run/main_scene` to `"res://main.tscn"`.
4. The Play button navigates to the game:
   ```gdscript
   func _on_play_pressed():
	   get_tree().change_scene_to_file("res://leve.tscn")
   ```

### 10.2 Pause Menu

Add a `CanvasLayer` (layer 99) to `leve.tscn`:

```gdscript
extends CanvasLayer

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_cancel"):
		visible = not visible
		get_tree().paused = visible
```

Set `process_mode = PROCESS_MODE_ALWAYS` on the `CanvasLayer` node so it still receives input while the scene tree is paused.

### 10.3 Settings Menu

1. Create `settings_menu.tscn` with sliders for volume, dropdowns for quality presets, and checkboxes for visual options.
2. Persist settings with `ConfigFile`:
   ```gdscript
   var cfg = ConfigFile.new()
   cfg.set_value("audio", "master_volume", slider.value)
   cfg.save("user://settings.cfg")
   ```
3. Load settings in `global.gd::_ready()` and apply them to `AudioServer`, `RenderingServer`, etc.

### 10.4 Connecting menus from Game Over

In `ui.gd`, add a **Main Menu** button and connect it:

```gdscript
func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
```

---

## 11. How to Add a Skill Tree

### 11.1 Skill data model

Create `skill_data.gd` as a `Resource` subclass:

```gdscript
class_name SkillData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 1                      # skill points required to unlock
@export var requires: Array[String] = []       # IDs of prerequisite skills
@export var icon: Texture2D
```

Save one `.tres` file per skill (e.g. `skills/double_jump.tres`, `skills/higher_jump.tres`).

### 11.2 Persistence in global.gd

Add to `global.gd`:

```gdscript
var unlocked_skills: Dictionary = {}   # skill_id -> bool
var skill_points: int = 0

func save_skills() -> void:
	var f = FileAccess.open("user://skills.dat", FileAccess.WRITE)
	f.store_var(unlocked_skills)
	f.store_var(skill_points)
	f.close()

func load_skills() -> void:
	if FileAccess.file_exists("user://skills.dat"):
		var f = FileAccess.open("user://skills.dat", FileAccess.READ)
		unlocked_skills = f.get_var()
		skill_points = f.get_var()
		f.close()
```

Call `Global.load_skills()` from `global.gd::_ready()`.

### 11.3 Applying skill effects

In `player.gd::_ready()`, after `super._ready()`:

```gdscript
if Global.unlocked_skills.get("double_jump", false):
	jumps = 2            # sets the addon's multi-jump count
	_updateData()        # recomputes jumpMagnitude and jump counters

if Global.unlocked_skills.get("higher_jump", false):
	jumpHeight = 3.5
	_updateData()

if Global.unlocked_skills.get("dash", false):
	dashType = 1         # enable horizontal dash in the addon

if Global.unlocked_skills.get("faster_run", false):
	run_speed = 800.0
	maxSpeed = run_speed
	maxSpeedLock = run_speed
```

### 11.4 Skill tree UI

Create `skill_tree.tscn` with `Button` nodes positioned in a tree layout and `Line2D` edges connecting prerequisites to their dependents. On button press:

```gdscript
func _on_skill_button_pressed(skill_id: String) -> void:
	var skill: SkillData = skills_by_id[skill_id]
	if Global.skill_points >= skill.cost and _prerequisites_met(skill):
		Global.skill_points -= skill.cost
		Global.unlocked_skills[skill_id] = true
		Global.save_skills()
		_refresh_all_buttons()

func _prerequisites_met(skill: SkillData) -> bool:
	for req in skill.requires:
		if not Global.unlocked_skills.get(req, false):
			return false
	return true
```

### 11.5 Earning skill points

Track the player's progress and award points at distance milestones. In `level_generator.gd` or a new `score_manager.gd` autoload:

```gdscript
var _last_milestone_tile: int = 0

func _process(_delta) -> void:
	if not player: return
	var dist = int(player.global_position.x / 128)
	if dist > _last_milestone_tile + 50:
		_last_milestone_tile = dist
		Global.skill_points += 1
		Global.save_skills()
```

Show the awarded point with a floating label for feedback:

```gdscript
var lbl = Label.new()
lbl.text = "+1 Skill Point"
lbl.global_position = player.global_position + Vector2(0, -80)
get_tree().current_scene.add_child(lbl)
var tw = create_tween()
tw.tween_property(lbl, "position:y", lbl.position.y - 60, 1.0)
tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
tw.tween_callback(lbl.queue_free)
```

---

## 12. How to Add Custom Particle Effects

### 12.1 The runtime particle pattern

Every existing particle burst is created entirely in code — no `.tscn` files needed:

```gdscript
var poof = CPUParticles2D.new()
poof.emitting = true
poof.one_shot = true
poof.amount = 30
poof.lifetime = 0.6
poof.explosiveness = 0.95       # 1.0 = all particles at once
poof.spread = 180.0             # degrees; 180 = full hemisphere
poof.gravity = Vector2(0, 400)
poof.initial_velocity_min = 100.0
poof.initial_velocity_max = 350.0
poof.scale_amount_min = 5.0
poof.scale_amount_max = 15.0
poof.color = Color(0.4, 0.8, 1.0)
get_parent().add_child(poof)
poof.global_position = global_position
# Auto-free after all particles die:
poof.finished.connect(poof.queue_free)
```

### 12.2 Directional burst (landing dust)

```gdscript
var dust = CPUParticles2D.new()
dust.one_shot = true
dust.amount = 16
dust.lifetime = 0.4
dust.explosiveness = 0.8
dust.spread = 60.0              # narrow upward cone
dust.direction = Vector2(0, -1) # base direction upward
dust.gravity = Vector2(0, 200)
dust.initial_velocity_min = 80.0
dust.initial_velocity_max = 180.0
dust.scale_amount_min = 4.0
dust.scale_amount_max = 10.0
dust.color = Color(0.75, 0.65, 0.5, 0.8)
get_parent().add_child(dust)
dust.global_position = global_position + Vector2(0, 50)
dust.emitting = true
dust.finished.connect(dust.queue_free)
```

The existing `$DustParticles` node on the player is a pre-placed `CPUParticles2D` that gets `restart()` + `emitting = true` triggered on jump and land.

### 12.3 Persistent continuous emitter (running sparks)

For always-on effects while a condition is true, do not use `one_shot`:

```gdscript
var sparks = CPUParticles2D.new()
sparks.amount = 8
sparks.lifetime = 0.3
sparks.one_shot = false
sparks.explosiveness = 0.0        # continuous stream
sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
sparks.emission_sphere_radius = 5.0
sparks.gravity = Vector2(0, 500)
sparks.initial_velocity_min = 40.0
sparks.initial_velocity_max = 100.0
sparks.color = Color(1.0, 0.7, 0.1)
add_child(sparks)
sparks.position = Vector2(0, 50)  # at player feet
```

Toggle `sparks.emitting = is_on_floor() and abs(velocity.x) > 200.0` each frame in `_process()`.

### 12.4 Texture particles

Assign a `Texture2D` to `CPUParticles2D.texture` to use sprite particles instead of colored squares:

```gdscript
sparks.texture = preload("res://assets/spark.png")
```

### 12.5 GPU particles for high-count effects

For effects needing more than ~200 particles, switch to `GPUParticles2D` and a `ParticleProcessMaterial`:

```gdscript
var gpu_poof = GPUParticles2D.new()
var mat = ParticleProcessMaterial.new()
mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
mat.emission_sphere_radius = 10.0
mat.initial_velocity_min = 100.0
mat.initial_velocity_max = 400.0
mat.gravity = Vector3(0, 500, 0)
gpu_poof.process_material = mat
gpu_poof.amount = 500
gpu_poof.one_shot = true
gpu_poof.explosiveness = 0.95
get_parent().add_child(gpu_poof)
gpu_poof.global_position = global_position
gpu_poof.emitting = true
gpu_poof.finished.connect(gpu_poof.queue_free)
```

> Note: `GPUParticles2D` is not available on very old hardware using GL Compatibility. Always provide a `CPUParticles2D` fallback if targeting all GL Compatibility devices.

---

## 13. How to Add a Leaderboard

### 13.1 Create a score manager autoload

Create `score_manager.gd`:

```gdscript
extends Node

var current_score: int = 0
var high_scores: Array = []   # Array of {name: String, score: int}

func _ready() -> void:
	load_scores()

func update_score(player_x: float) -> void:
	current_score = int(player_x / 128)   # convert pixels to tile units

func submit_score(player_name: String) -> void:
	high_scores.append({"name": player_name, "score": current_score})
	high_scores.sort_custom(func(a, b): return a.score > b.score)
	if high_scores.size() > 10:
		high_scores.resize(10)
	save_scores()

func save_scores() -> void:
	var f = FileAccess.open("user://scores.dat", FileAccess.WRITE)
	f.store_var(high_scores)
	f.close()

func load_scores() -> void:
	if FileAccess.file_exists("user://scores.dat"):
		var f = FileAccess.open("user://scores.dat", FileAccess.READ)
		high_scores = f.get_var()
		f.close()
```

Register in `project.godot`:
```ini
[autoload]
Global="*res://global.gd"
ScoreManager="*res://score_manager.gd"
```

### 13.2 Update score in real-time

In `player.gd::_process()`, after `super._process(delta)`:

```gdscript
ScoreManager.update_score(global_position.x)
```

### 13.3 Live HUD score display

In `ui.gd`, add a `Label` to `ui.tscn` and update it each frame:

```gdscript
@onready var score_label: Label = $ScoreLabel

func _process(_delta) -> void:
	score_label.text = str(ScoreManager.current_score) + " m"
```

### 13.4 Local leaderboard display on game over

In `ui.gd::show_game_over()`:

```gdscript
func show_game_over() -> void:
	visible = true
	# Immediately submit with a default name; replace with name-entry UI below
	ScoreManager.submit_score("Player")
	_populate_leaderboard()

func _populate_leaderboard() -> void:
	for child in leaderboard_container.get_children():
		child.queue_free()
	for i in ScoreManager.high_scores.size():
		var row = Label.new()
		var entry = ScoreManager.high_scores[i]
		row.text = "%d. %s — %d m" % [i + 1, entry["name"], entry["score"]]
		leaderboard_container.add_child(row)
```

### 13.5 Name entry before submission

Show a name-entry panel between death and leaderboard:

```gdscript
func show_game_over() -> void:
	visible = true
	name_panel.visible = true      # LineEdit + "OK" button

func _on_confirm_name_pressed() -> void:
	var name = name_line_edit.text.strip_edges().left(12)
	if name.is_empty(): name = "Anonymous"
	ScoreManager.submit_score(name)
	name_panel.visible = false
	_populate_leaderboard()
	leaderboard_panel.visible = true
```

### 13.6 Online leaderboard (advanced)

For a global online leaderboard, POST the score to a backend API using `HTTPRequest`:

```gdscript
func _submit_to_server(player_name: String, score: int) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, headers, body):
		http.queue_free()
		if code == 200:
			print("Score submitted successfully")
	)
	var body = JSON.stringify({"name": player_name, "score": score})
	var headers = ["Content-Type: application/json"]
	http.request("https://your-api.example.com/scores", headers, HTTPClient.METHOD_POST, body)
```

For the **web export**, you can also call a JavaScript function directly via `JavaScriptBridge.eval()` to POST to Firebase Realtime Database, Supabase, or any REST endpoint, avoiding CORS issues that sometimes occur with `HTTPRequest` in browsers.

---

## 14. Debug Toggles Reference

Access via `Global.debug_toggles.get("key", false)` anywhere, or toggle at runtime with the debug overlay checkboxes (visible when `Global.debugText = true` in the Inspector on the Global autoload).

| Key | Default | Effect |
|---|---|---|
| `auto_restart` | `false` | Skips the game-over UI; reloads the scene immediately after death |
| `keep_seed` | `false` | When `auto_restart` is also true, reloads the exact same level seed |
| `show_collisions` | `false` | All `TileObject`, enemy, player, and obstacle scripts draw their collision rectangles in green via `_draw()` / `queue_redraw()` |

**Adding a new debug toggle:**

1. Add it to the dictionary in `global.gd`:
   ```gdscript
   @export var debug_toggles: Dictionary = {
	   "auto_restart":      false,
	   "keep_seed":         false,
	   "show_collisions":   false,
	   "my_new_flag":       false,   # <-- add here
   }
   ```

2. Check it anywhere in the codebase:
   ```gdscript
   if Global.debug_toggles.get("my_new_flag", false):
	   # do debug thing
   ```

3. It automatically appears as a labeled checkbox in the debug overlay — the loop in `player.gd::_setup_debug_ui()` iterates all dictionary keys, so no extra registration is needed.

---

*Document generated from source analysis — June 2026.*
*Update this file whenever the architecture changes significantly.*
