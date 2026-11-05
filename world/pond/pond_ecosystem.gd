class_name PondEcosystem
extends Node

signal fish_biting(fish: RefCounted)
signal population_changed

const FishRecord = preload("res://world/pond/fish_state.gd")
const Catalog = preload("res://data/fish/fish_catalog.gd")
@export var species: Array[Resource] = Catalog.SPECIES.duplicate()
@export_range(3, 2000) var population_limit: int = 30
@export var simulation_interval: float = 0.15
@export var simulation_observer: Node3D
@export var full_rate_radius:=95.0
@export var distant_simulation_interval:=.9
@export var population_expansion_revision: String=""
@export var population_expansion_count:=0
@export var population_expansion_species_offset:=0
@export var restock_interval: float = 45.0
@export var simulation_seed: int = 4207
var fish: Array[RefCounted] = []
var bait_active := false
var bait_item:TackleItem
@export var default_attraction_radius:=7.0
@export var natural_commit_seconds:=1.1
@export var lure_commit_seconds:=.45
## Temporary, capped detection bonus earned by a lure rhythm; never forces a bite.
var lure_appeal := 0.0
var lure_controlled := false
var lure_followers := 0
var lure_strike_fish: RefCounted
var lure_strike_until := -1.0
var lure_strike_chance := 0.0
var lure_interest := 0.0
@export_range(0.5, 3.0) var lure_attack_distance := 1.8
var bait_position := Vector3.ZERO
var bait_type: StringName = &"worm"
var reserved_fish: RefCounted
var clock := 0.0
var next_id := 1
var restock_clock := 0.0
var accumulator := 0.0
var rng := RandomNumberGenerator.new()
## Match-only identity/metadata stream; movement and bite decisions stay independent.
var shared_population_seed := -1
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
 lure_controlled = false
 lure_followers = 0
 invalidate_lure_action()
 for index in population_limit:
  _spawn(index % species.size(), index)
 population_changed.emit()

func expand_population(additional_count: int) -> void:
 var amount:=mini(maxi(0,additional_count),maxi(0,population_limit-fish.size()))
 var start_slot:=fish.size()
 for index in amount:_spawn((population_expansion_species_offset+index)%species.size(),start_slot+index)
 population_changed.emit()

func _spawn(species_index: int, slot: int = -1) -> RefCounted:
 var record = FishRecord.new()
 record.id = next_id
 next_id += 1
 var spawn_rng := rng
 if shared_population_seed>=0:
  spawn_rng=RandomNumberGenerator.new()
  spawn_rng.seed=(str(shared_population_seed)+":"+str(record.id)).hash()
  species_index=(record.id-1)%species.size()
  record.persistent_key=(str(shared_population_seed)+":"+str(record.id)).md5_text()
 record.species = species[species_index]
 record.weight = spawn_rng.randf_range(record.species.min_weight, record.species.max_weight)
 var depth: Vector2 = record.species.preferred_depth
 # This population exists before casting; it is never spawned in response to bait.
 record.position = definition.spawn_position(spawn_rng, depth, slot)
 record.destination = definition.roaming_position(spawn_rng,record.position,depth)
 record.hunger = spawn_rng.randf_range(0.65, 1.0)
 record.decision_timer = spawn_rng.randf_range(3, 8)
 record.surface_timer = spawn_rng.randf_range(0, 22)
 fish.append(record)
 return record

func _destination(record: RefCounted) -> Vector3:
 var depths: Vector2 = record.species.preferred_depth
 return definition.roaming_position(rng, record.position, depths)

func set_bait(point: Vector3, kind: StringName, requires_lure_rhythm: bool = false, item:TackleItem = null) -> void:
 cancel_bait()
 bait_position = point
 bait_type = kind
 bait_item = item
 bait_active = true
 lure_controlled = requires_lure_rhythm

func cancel_bait() -> void:
 bait_active = false
 bait_item = null
 lure_appeal = 0.0
 lure_controlled = false
 lure_followers = 0
 invalidate_lure_action()
 for record in fish:
  if record.state in [&"approaching", &"inspecting", &"biting", &"chasing_lure", &"committed"]:
   record.state = &"roaming"
   record.timer = 0.0
 reserved_fish = null

func invalidate_lure_action() -> void:
 if lure_controlled:
  for record in fish:
   if record.state==&"committed":record.state=&"chasing_lure";record.timer=0.0
 lure_interest = 0.0
 lure_strike_fish = null
 lure_strike_until = -1.0
 lure_strike_chance = 0.0

func register_lure_action(quality: float, _duration: float = 2.5, _bite_chance: float = 0.78) -> void:
 if not bait_active or not lure_controlled or reserved_fish != null:
  return
 lure_interest = clampf(quality, 0.0, 1.0)
 lure_appeal = 0.2
 # Progress persists for this cast until a wrong direction or a state reset.
 lure_strike_until = INF
 lure_strike_chance = 1.0 if lure_interest >= 1.0 else lure_interest * 0.55

