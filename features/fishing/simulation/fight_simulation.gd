class_name FightSimulation
extends RefCounted

var tension: float = 0.0
var line_length: float = 0.0
var fish_force: float = 0.0
var lateral_direction: float = 0.0
var fight_time: float = 0.0
var overload_time: float = 0.0
var slack_time: float = 0.0
var drag_strength: float = 0.55

## Advances only numeric state and the hooked fish; caller applies pond constraints.
func advance(delta: float, angler_position: Vector3, active_fish: FishState, rod_input: Vector2, tuning: FishingTuning) -> void:
 fight_time += delta
 var definition: Resource = active_fish.species
 var reel := maxf(0.0, rod_input.y)
 var release_line := maxf(0.0, -rod_input.y)
 var stamina: float = active_fish.stamina
 # Species-specific surges and rests, scaled by the fish's remaining energy.
 var cycle: float = fmod(fight_time + float(active_fish.id) * 0.37, 7.0)
 var burst: float = 1.35 if cycle < 2.2 else (0.42 if cycle > 4.2 else 0.8)
 var typical_weight: float = (definition.min_weight + definition.max_weight) * 0.5
 var mass_scale: float = clampf(0.75 + active_fish.weight / typical_weight * 0.25, 0.8, 1.4)
 fish_force = definition.pull_strength * (0.28 + stamina * 0.85) * burst * mass_scale
 lateral_direction = sin(fight_time * definition.struggle_frequency + float(active_fish.id))
 var counter: float = clampf(-rod_input.x * lateral_direction, -1.0, 1.0)
 var alignment: float = 0.8 + 0.2 * counter
 line_length = clampf(line_length - reel * tuning.reel_speed * delta + release_line * tuning.release_speed * delta, 0.9, tuning.spool_capacity)
 var relative := Vector2(active_fish.position.x - angler_position.x, active_fish.position.z - angler_position.z)
 var radial: Vector2 = relative.normalized() if relative.length() > 0.01 else Vector2(0, -1)
 var sideways := Vector2(-radial.y, radial.x)
 relative += radial * fish_force * definition.swim_speed * delta
 relative += sideways * lateral_direction * definition.swim_speed * delta * 0.45
 var distance := relative.length()
 var stretch := maxf(0.0, distance - line_length)
 var target := 0.20 + fish_force * 0.36 + reel * 0.36 - release_line * 0.40 + stretch * 0.35 + (1.0 - counter) * 0.035
 tension = lerpf(tension, clampf(target, 0.0, 1.25), 1.0 - exp(-5.0 * delta))
 # The reel's brake can slip under a surge; manual release still matters.
 if tension > 0.82 and drag_strength < 0.95:
  line_length = minf(tuning.spool_capacity, line_length + fish_force * (1.0 - drag_strength) * delta * 1.6)
 if reel > 0 and tension > 0.16 and tension < 0.98:
  distance = maxf(1.0, distance - reel * tuning.reel_speed * (1.0 - stamina * 0.45) * alignment * delta)
 if tension > 0.18:
  distance = minf(distance, line_length + 1.0)
 relative = relative.normalized() * distance
 active_fish.position.x = angler_position.x + relative.x
 active_fish.position.z = angler_position.z + relative.y
 active_fish.position.y = move_toward(active_fish.position.y, maxf(0.08, stamina * 1.6 + sin(fight_time * 1.7) * 0.7), delta * 1.2)
 active_fish.heading = atan2(-relative.x, -relative.y)
 active_fish.stamina = clampf(stamina - delta * (0.018 + tension * 0.04 + fish_force * 0.012) / mass_scale, 0, 1)
