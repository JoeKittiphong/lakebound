class_name AnglerPlayer
extends CharacterBody3D
@export var move_speed: float = 3.8
@export var fight_move_speed: float = 1.8
var fighting := false
@export var pond: Pond
@export var turn_speed: float = 10.0
@export var joystick: Control
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
 velocity.x = input_vector.x * speed
 velocity.z = input_vector.y * speed
 if not is_on_floor():
  velocity.y -= 20.0 * delta
 else:
  velocity.y = 0.0
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
