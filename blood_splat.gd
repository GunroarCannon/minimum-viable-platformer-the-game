extends Node
class_name BloodSplat

## Spawns a one-shot blood-particle burst at `pos`, parented to `parent`.
## No-op if the player hasn't bought the "blood_splats" skill.
##
## `velocity` lets the splatter trail away from the impact direction.

static func apply(parent: Node, pos: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	if not Global.is_unlocked("blood_splats"): return
	if parent == null or not parent.is_inside_tree(): return

	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = 32
	p.lifetime = 0.75
	p.explosiveness = 0.95
	p.spread = 60.0
	# Splatter trails AWAY from velocity (opposite direction).
	if velocity.length_squared() > 1.0:
		p.direction = -velocity.normalized()
	else:
		p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, 900)
	p.initial_velocity_min = 240.0
	p.initial_velocity_max = 560.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 16.0
	p.damping_min = 12.0
	p.damping_max = 28.0
	p.color = Color(0.78, 0.10, 0.10)

	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.12, 0.12, 1.0))
	ramp.add_point(0.55, Color(0.55, 0.06, 0.06, 1.0))
	ramp.add_point(1.0, Color(0.28, 0.04, 0.04, 0.0))
	p.color_ramp = ramp

	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)

	# A second, fast, narrow plume for the wet "spurt" feel.
	var spurt := CPUParticles2D.new()
	spurt.emitting = true
	spurt.one_shot = true
	spurt.amount = 12
	spurt.lifetime = 0.45
	spurt.explosiveness = 1.0
	spurt.spread = 25.0
	spurt.direction = p.direction
	spurt.gravity = Vector2(0, 600)
	spurt.initial_velocity_min = 520.0
	spurt.initial_velocity_max = 860.0
	spurt.scale_amount_min = 4.0
	spurt.scale_amount_max = 9.0
	spurt.color = Color(0.90, 0.15, 0.15)
	parent.add_child(spurt)
	spurt.global_position = pos
	spurt.finished.connect(spurt.queue_free)
