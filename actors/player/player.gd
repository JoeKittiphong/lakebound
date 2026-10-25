class_name AnglerPlayer
extends CharacterBody3D
signal swimming_changed(swimming: bool)
@export var move_speed: float = 3.8
@export var run_speed: float = 6.2
@export var jump_velocity: float = 6.8
@export var gravity: float = 20.0
@export var swim_speed: float = 2.6
## Root below the surface; the horizontal swimming pose keeps the head above water.
@export var swim_float_depth: float = 0.95
@export var buoyancy_response: float = 8.0
@export var fight_move_speed: float = 1.2
@export_range(0.2, 1.0) var wading_speed_multiplier: float = 0.65
var fighting := false
@export var pond: Pond
@export var turn_speed: float = 10.0
@export var joystick: Control
## Camera rig defining screen-relative movement; independent of model facing.
@export var movement_reference: Node3D
@onready var visual: Node3D = $Visual
@onready var character_model: AnglerModel = $Visual/AnglerModel
var actual_ground_speed := 0.0
var input_enabled := true
var facing_follows_camera := false
var fishing_active := false
var rod_tension: float = 0.0
var rod_side: float = 0.0
var swimming := false
var running := false
var run_requested := false
var _jump_buffer := 0.0
var _swim_exit_cooldown := 0.0
var boat: FishingBoat
var _saved_collision_layer := 1
var _saved_collision_mask := 1

func _ready() -> void:
 # Bone attachments update after animation sampling, before the rendered line.
 character_model.skeleton.skeleton_updated.connect(_sync_rod_tip)

func request_jump() -> bool:
 if not input_enabled or fishing_active or boat != null:
  return false
 _jump_buffer = 0.15
 return true

func request_greeting() -> void:
 if input_enabled and is_on_floor() and not swimming and not fishing_active:
  character_model.greet()

func equip_rod(item: TackleItem) -> void:
 character_model.equip_rod(item.model_scene if item != null else null)

func can_fish() -> bool:
 return (boat != null and boat.mode == FishingBoat.Mode.FISHING) or (boat == null and not swimming and is_on_floor())

func embark(vessel: FishingBoat) -> void:
 boat = vessel
 _saved_collision_layer = collision_layer
 _saved_collision_mask = collision_mask
 collision_layer = 0
 collision_mask = 0
 _set_swimming(false)
 _jump_buffer = 0.0
 run_requested = false
 character_model.aiming = false
 velocity = Vector3.ZERO

func disembark(point: Vector3) -> void:
 boat = null
 collision_layer = _saved_collision_layer
 collision_mask = _saved_collision_mask
 global_position = point
 velocity = Vector3.ZERO
 character_model.driving = false
 character_model.aiming = false

func boat_driving() -> bool:
 return boat != null and boat.mode == FishingBoat.Mode.DRIVING

func boat_fishing() -> bool:
 return boat != null and boat.mode == FishingBoat.Mode.FISHING

