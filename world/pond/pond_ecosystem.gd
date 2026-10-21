class_name PondEcosystem
extends Node

signal fish_biting(fish: RefCounted)
signal population_changed

const FishRecord = preload("res://world/pond/fish_state.gd")
const Catalog = preload("res://data/fish/fish_catalog.gd")
@export var species: Array[Resource] = Catalog.SPECIES.duplicate()
@export_range(3, 120) var population_limit: int = 30
@export var simulation_interval: float = 0.15
@export var restock_interval: float = 45.0
@export var simulation_seed: int = 4207
var fish: Array[RefCounted] = []
var bait_active := false
var bait_position := Vector3.ZERO
var bait_type: StringName = &"worm"
var reserved_fish: RefCounted
var clock := 0.0
var next_id := 1
var restock_clock := 0.0
var accumulator := 0.0
var rng := RandomNumberGenerator.new()
var line_visibility := 1.0

@export var definition: PondDefinition = preload("res://world/pond/default_pond.tres")
var water_bounds: Rect2:
 get:
  return definition.water_bounds
var dock_clearance: Rect2:
 get:
  return definition.dock_clearance

func constrain_to_water(point: Vector3) -> Vector3:
 return definition.constrain_to_water(point)

func can_land_fish(angler: Vector3, fish_position: Vector3, distance: float) -> bool:
 return definition.can_land_fish(angler, fish_position, distance)

func _ready() -> void:
 reset_population(simulation_seed)

func reset_population(seed_value: int) -> void:
 rng.seed = seed_value
 fish.clear()
 reserved_fish = null
 bait_active = false
 next_id = 1
 clock = 0.0
 restock_clock = 0.0
 accumulator = 0.0
 for index in population_limit:
  _spawn(index % species.size(), index)
 population_changed.emit()

func _spawn(species_index: int, slot: int = -1) -> RefCounted:
 var record = FishRecord.new()
 record.id = next_id
 next_id += 1
 record.species = species[species_index]
 record.weight = rng.randf_range(record.species.min_weight, record.species.max_weight)
 var depth: Vector2 = record.species.preferred_depth
 # This population exists before casting; it is never spawned in response to bait.
 record.position = definition.spawn_position(rng, depth, slot)
 record.destination = _destination(record)
 record.hunger = rng.randf_range(0.65, 1.0)
 record.decision_timer = rng.randf_range(3, 8)
 record.surface_timer = rng.randf_range(0, 22)
 fish.append(record)
 return record

func _destination(record: RefCounted) -> Vector3:
 var depths: Vector2 = record.species.preferred_depth
 return definition.roaming_position(rng, record.position, depths)

func set_bait(point: Vector3, kind: StringName) -> void:
 cancel_bait()
 bait_position = point
 bait_type = kind
 bait_active = true

func cancel_bait() -> void:
 bait_active = false
 for record in fish:
  if record.state in [&"approaching", &"inspecting", &"biting"]:
   record.state = &"roaming"
   record.timer = 0.0
 reserved_fish = null

## Move an existing bait without resetting approach/inspection or population.
func move_bait(point: Vector3) -> void:
 if bait_active and reserved_fish == null:
  bait_position = point

func _physics_process(delta: float) -> void:
 accumulator += delta
 while accumulator >= simulation_interval:
  step(simulation_interval)
  accumulator -= simulation_interval