## Use current positions and the same conditions as simulation, not stale follower counts.
func _interested_in_bait(record: RefCounted) -> bool:
 if not record.available_for_bait or record.state in [&"hooked", &"landed"] or not bait_active or reserved_fish != null:
  return false
 if record.caution >= 0.6 or record.hunger <= 0.35 or String(bait_type) not in record.species.bait_preferences:
  return false
 var depths: Vector2 = record.species.preferred_depth
 return record.position.distance_to(bait_position) <= fish_detection_radius(record) and bait_position.y >= depths.x - 0.5 and bait_position.y <= depths.y + 0.5

func has_lure_candidate() -> bool:
 for record in fish:
  if _interested_in_bait(record):
   return true
 return false

func lure_status() -> String:
 if reserved_fish != null:
  return "ปลากัดแล้ว!"
 if has_lure_candidate():
  if lure_interest >= 1.0:
   return "ปลากำลังตาม • เต็มหลอดแล้ว รอปลาเข้าถึง"
  return "ปลากำลังตาม • ทำสูตรต่อเพื่อเพิ่มโอกาสกัด"
 var nearby := false
 var compatible := false
 var depth_ok := false
 for record in fish:
  if not record.available_for_bait or record.state in [&"hooked", &"landed"]:
   continue
  if record.position.distance_to(bait_position) > maxf(attraction_radius(),fish_detection_radius(record)):
   continue
  nearby = true
  if String(bait_type) not in record.species.bait_preferences:
   continue
  compatible = true
  var depths: Vector2 = record.species.preferred_depth
  if bait_position.y >= depths.x - 0.5 and bait_position.y <= depths.y + 0.5:
   depth_ok = true
 if not nearby:
  return "ยังไม่มีปลาใกล้เหยื่อ • ลองเปลี่ยนจุดเหวี่ยง"
 if not compatible:
  return "ปลาใกล้ ๆ ไม่สนใจเหยื่อนี้ • ลองเปลี่ยนเหยื่อ"
 if not depth_ok:
  return "เหยื่ออยู่ผิดระดับปลา • ลองปรับความลึก"
 return "ปลายังระแวงหรือไม่หิว • รอหรือเปลี่ยนจุด"

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
 lure_appeal = maxf(0.0, lure_appeal - delta * 0.05)
 lure_followers = 0
 if clock > lure_strike_until:
  invalidate_lure_action()
 restock_clock += delta
 if shared_population_seed<0 and restock_clock >= restock_interval:
  restock_clock = 0.0
  if fish.size() < population_limit:
   _spawn(rng.randi_range(0, species.size() - 1))
   population_changed.emit()
 for record in fish:
  if record.state in [&"hooked", &"landed"]:
   continue
  var fish_delta:=delta
  if is_instance_valid(simulation_observer):
   var near:=Vector2(record.position.x-simulation_observer.global_position.x,record.position.z-simulation_observer.global_position.z).length_squared()<=full_rate_radius*full_rate_radius
   var relevant_bait: bool=bait_active and record.position.distance_squared_to(bait_position)<=pow(maxf(25,attraction_radius()+5),2)
   if not near and not relevant_bait and record.state not in [&"approaching",&"inspecting",&"biting",&"chasing_lure", &"committed"]:
    record.simulation_elapsed+=delta
    if record.simulation_elapsed<distant_simulation_interval:continue
    fish_delta=record.simulation_elapsed;record.simulation_elapsed=0
   else:
    fish_delta+=record.simulation_elapsed;record.simulation_elapsed=0
  record.caution = maxf(0.0, record.caution - fish_delta * 0.03)
  record.stamina = minf(1.0, record.stamina + fish_delta * (0.03 if record.state == &"resting" else 0.015))
  record.hunger = minf(1.0, record.hunger + fish_delta * 0.004)
  record.surface_timer += fish_delta
  record.decision_timer -= fish_delta
  if record.state == &"biting":
   continue
  var interested := _interested_in_bait(record)
  if interested and record.state not in [&"approaching", &"inspecting", &"chasing_lure", &"committed"]:
   record.state = &"chasing_lure" if lure_controlled else &"approaching"
   record.timer = 0.0
  if interested and lure_controlled:
   if record.state!=&"committed":record.state = &"chasing_lure"
   lure_followers += 1
   _move_fish(record, bait_position, record.species.swim_speed * fish_delta)
   if record.position.distance_to(bait_position) < 0.65 and lure_interest > 0.0:
    lure_strike_fish = record
    record.timer += fish_delta
    if record.state!=&"committed" and record.timer+.00001>=lure_commit_seconds:
     if rng.randf()<lure_strike_chance:record.state=&"committed"
     else:record.timer=0.0
    if record.state==&"committed" and record.timer>=.7:
     record.state=&"biting"
     reserved_fish=record
     fish_biting.emit(record)
   else:
    record.state=&"chasing_lure"
    record.timer = 0.0
   continue
  if interested and record.state in [&"approaching", &"inspecting", &"committed"] and bait_active and reserved_fish == null:
   _move_fish(record, bait_position, record.species.swim_speed * fish_delta)
   if record.position.distance_to(bait_position) < 0.35:
    if record.state!=&"committed":record.state = &"inspecting"
    record.timer += fish_delta
    if record.timer>=natural_commit_seconds:record.state=&"committed"
    if record.timer >= 2.2 + (1.0 - record.hunger) * 2.0:
     record.state = &"biting"
     reserved_fish = record
     fish_biting.emit(record)
   else:
    record.state = &"approaching"
    record.timer = 0.0
   continue
  if record.state in [&"approaching", &"inspecting", &"chasing_lure", &"committed"]:
   record.state = &"roaming"
   record.timer = 0.0
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
   record.hunger = maxf(0.0, record.hunger - fish_delta * 0.055)
  elif record.state != &"resting":
   var speed_factor: float = 0.8 if record.state == &"fleeing" else (0.6 if record.state == &"hunting" else 0.3)
   _move_fish(record, record.destination, record.species.swim_speed * fish_delta * speed_factor)
  if record.surface_timer > 22.0:
   record.position.y = move_toward(record.position.y, 0.12, fish_delta * 1.8)
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
 invalidate_lure_action()
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
 for species_definition in species:
  result[species_definition.id] = 0
 for record in fish:
  result[record.species.id] += 1
 return result

