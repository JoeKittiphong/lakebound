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
var yellow_start: float = 0.28
var red_start: float = 0.50
var activity: float = 1.0
var surge_active: bool = false
var yellow_width: float = 0.12
var _fish: FishState
var _rng := RandomNumberGenerator.new()
var _width_roll: float = 1.0
var _surge_remaining: float = 0.0
var _surge_wait: float = 4.0
var _surge_strength: float = 2.0
var line_strength: float = 5.0
## Estimated instantaneous load in kgf, compared with the equipped line rating.
var line_load_kgf: float = 0.0
var rod_strength: float = 5.0

func begin(fish: FishState) -> void:
 _fish = fish
 _rng.seed = fish.id * 7919 + int(round(fish.weight * 1000.0)) + String(fish.species.id).hash()
 _width_roll = _rng.randf_range(0.8, 1.05)
 _surge_remaining = 0.0
 _surge_wait = _rng.randf_range(3.0, 6.0)
 surge_active = false

func _advance_surges(delta: float, fish: FishState) -> void:
 if _surge_remaining > 0.0:
  _surge_remaining = maxf(0.0, _surge_remaining - delta)
 else:
  _surge_wait -= delta
  if _surge_wait <= 0.0:
   _surge_remaining = _rng.randf_range(0.65, 1.05)
   _surge_strength = _rng.randf_range(1.5, 2.7)
   var difficulty := clampf(fish.species.fight_pressure(fish.weight) / 0.24, 0.0, 1.0)
   _surge_wait = _rng.randf_range(3.5, 6.0) - difficulty
 surge_active = _surge_remaining > 0.0

func update_zones(fish: FishState) -> void:
 if _fish != fish:
  begin(fish)
 var cycle := fmod(fight_time + float(fish.id) * 0.37, 7.0)
 activity = 1.35 if cycle < 2.2 else (0.42 if cycle > 4.2 else 0.8)
 if surge_active:
  activity = _surge_strength
 var zones := fish.species.fight_zones(fish.weight, fish.stamina, activity)
 red_start = zones.y
 yellow_width = clampf((zones.y - zones.x) * _width_roll, 0.18, red_start - 0.16)
 yellow_start = maxf(0.16, red_start - yellow_width)

## Advances only numeric state and the hooked fish; caller applies pond constraints.
func advance(delta: float, angler_position: Vector3, active_fish: FishState, rod_input: Vector2, tuning: FishingTuning) -> void:
 fight_time += delta
 if _fish != active_fish:
  begin(active_fish)
 _advance_surges(delta, active_fish)
 update_zones(active_fish)
 var definition: Resource = active_fish.species
 var reel := maxf(0.0, rod_input.y)
 var release_line := maxf(0.0, -rod_input.y)
 var stamina: float = active_fish.stamina
 # Species-specific surges and rests, scaled by the fish's remaining energy.
 var burst := activity
 var typical_weight: float = (definition.min_weight + definition.max_weight) * 0.5
 var mass_scale: float = clampf(0.75 + active_fish.weight / typical_weight * 0.25, 0.8, 1.4)
 fish_force = definition.pull_strength * (0.28 + stamina * 0.85) * burst * mass_scale
 lateral_direction = sin(fight_time * definition.struggle_frequency + float(active_fish.id))
 var counter: float = clampf(-rod_input.x * lateral_direction, -1.0, 1.0)
 var alignment: float = 0.8 + 0.2 * counter
 line_length = clampf(line_length - reel * tuning.reel_speed * delta + release_line * tuning.release_speed * delta, 0.9, tuning.spool_capacity)
 var relative := Vector2(active_fish.position.x - angler_position.x, active_fish.position.z - angler_position.z)
 var previous_distance := relative.length()
 var radial: Vector2 = relative.normalized() if relative.length() > 0.01 else Vector2(0, -1)
 var sideways := Vector2(-radial.y, radial.x)
 relative += radial * fish_force * definition.swim_speed * delta
 relative += sideways * lateral_direction * definition.swim_speed * delta * 0.45
 var distance := relative.length()
 var stretch := maxf(0.0, distance - line_length)
 # Fish mass alone is not line load: surges, cranking against the fish and
 # stretch add force; paying out and the reel brake relieve it. Keep units
 # independent of the gameplay control band's moving red/yellow boundaries.
 line_load_kgf = active_fish.weight * (0.25 + fish_force * 0.35 + reel * 0.65 + stretch * 0.18 + (1.0 - counter) * 0.04)
 line_load_kgf *= (1.0 - release_line * 0.70) * lerpf(0.65, 1.0, clampf(drag_strength, 0.0, 1.0))
 var load_offset := (fish_force - 0.6) * 0.16 + stretch * 0.18
 load_offset += active_fish.species.fight_pressure(active_fish.weight) * burst * stamina * 0.18
 # Gear changes load tolerance, never grants a catch. Fast reels still raise
 # tension; heavy rods damp surges but are less responsive to lateral input.
 load_offset += clampf((line_load_kgf / maxf(line_strength, 0.1) - 0.65) * 0.30, -0.08, 0.24)
 load_offset -= maxf(0.0, rod_strength - 5.0) * burst * 0.004
 if previous_distance >= tuning.spool_capacity - 0.2:
  load_offset += 0.12
 # Keep environmental load within the player's control range. Previously a
 # strong surge (or the end-of-spool override in the controller) could pin red
 # even with full payout, so no gesture could recover before the break timer.
 var target := (yellow_start + red_start) * 0.5 + clampf(load_offset, -0.10, 0.32)
 target += reel * 0.28 - release_line * 0.65 + (1.0 - counter) * 0.02
 alignment *= clampf(5.0 / maxf(rod_strength, 5.0), 0.7, 1.0)
 tension = lerpf(tension, clampf(target, 0.0, 1.25), 1.0 - exp(-5.0 * delta))
 # The reel's brake can slip under a surge; manual release still matters.
 var in_yellow := tension >= yellow_start and tension < red_start
 var in_green := tension >= 0.15 and tension < yellow_start
 if tension >= red_start and drag_strength < 0.95:
  line_length = minf(tuning.spool_capacity, line_length + fish_force * (1.0 - drag_strength) * delta * 0.8)
 if in_green:
  distance += definition.swim_speed * (0.7 + stamina * 1.8) * delta
  line_length = minf(tuning.spool_capacity, maxf(line_length, distance - 0.5))
 if in_yellow:
  # Yellow is always progress: cancel the outward surge displacement first,
  # then steadily bring the fish closer even while holding the reel neutral.
  var retrieve_rate := (0.35 + reel * 0.65) * tuning.reel_speed * tuning.yellow_retrieve_multiplier * (1.0 - stamina * 0.45) * alignment
  distance = maxf(1.0, previous_distance - retrieve_rate * delta)
  line_length = minf(line_length, distance + 0.3)
 if tension >= yellow_start:
  distance = minf(distance, line_length + 1.0)
 relative = relative.normalized() * distance
 active_fish.position.x = angler_position.x + relative.x
 active_fish.position.z = angler_position.z + relative.y
 active_fish.position.y = move_toward(active_fish.position.y, maxf(0.08, stamina * 1.6 + sin(fight_time * 1.7) * 0.7), delta * 1.2)
 active_fish.heading = atan2(-relative.x, -relative.y)
 var fatigue_rate := (0.024 + fish_force * 0.012) * (1.8 if in_yellow else 0.20)
 active_fish.stamina = clampf(stamina - delta * fatigue_rate / mass_scale, 0, 1)
