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
@onready var driver_anchor: Marker3D = $DriverAnchor
@onready var fishing_anchor: Marker3D = $FishingAnchor
var mode := Mode.MOORED
var passenger: AnglerPlayer
var drive_input := Vector2.ZERO
var forward_speed := 0.0
var exit_point := Vector3.INF
var _exit_clock := 0.0

func can_board(player: AnglerPlayer) -> bool:
 return passenger == null and player.input_enabled and not player.fishing_active and Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() <= boarding_distance and absf(player.global_position.y - global_position.y) < 2.5

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
 drive_input = Vector2.ZERO
 forward_speed = 0.0
 velocity = Vector3.ZERO
 passenger.character_model.driving = false
 passenger.character_model.aiming = true
 $DriverClearance.set_deferred("disabled", true)
 $StandingClearance.set_deferred("disabled", false)
 _sync_passenger()

func _physics_process(delta: float) -> void:
 if pond == null:
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
  exit_point = find_shore_exit()

func _sync_passenger() -> void:
 if passenger == null:
  return
 passenger.global_position = (driver_anchor if mode == Mode.DRIVING else fishing_anchor).global_position
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
   point.y = definition.ground_height(Vector2(point.x, point.z)) + 0.08
   var query := PhysicsShapeQueryParameters3D.new()
   query.shape = shape.shape
   query.transform = Transform3D(Basis.IDENTITY, point + shape.position)
   query.exclude = [get_rid(), passenger.get_rid()]
   query.collision_mask = 1
   if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
    return point
 return Vector3.INF

func disembark() -> bool:
 var point := find_shore_exit()
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