func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("jump") and not event.is_echo():
  request_jump()
  get_viewport().set_input_as_handled()
 elif event.is_action_pressed("greet") and not event.is_echo():
  request_greeting()
  get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
 var previous_position := global_position
 var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
 if is_instance_valid(joystick) and joystick.direction.length() > input_vector.length():
  input_vector = joystick.direction
 if not input_enabled:
  input_vector = Vector2.ZERO
 if boat != null:
  swimming = false
  running = false
  boat.drive_input = input_vector if boat_driving() else Vector2.ZERO
  character_model.driving = boat_driving()
  character_model.driving_speed = absf(boat.forward_speed)
  character_model.update_motion(delta, false, 0.0, false)
  character_model.set_rod_load(rod_tension, rod_side)
  actual_ground_speed = 0.0
  return
 _swim_exit_cooldown = maxf(0.0, _swim_exit_cooldown - delta)
 _update_swimming()
 if Input.is_action_just_pressed("jump"):
  request_jump()
 running = input_enabled and (run_requested or Input.is_action_pressed("sprint")) and not fishing_active and not swimming and input_vector.length() > 0.05
 var speed := swim_speed if swimming else fight_move_speed if fighting else run_speed if running else move_speed
 if not swimming and is_instance_valid(pond) and pond.definition.is_wading(global_position):
  speed *= wading_speed_multiplier
 var movement := Vector3(input_vector.x, 0, input_vector.y)
 if facing_follows_camera and is_instance_valid(movement_reference):
  var forward := -movement_reference.global_basis.z
  forward.y = 0.0
  forward = forward.normalized()
  var right := forward.cross(Vector3.UP)
  movement = right * input_vector.x - forward * input_vector.y
 elif facing_follows_camera:
  movement = movement.rotated(Vector3.UP, visual.rotation.y)
 velocity.x = movement.x * speed
 velocity.z = movement.z * speed
 if _jump_buffer > 0.0 and input_enabled and not fishing_active and (is_on_floor() or swimming):
  velocity.y = jump_velocity
  _jump_buffer = 0.0
  if swimming:
   _swim_exit_cooldown = 0.65
   _set_swimming(false)
 elif swimming:
  var target := pond.definition.surface_height() - swim_float_depth
  # Rise with the river bed at the bank so the deeper floating pose can exit.
  if pond.definition is RiverDefinition:
   var bed := (pond.definition as RiverDefinition).ground_height(Vector2(global_position.x, global_position.z))
   target = maxf(target, bed + 0.25)
  velocity.y = move_toward(velocity.y, clampf((target - global_position.y) * buoyancy_response, -4.0, 4.0), 18.0 * delta)
 elif not is_on_floor():
  velocity.y -= gravity * delta
 else:
  velocity.y = 0.0
 _jump_buffer = maxf(0.0, _jump_buffer - delta)
 if is_instance_valid(pond) and delta > 0.0:
  var next_position := pond.definition.constrain_travel(global_position + Vector3(velocity.x, 0, velocity.z) * delta)
  velocity.x = (next_position.x - global_position.x) / delta
  velocity.z = (next_position.z - global_position.z) / delta
 move_and_slide()
 if is_instance_valid(pond):
  global_position = pond.definition.constrain_travel(global_position)
 if input_vector.length() > 0.05:
  var facing := movement
  visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-turn_speed * delta))
 var displacement := global_position - previous_position
 displacement.y = 0.0
 actual_ground_speed = displacement.length() / maxf(delta, 0.0001)
 character_model.update_motion(delta, actual_ground_speed > 0.04, actual_ground_speed, false, not is_on_floor() and not swimming, swimming, running)
 character_model.set_rod_load(rod_tension, rod_side)

func _update_swimming() -> void:
 if not is_instance_valid(pond) or _swim_exit_cooldown > 0.0:
  _set_swimming(false)
  return
 var surface := pond.definition.surface_height()
 var immersed := global_position.y < surface - (0.18 if swimming else 0.35)
 _set_swimming(immersed and pond.definition.can_swim_at(global_position))

func _set_swimming(value: bool) -> void:
 if swimming == value:
  return
 swimming = value
 motion_mode = MOTION_MODE_FLOATING if swimming else MOTION_MODE_GROUNDED
 swimming_changed.emit(swimming)

func _process(_delta: float) -> void:
 # Existing line effects bind this editor-authored marker; follow the real animated rod.
 _sync_rod_tip()

func _sync_rod_tip() -> void:
 # Deferred pose updates can arrive after a scene change has removed this player.
 if not is_inside_tree() or not is_instance_valid(character_model) or not character_model.is_inside_tree():
  return
 $Visual/FishingRod/Joint1/Joint2/Joint3/Joint4/Joint5/Tip.global_position = character_model.rod_tip_position()

func set_fighting(value: bool) -> void:
 fighting = value

func set_view_yaw(yaw: float) -> void:
 if not boat_driving():
  visual.rotation.y = yaw

func set_rod_pose(active: bool, tension: float, side: float) -> void:
 fishing_active = active
 rod_tension = tension
 rod_side = side

func play_cast(duration: float = 0.6) -> void:
 character_model.cast(duration)

func set_aiming(value: bool) -> void:
 character_model.aiming = (value or boat_fishing()) and can_fish()

func set_fishing_animation_state(state: int, reeling: float, tension: float) -> void:
 character_model.set_fishing_state(state, reeling, tension)

