class_name AnglerPlayer
extends CharacterBody3D
@export var move_speed: float = 3.8
@export var fight_move_speed: float = 1.8
@export_range(0.2, 1.0) var wading_speed_multiplier: float = 0.65
var fighting := false
@export var pond: Pond
@export var turn_speed: float = 10.0
@export var joystick: Control
## Camera rig defining screen-relative movement; independent of model facing.
@export var movement_reference: Node3D
@onready var visual: Node3D = $Visual
var walk_time := 0.0
var input_enabled := true
var facing_follows_camera := false
var fishing_active := false
var rod_tension: float = 0.0
var rod_side: float = 0.0
var rod_joints: Array[Node3D] = []

func _ready() -> void:
 var path := "Joint1"
 for index in 5:
  rod_joints.append($Visual/FishingRod.get_node(path))
  path += "/Joint%d" % (index + 2)

func _physics_process(delta: float) -> void:
 var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
 if is_instance_valid(joystick) and joystick.direction.length() > input_vector.length():
  input_vector = joystick.direction
 if not input_enabled:
  input_vector = Vector2.ZERO
 var speed := fight_move_speed if fighting else move_speed
 if is_instance_valid(pond) and pond.definition.is_wading(global_position):
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
 if not is_on_floor():
  velocity.y -= 20.0 * delta
 else:
  velocity.y = 0.0
 if is_instance_valid(pond) and delta > 0.0:
  var next_position := pond.constrain_walking(global_position + Vector3(velocity.x, 0, velocity.z) * delta)
  velocity.x = (next_position.x - global_position.x) / delta
  velocity.z = (next_position.z - global_position.z) / delta
 move_and_slide()
 if is_instance_valid(pond):
  global_position = pond.constrain_walking(global_position)
 if input_vector.length() > 0.05:
  if not facing_follows_camera:
   visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-input_vector.x, -input_vector.y), turn_speed * delta)
  walk_time += delta * input_vector.length() * 9.0
  $Visual/LeftLeg.rotation.x = sin(walk_time) * 0.35
  $Visual/RightLeg.rotation.x = -sin(walk_time) * 0.35
 else:
  $Visual/LeftLeg.rotation.x = lerpf($Visual/LeftLeg.rotation.x, 0.0, delta * 12.0)
  $Visual/RightLeg.rotation.x = lerpf($Visual/RightLeg.rotation.x, 0.0, delta * 12.0)
 $Visual/LeftArm.rotation.x = -0.75 if fishing_active else -0.25
 $Visual/RightArm.rotation.x = -0.85 if fishing_active else -0.25
 $Visual/FishingRod.rotation.z = rod_side * -0.45
 for joint in rod_joints:
  joint.rotation.x = -rod_tension * 0.13

func set_fighting(value: bool) -> void:
 fighting = value

func set_view_yaw(yaw: float) -> void:
 visual.rotation.y = yaw

func set_rod_pose(active: bool, tension: float, side: float) -> void:
 fishing_active = active
 rod_tension = tension
 rod_side = side

func play_cast() -> void:
 $CastAnimation.play("cast")

