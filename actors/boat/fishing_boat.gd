class_name FishingBoat
extends CharacterBody3D

enum Mode { MOORED, DRIVING, FISHING }
@export var pond: Pond
@export var speed: float = 8.0
@export var acceleration: float = 3.5
@export var turn_speed: float = 1.25
@export var boarding_distance: float = 6.5
@export var minimum_depth: float = 0.4
@export var shore_exit_radius: float = 7.0
@export_range(2.5, 6.0) var water_exit_radius := 3.5
@export var deck_bounds := Rect2(-0.85,-1.85,1.7,3.25)
@export var deck_walk_speed := 1.8
@export var deck_obstacles: Array[Rect2] = [Rect2(-.32,-.20,.64,.65)]
var deployed := true
var deck_position := Vector3.ZERO
var water_exit_point := Vector3.INF
@onready var driver_anchor: Marker3D = $DriverAnchor
@onready var fishing_anchor: Marker3D = $FishingAnchor
var mode := Mode.MOORED
var passenger: AnglerPlayer
var drive_input := Vector2.ZERO
var forward_speed := 0.0
var exit_point := Vector3.INF
var _exit_clock := 0.0

func can_board(player: AnglerPlayer) -> bool:
 return deployed and passenger == null and player.input_enabled and not player.fishing_active and Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() <= boarding_distance and absf(player.global_position.y - global_position.y) < 2.5

func board(player: AnglerPlayer) -> bool:
 if not can_board(player):
  return false
 passenger = player
 add_collision_exception_with(player)
 player.embark(self)
 start_driving()
 return true

func start_driving() -> void:
 if passenger == null:
  return
 mode = Mode.DRIVING
 drive_input = Vector2.ZERO
 passenger.character_model.aiming = false
 passenger.character_model.driving = true
 $DriverClearance.set_deferred("disabled", false)
 $StandingClearance.set_deferred("disabled", true)
 _sync_passenger()

func can_stand_to_fish() -> bool:
 if passenger == null:
  return false
 var clearance: CollisionShape3D = $StandingClearance
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = clearance.shape
 query.transform = clearance.global_transform
 query.exclude = [get_rid(), passenger.get_rid()]
 query.collision_mask = 1
 return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func start_fishing() -> void:
 if not can_stand_to_fish():
  return
 mode = Mode.FISHING
 deck_position = fishing_anchor.position
 drive_input = Vector2.ZERO
 forward_speed = 0.0
 velocity = Vector3.ZERO
 passenger.character_model.driving = false
 passenger.character_model.aiming = true
 $DriverClearance.set_deferred("disabled", true)
 $StandingClearance.set_deferred("disabled", false)
 _sync_passenger()

func _physics_process(delta: float) -> void:
 if pond == null or not deployed:
  return
 var definition := pond.definition
 var desired := -drive_input.y * speed if mode == Mode.DRIVING else 0.0
 forward_speed = move_toward(forward_speed, desired, acceleration * delta)
 if mode == Mode.DRIVING and drive_input.length() > 0.05:
  rotation.y -= drive_input.x * turn_speed * delta
 var travel := -global_basis.z * forward_speed
 var candidate := global_position + travel * delta
 var bounded := definition.constrain_travel(candidate)
 if candidate.distance_to(bounded) > 0.01 or definition.water_depth_at(Vector2(candidate.x, candidate.z)) < minimum_depth:
  travel = Vector3.ZERO
  forward_speed = 0.0
 velocity = travel
 move_and_slide()
 global_position.y = definition.surface_height()
 _sync_passenger()
 _exit_clock -= delta
 if passenger != null and _exit_clock <= 0.0:
  _exit_clock = 0.3
  water_exit_point = find_water_exit()
  var shore := find_shore_exit()
  exit_point = shore if shore.is_finite() else water_exit_point

func _sync_passenger() -> void:
 if passenger == null:
  return
 passenger.global_position = driver_anchor.global_position if mode == Mode.DRIVING else to_global(deck_position)
 passenger.velocity = Vector3.ZERO
 if mode == Mode.DRIVING:
  passenger.visual.global_rotation.y = global_rotation.y