func boss() -> RefCounted:
 var largest: RefCounted = null
 for record in fish:
  if largest == null or record.weight > largest.weight:
   largest = record
 return largest

func snapshot() -> Array:
 var records: Array = []
 for record in fish:
  records.append({"id": record.id, "persistent_key": record.persistent_key, "species": String(record.species.id), "weight": record.weight,
   "position": record.position, "stamina": record.stamina, "hunger": record.hunger, "caution": record.caution})
  if definition is RainforestLakeDefinition:
   records[-1]["habitat_revision"]="rainforest_lake_v1"
   records[-1]["cave_habitat_seeded"]=definition.cave_enabled
 return records

func restore(records: Array) -> bool:
 var cave_seed_start:=maxi(0,records.size()-mini(14,maxi(1,floori(records.size()/8.0))))
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
  # Legacy populations get a deterministic identity on migration. New fish use
  # random persistent keys, so recycled numeric IDs cannot block new catches.
  if entry.has("persistent_key") and (not entry.persistent_key is String or entry.persistent_key.is_empty()):
   return false
  record.persistent_key = entry.get("persistent_key", ("%s:%d:%.17f" % [entry.species, entry.id, entry.weight]).sha256_text())
  ids[entry.id] = true
  record.species = definition_found
  record.weight = entry.weight
  record.position = constrain_to_water(entry.position)
  if definition is RainforestLakeDefinition and entry.get("habitat_revision","")!="rainforest_lake_v1":
   # Preserve fish identity/weight/progress while relocating legacy river positions once.
   record.position=definition.spawn_position(rng,record.species.preferred_depth,restored.size())
  if definition is RainforestLakeDefinition and definition.cave_enabled and not bool(entry.get("cave_habitat_seeded",false)) and restored.size()>=cave_seed_start:
   # Populate the new cave once while retaining each fish's identity, species and weight.
   record.position=definition.spawn_cave_position(rng,record.species.preferred_depth)
  record.stamina = clampf(float(entry.get("stamina", 1.0)), 0.0, 1.0)
  record.hunger = clampf(float(entry.get("hunger", 0.7)), 0.0, 1.0)
  record.caution = clampf(float(entry.get("caution", 0.0)), 0.0, 1.0)
  record.destination = _destination(record)
  restored.append(record)
 fish = restored
 lure_controlled = false
 lure_followers = 0
 invalidate_lure_action()
 next_id = 1
 for record in fish:
  next_id = maxi(next_id, record.id + 1)
 reserved_fish = null
 bait_active = false
 population_changed.emit()
 return true

## Outer radius shown on water; fish senses can reduce, never expand, this boundary.
func attraction_radius()->float:
 var base:=bait_item.attraction.radius_m if bait_item!=null and bait_item.attraction!=null else default_attraction_radius
 return base*(1.0+clampf(lure_appeal,0,.2) if lure_controlled else 1.0)
func fish_detection_radius(record:RefCounted)->float:
 return minf(attraction_radius(),record.species.detection_radius/maxf(.5,line_visibility))
func bait_interest_status()->Dictionary:
 var status:={"active":bait_active,"radius_m":attraction_radius(),"phase":"waiting","interested_count":0}
 if not bait_active:return status
 if reserved_fish!=null and reserved_fish.state==&"biting":
  status.phase="committed";status.interested_count=1;return status
 for record in fish:
  if not _interested_in_bait(record):continue
  status.interested_count+=1
  if record.state==&"committed":status.phase="committed"
  elif status.phase!="committed":status.phase="interested"
 return status