func step(delta: float) -> void:
 clock += delta
 restock_clock += delta
 if restock_clock >= restock_interval:
  restock_clock = 0.0
  if fish.size() < population_limit:
   _spawn(rng.randi_range(0, species.size() - 1))
   population_changed.emit()
 for record in fish:
  if record.state in [&"hooked", &"landed"]:
   continue
  record.caution = maxf(0.0, record.caution - delta * 0.03)
  record.stamina = minf(1.0, record.stamina + delta * (0.03 if record.state == &"resting" else 0.015))
  record.hunger = minf(1.0, record.hunger + delta * 0.004)
  record.surface_timer += delta
  record.decision_timer -= delta
  if record.state == &"biting":
   continue
  var interested: bool = bait_active and reserved_fish == null and record.caution < 0.6 and record.hunger > 0.35 and String(bait_type) in record.species.bait_preferences
  # Distance includes depth. A bottom bait is not instantly visible to surface fish.
  interested = interested and record.position.distance_to(bait_position) <= record.species.detection_radius / maxf(0.5, line_visibility)
  var preferred: Vector2 = record.species.preferred_depth
  interested = interested and bait_position.y >= preferred.x - 0.5 and bait_position.y <= preferred.y + 0.5
  if interested and record.state not in [&"approaching", &"inspecting"]:
   record.state = &"approaching"
   record.timer = 0.0
  if record.state in [&"approaching", &"inspecting"] and bait_active and reserved_fish == null:
   _move_fish(record, bait_position, record.species.swim_speed * delta)
   if record.position.distance_to(bait_position) < 0.35:
    record.state = &"inspecting"
    record.timer += delta
    if record.timer >= 2.2 + (1.0 - record.hunger) * 2.0:
     record.state = &"biting"
     reserved_fish = record
     fish_biting.emit(record)
   else:
    record.state = &"approaching"
    record.timer = 0.0
   continue
  if record.state in [&"approaching", &"inspecting"]:
   record.state = &"roaming"
  if record.decision_timer <= 0.0:
   record.destination = _destination(record)
   record.state = &"resting" if rng.randf() < 0.17 else &"roaming"
   if record.hunger > 0.7 and rng.randf() < 0.22:
    record.state = &"feeding"
   if record.species.id == &"snakehead" and record.hunger > 0.6 and not bait_active:
    for prey in fish:
     if prey.species.id == &"tilapia" and prey.state not in [&"hooked", &"landed", &"biting"] and record.position.distance_to(prey.position) < 6.0:
      record.state = &"hunting"
      record.destination = prey.position
      prey.state = &"fleeing"
      var away: Vector3 = (prey.position - record.position).normalized()
      prey.destination = prey.position + away * 4.0
      prey.destination = constrain_to_water(prey.destination)
      prey.decision_timer = 2.5
      break
   record.decision_timer = rng.randf_range(3, 7)
  if record.state == &"feeding":
   record.hunger = maxf(0.0, record.hunger - delta * 0.055)
  elif record.state != &"resting":
   var speed_factor: float = 0.8 if record.state == &"fleeing" else (0.6 if record.state == &"hunting" else 0.3)
   _move_fish(record, record.destination, record.species.swim_speed * delta * speed_factor)
  if record.surface_timer > 22.0:
   record.position.y = move_toward(record.position.y, 0.12, delta * 1.8)
   if record.surface_timer > 24.0:
    record.surface_timer = 0.0

func _move_fish(record: RefCounted, target: Vector3, distance: float) -> void:
 var previous: Vector3 = record.position
 record.position = constrain_to_water(record.position.move_toward(target, distance))
 var movement: Vector3 = record.position - previous
 if Vector2(movement.x, movement.z).length_squared() > 0.000001:
  record.heading = atan2(-movement.x, -movement.z)

func hook(record: RefCounted) -> void:
 bait_active = false
 reserved_fish = record
 record.state = &"hooked"

func release(record: RefCounted) -> void:
 if record == null:
  return
 record.state = &"roaming"
 record.caution = 1.0
 record.hunger = 0.25
 record.position = constrain_to_water(record.position)
 record.position.y = maxf(record.species.preferred_depth.x, 1.0)
 record.destination = _destination(record)
 reserved_fish = null
 population_changed.emit()

func keep(record: RefCounted) -> void:
 fish.erase(record)
 reserved_fish = null
 population_changed.emit()

func counts() -> Dictionary:
 var result := {}
 for definition in species:
  result[definition.id] = 0
 for record in fish:
  result[record.species.id] += 1
 return result

func boss() -> RefCounted:
 var largest: RefCounted
 for record in fish:
  if largest == null or record.weight > largest.weight:
   largest = record
 return largest

func snapshot() -> Array:
 var records: Array = []
 for record in fish:
  records.append({"id": record.id, "species": String(record.species.id), "weight": record.weight,
   "position": record.position, "stamina": record.stamina, "hunger": record.hunger, "caution": record.caution})
 return records

func restore(records: Array) -> bool:
 var restored: Array[RefCounted] = []
 var ids := {}
 for entry in records:
  if not entry is Dictionary or not entry.get("position") is Vector3:
   return false
  var definition_found: Resource
  for candidate in species:
   if String(candidate.id) == str(entry.get("species", "")):
    definition_found = candidate
  if definition_found == null or not entry.get("id") is int or entry.id <= 0 or ids.has(entry.id):
   return false
  if not is_finite(float(entry.get("weight", 0))) or entry.weight < definition_found.min_weight or entry.weight > definition_found.max_weight or not entry.position.is_finite():
   return false
  var record := FishState.new()
  record.id = entry.id
  ids[entry.id] = true
  record.species = definition_found
  record.weight = entry.weight
  record.position = constrain_to_water(entry.position)
  record.stamina = clampf(float(entry.get("stamina", 1.0)), 0.0, 1.0)
  record.hunger = clampf(float(entry.get("hunger", 0.7)), 0.0, 1.0)
  record.caution = clampf(float(entry.get("caution", 0.0)), 0.0, 1.0)
  record.destination = _destination(record)
  restored.append(record)
 fish = restored
 next_id = 1
 for record in fish:
  next_id = maxi(next_id, record.id + 1)
 reserved_fish = null
 bait_active = false
 population_changed.emit()
 return true