func find_shore_exit() -> Vector3:
 if passenger == null or pond == null:
  return Vector3.INF
 var definition := pond.definition as RiverDefinition
 if definition == null:
  return Vector3.INF
 var shape := passenger.get_node("CollisionShape3D") as CollisionShape3D
 for radius in [3.5, 5.0, shore_exit_radius]:
  for index in 16:
   var angle := TAU * float(index) / 16.0
   var point: Vector3 = global_position + Vector3(cos(angle), 0, sin(angle)) * radius
   if definition.water_depth_at(Vector2(point.x, point.z)) > 0.6 or not definition.walking_bounds.has_point(Vector2(point.x, point.z)):
    continue
   var cave_landing: bool=definition is RainforestLakeDefinition and definition.in_cave_area(Vector2(point.x,point.z))
   if cave_landing and definition.signed_water_distance(Vector2(point.x,point.z))<1.0:continue
   point.y = definition.ground_height(Vector2(point.x, point.z)) + 0.08
   if cave_landing:
    var floor_query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,definition.surface_height()+5,point.z),point-Vector3.UP*4)
    floor_query.exclude=[get_rid(),passenger.get_rid()]
    var floor_hit:=get_world_3d().direct_space_state.intersect_ray(floor_query)
    if floor_hit.is_empty() or floor_hit.normal.y<.65 or floor_hit.position.y<definition.surface_height()+.08:continue
    point.y=floor_hit.position.y+.08
   var query := PhysicsShapeQueryParameters3D.new()
   query.shape = shape.shape
   query.transform = Transform3D(Basis.IDENTITY, point + shape.position)
   query.exclude = [get_rid(), passenger.get_rid()]
   query.collision_mask = 1
   if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
    return point
 return Vector3.INF

func disembark() -> bool:
 var point := find_exit()
 if not point.is_finite() or passenger == null:
  return false
 var player := passenger
 passenger = null
 mode = Mode.MOORED
 forward_speed = 0.0
 drive_input = Vector2.ZERO
 velocity = Vector3.ZERO
 remove_collision_exception_with(player)
 $DriverClearance.set_deferred("disabled", true)
 $StandingClearance.set_deferred("disabled", true)
 player.disembark(point)
 return true

func find_exit() -> Vector3:
 var shore := find_shore_exit()
 return shore if shore.is_finite() else find_water_exit()

func find_water_exit() -> Vector3:
 if passenger == null or pond == null: return Vector3.INF
 var shape := passenger.get_node("CollisionShape3D") as CollisionShape3D
 var definition := pond.definition
 # Start alongside the hull; other directions handle bridges and obstructions.
 for radius in [water_exit_radius, water_exit_radius + 1.0]:
  for index in 8:
   var angle := global_rotation.y + TAU * float(index) / 8.0
   var point: Vector3 = global_position + Vector3(cos(angle), 0, sin(angle)) * radius
   point.y = definition.surface_height() - passenger.swim_float_depth
   if not definition.can_swim_at(point) or definition.constrain_travel(point).distance_to(point) > 0.05: continue
   var query := PhysicsShapeQueryParameters3D.new()
   query.shape = shape.shape
   query.transform = Transform3D(Basis.IDENTITY, point + shape.position)
   query.exclude = [passenger.get_rid()]
   query.collision_mask = passenger._saved_collision_mask
   if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return point
 return Vector3.INF

func set_deployed(active: bool) -> void:
 deployed = active
 visible = active
 collision_layer = 1 if active else 0
 collision_mask = 1 if active else 0
 set_physics_process(active)
 drive_input = Vector2.ZERO
 velocity = Vector3.ZERO
 forward_speed = 0
 if not active:
  mode = Mode.MOORED
  exit_point = Vector3.INF
  water_exit_point = Vector3.INF

func apply_spec(spec: Resource) -> void:
 speed = spec.speed
 acceleration = spec.acceleration
 turn_speed = spec.turn_speed
 minimum_depth = spec.minimum_depth
 deck_bounds = spec.deck_bounds
 deck_walk_speed = spec.deck_walk_speed

func walk_passenger(world_input: Vector3, delta: float) -> float:
 if passenger == null or mode != Mode.FISHING: return 0.0
 var local_input := global_basis.inverse() * world_input
 var candidate := deck_position + local_input * deck_walk_speed * delta
 candidate.x = clampf(candidate.x,deck_bounds.position.x,deck_bounds.end.x)
 candidate.z = clampf(candidate.z,deck_bounds.position.y,deck_bounds.end.y)
 candidate.y = fishing_anchor.position.y
 for obstacle in deck_obstacles:
  if obstacle.has_point(Vector2(candidate.x,candidate.z)): return 0.0
 var shape: CollisionShape3D = passenger.get_node("CollisionShape3D")
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = shape.shape
 query.transform = Transform3D(Basis.IDENTITY,to_global(candidate) + shape.position)
 query.exclude = [get_rid(),passenger.get_rid()]
 query.collision_mask = 1
 if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return 0.0
 var distance := candidate.distance_to(deck_position)
 deck_position = candidate
 _sync_passenger()
 return distance / maxf(delta,.0001)
