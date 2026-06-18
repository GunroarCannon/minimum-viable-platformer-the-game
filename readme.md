# Minimum Viable Platformer — Developer Reference Manual

Welcome to the **Minimum Viable Platformer** codebase! This document outlines the design philosophy of the game, explains the architecture of the code, and provides a step-by-step developer's guide for adding new features, hazards, and enemies.

---

## 1. Game Overview

This project is a high-speed, momentum-based auto-running 2D platformer.
- **Auto-Running & Momentum**: The player automatically moves to the right. Momentum/velocity builds up gradually and can be temporarily lost or suppressed by stun triggers (e.g. hitting a bouncer's side).
- **Dynamic Camera Zoom**: The game camera dynamically adjusts its zoom level based on the current context. It supports two modes:
  1. *Hazard Proximity*: Zooms out if a hazard is coming up far ahead.
  2. *Tile Count*: Queries the physics space around the player and zooms out when there are fewer solid tiles visible on screen.
- **Physics Shattering (Tearing)**: When entities (player or monsters) die from any cause other than a fall, they split into 2-5 irregular rigid body shards inheriting their actual visual texture and UV mapping.

---

## 2. Core Codebase Structure

The project has a flat structure in the workspace root, with specialized enemies nested in the `/enemies` subdirectory:

### Root Files
- **[global.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/global.gd)**: Singleton/Autoload script handling automatic InputMap configuration and export parameters for camera zoom modes and debug toggles (`Global.debugText`).
- **[level_generator.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/level_generator.gd)**: Procedural section-based generator. Builds levels dynamically by assembling 2D grid block templates (pattern strings mapping characters to solid tiles, ramps, hazards, and enemies).
- **[player.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/player.gd)**: Coordinates player logic, dynamic screen-query sensors, local column-based lowest tile detection, death triggers, camera reparenting, and the debug text overlay.
- **[tear_effect.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/tear_effect.gd)**: The modular tearing engine. Cuts shapes into irregular polygons, spawns individual `RigidBody2D` instances, maps texture UVs from Sprite nodes, and tweens their fade out.
- **[tile_object.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/tile_object.gd)**: Controls the standard block footprint, scaling, landing squash juice, and procedural visual rectangle drawing.
- **[smasher.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/smasher.gd)**: Falling trap. Employs one-way top collision allowing safe landing while crushing anything beneath it.
- **[spike.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/spike.gd)**: Ground hazard. Kills player and non-bullet enemies with tearing physics.

### Enemies Directory (`/enemies`)
- **[base_enemy.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/base_enemy.gd)**: Core template for monsters. Sets default collision layers, handles side-contact player kills, and hosts the modular `die()` and `die_torn()` methods.
- **[frog.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/frog.gd)** / **[big_frog.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/big_frog.gd)**: Standard leaping hazards.
- **[bat.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/bat.gd)**: Gravity-immune floating hazard.
- **[kobold.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/kobold.gd)**: Ground patrol hazard.
- **[rock.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/rock.gd)**: Side knockback bouncer that launches stompers upwards and throws other enemies sideways.
- **[bullet.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/bullet.gd)**: Projectile hazard that moves horizontally, dies on wall impact, and shatters other enemies into rectangular logs.
- **[drill.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/drill.gd)**: Excavator enemy that falls straight down, chewing through blocks and entities.
- **[jumper.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/enemies/jumper.gd)**: Low-hop hazard that catapults stompers with an extremely high vertical velocity kick.

---

## 3. The Tearing System

Tearing breaks a node into physical shards using CSG/Geometry polygon intersection tools:
1. **Shading & Texture Mapping**: `TearEffect.apply()` inspects children for `Sprite2D` or `AnimatedSprite2D`. If found, it maps the coordinate coordinates to coordinate UVs on the generated shards. If not, it uses flat colors modulated by random shade offsets.
2. **Tearing Types**:
   - `default`: Irregular shards built from a jagged bounding box.
   - `circular`: Starburst shards built from a circle polygon approximation.
   - `logs`: Parallel horizontal cuts creating logs.

---

## 4. How to Add a New Enemy

To add a new enemy type to the project, follow this modular workflow:

### Step 1: Create the Script
Create a new GDScript in `res://enemies/` (e.g. `res://enemies/crawler.gd`). Inherit from `BaseEnemy`:
```gdscript
extends BaseEnemy

@export var crawl_speed: float = 100.0
var direction: int = -1

func _ready() -> void:
	super._ready() # Sets layers/hitbox
	tear_size = Vector2(64, 64)
	tear_color = Color(0.8, 0.4, 0.1)
	tear_type = "default" # "default", "circular", or "logs"
	
func _custom_process(delta: float) -> void:
	# Custom movement logic
	velocity.x = direction * crawl_speed
	if is_on_wall():
		direction *= -1
```

### Step 2: Create the Scene
1. Create a scene `res://enemies/crawler.tscn` with a `CharacterBody2D` root.
2. Attach your new script.
3. Add a `CollisionShape2D` (body) and an `Area2D` named `Hitbox` containing another `CollisionShape2D` (for player/sensor overlap).

### Step 3: Register in the Level Generator
Open [level_generator.gd](file:///c:/Users/hmmm/Documents/minimum-viable-platformer/level_generator.gd):
1. **Preload the Scene**:
   ```gdscript
   @export var crawler_scene: PackedScene = preload("res://enemies/crawler.tscn")
   ```
2. **Add to Spawner**: In `_spawn_entity(id, world_pos)`, add your match branch:
   ```gdscript
   "crawler": inst = crawler_scene.instantiate()
   ```
3. **Define a Template Char**: Add pattern templates to `TEMPLATES` mapping a key char to `"crawler"`, for example:
   ```gdscript
   { "pattern": ["........", "...c....", "########"], "c": "crawler" }
   ```
