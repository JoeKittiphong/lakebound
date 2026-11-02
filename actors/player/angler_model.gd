class_name AnglerModel
extends Node3D

@export var blend_time: float = 0.14
@export var fishing_idle_speed: float = 1.0
@export_range(0.1, 6.0) var walk_cycle_distance: float = 2.0
@export_range(0.1, 8.0) var run_cycle_distance: float = 3.0
@export var default_rod: PackedScene = preload("res://features/equipment/rods/light_rod.tscn")
@export var carry_selected_rod: bool = true
@export var carry_animations: AnimationLibrary = preload("res://actors/player/animations/carry_right_hand.tres")
var carrying := false
var _played_action: StringName = &""
var walk_playback_rate := 0.0
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var rod_mesh: Node3D
var current_action: StringName = &""
var _cast_remaining := 0.0
var _hook_remaining := 0.0
var _greeting_remaining := 0.0
var _state := 0
var _reeling := 0.0
var _tension := 0.0
var _celebrated := false
var _direction := 1.0
var _equipped_scene: PackedScene
var locomotion_active := false
var first_person := false
var first_person_rod: FishingRodVisual
var aiming := false
var driving := false
var driving_speed := 0.0
var _right_hand_index := -1
var _left_leaf_rest := Vector3.ZERO
@onready var locomotion_tree: AnimationTree = $FishingLocomotion
@onready var rod_grip: Node3D = $RodHand/Grip
@onready var left_hand_target: Marker3D = $RodHand/Grip/LeftHandTarget
@onready var left_hand_ik: SkeletonIK3D = $Asset/Scene/M2M_TPose_Rig/Skeleton3D/LeftHandIK

func _ready() -> void:
 animation_player = $Asset/AnimationPlayer
 animation_player.add_animation_library(&"carry", carry_animations)
 skeleton = $"Asset/Scene/M2M_TPose_Rig/Skeleton3D"
 _right_hand_index = skeleton.find_bone("hand_r")
 _left_leaf_rest = skeleton.get_bone_rest(skeleton.find_bone("hand_leaf_l")).origin
 locomotion_tree.anim_player = locomotion_tree.get_path_to(animation_player)
 locomotion_tree.root_node = locomotion_tree.get_path_to(animation_player.get_node(animation_player.root_node))
 var tree := locomotion_tree.tree_root as AnimationNodeBlendTree
 var mix := tree.get_node("Mix") as AnimationNodeBlend2
 var walk := animation_player.get_animation("Walk")
 for track in walk.get_track_count():
  var bone := String(walk.track_get_path(track).get_subname(0))
  if bone.begins_with("thigh_") or bone.begins_with("calf_") or bone.begins_with("foot_") or bone.begins_with("ball_"):
   mix.set_filter_path(walk.track_get_path(track), true)
 mix.set_filter_enabled(true)
 locomotion_tree.set("parameters/Mix/blend_amount", 1.0)
 for animation_name in ["Idle_A", "Walk", "Sprint", "Swim_Fwd", "Swim_Idle", "Fishing_Reel", "Fishing_Catch", "Driving", "Sitting_Idle"]:
  animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
 equip_rod(default_rod)
 _play(&"Idle_A")

func equip_rod(scene: PackedScene) -> void:
 if scene == null:
  scene = default_rod
 if scene == _equipped_scene:
  return
 if is_instance_valid(rod_mesh):
  rod_grip.remove_child(rod_mesh)
  rod_mesh.queue_free()
 _equipped_scene = scene
 rod_mesh = scene.instantiate() as Node3D
 rod_grip.add_child(rod_mesh)
 rod_mesh.visible = (_is_fishing() or carrying) and not first_person and not driving

func clear_rod() -> void:
 if is_instance_valid(rod_mesh):
  rod_mesh.get_parent().remove_child(rod_mesh)
  rod_mesh.queue_free()
 rod_mesh = null
 _equipped_scene = null

func set_rod_load(tension: float, side: float) -> void:
 if rod_mesh is FishingRodVisual:
  rod_mesh.set_load(0.0 if carrying else tension, 0.0 if carrying else side)

func _process(delta: float) -> void:
 var holding: bool = _is_fishing() and not driving and is_instance_valid(rod_mesh) and rod_mesh is FishingRodVisual
 if first_person:
  if is_instance_valid(rod_mesh):rod_mesh.hide()
  if left_hand_ik.is_running(): left_hand_ik.stop()
  return
 if not holding:
  if left_hand_ik.is_running():
   left_hand_ik.stop()
  return
 rod_mesh.advance_reel(delta, _reeling)
 var grip_mode := FishingRodVisual.GripMode.CAST if _state == FishingController.State.CASTING else (FishingRodVisual.GripMode.SUPPORT if _state == FishingController.State.FIGHT else FishingRodVisual.GripMode.REEL)
 # Place the palm, not the wrist bone, on the contact. Orient the support
 # hand around the shaft and preserve the skeleton's centimeter scale.
 var right_hand := skeleton.global_transform * skeleton.get_bone_global_pose(_right_hand_index)
 var shaft_axis := rod_mesh.global_basis.y.normalized()
 var hand_basis := Basis(shaft_axis, PI * 0.5) * right_hand.basis
 var palm_offset := hand_basis * _left_leaf_rest * 0.28
 left_hand_target.global_transform = Transform3D(hand_basis, rod_mesh.left_hand_contact(grip_mode) - palm_offset)
 if not left_hand_ik.is_running():
  left_hand_ik.start()

func equip_reel(item: TackleItem) -> void:
 if rod_mesh is FishingRodVisual and item == null:
  rod_mesh.clear_held_reel()
  return
 if rod_mesh is FishingRodVisual and item != null and item.model_scene != null:
  rod_mesh.set_held_reel(item.model_scene, {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}[item.spool_axis])

func set_fishing_state(state: int, reeling: float, tension: float) -> void:
 if state != _state:
  if state != FishingController.State.CASTING:
   _cast_remaining = 0.0
  if state != FishingController.State.FIGHT:
   _hook_remaining = 0.0
  if state == FishingController.State.FIGHT and _state == FishingController.State.BITE:
   _hook_remaining = 0.32
  if state == FishingController.State.RESULT:
   _celebrated = false
 _state = state
 _reeling = reeling
 _tension = tension

func cast(duration: float) -> void:
 _cast_remaining = maxf(duration, 0.1)
 _hook_remaining = 0.0
 _play(&"Fishing_Cast", animation_player.get_animation("Fishing_Cast").length / _cast_remaining)

func greet() -> void:
 if not _is_fishing():
  _greeting_remaining = animation_player.get_animation("Greeting").length
  _play(&"Greeting")

func _is_fishing() -> bool:
 return (aiming and _state == FishingController.State.READY) or _state in [FishingController.State.CASTING, FishingController.State.WAITING, FishingController.State.BITE, FishingController.State.FIGHT]

func update_motion(delta: float, moving: bool, ground_speed: float, backwards: bool, airborne: bool = false, swimming: bool = false, running: bool = false) -> void:
 walk_playback_rate = ground_speed * animation_player.get_animation("Walk").length / walk_cycle_distance
 var signed_rate := walk_playback_rate * (-1.0 if backwards else 1.0)
 _cast_remaining = maxf(0.0, _cast_remaining - delta)
 _hook_remaining = maxf(0.0, _hook_remaining - delta)
 _greeting_remaining = maxf(0.0, _greeting_remaining - delta)
 var fishing := _is_fishing() and not swimming and not airborne and not driving
 carrying = carry_selected_rod and not fishing and not swimming and not airborne and not driving and _greeting_remaining <= 0.0 and _state == FishingController.State.READY
 var walk_while_fishing := moving and fishing and _state != FishingController.State.CASTING
 if walk_while_fishing:
  var tree := locomotion_tree.tree_root as AnimationNodeBlendTree
  var body := tree.get_node("Body") as AnimationNodeAnimation
  body.animation = &"Fishing_Catch" if _state == FishingController.State.FIGHT else &"Fishing_Reel"
  locomotion_tree.set("parameters/LegSpeed/scale", signed_rate)
  locomotion_tree.set("parameters/BodySpeed/scale", 1.0 if _state == FishingController.State.FIGHT or _reeling > 0.1 else 0.0)
  animation_player.active = false
  locomotion_tree.active = true
  locomotion_active = true
 elif locomotion_active:
  locomotion_tree.active = false
  animation_player.active = true
  locomotion_active = false
  current_action = &""
 if is_instance_valid(rod_mesh):
  rod_mesh.visible = (fishing or carrying) and not first_person
 if driving:
  _greeting_remaining = 0.0
  _play(&"Driving" if driving_speed > 0.1 else &"Sitting_Idle")
 elif swimming:
  _greeting_remaining = 0.0
  _play(&"Swim_Fwd" if moving else &"Swim_Idle")
 elif airborne:
  _greeting_remaining = 0.0
  _play(&"Jump_2")
 elif _cast_remaining > 0.0:
  return
 elif _hook_remaining > 0.0:
  _play(&"Fishing_Catch", 2.0)
 elif _state == FishingController.State.RESULT:
  if not _celebrated:
   _play(&"Greeting")
   _celebrated = true
 elif _state == FishingController.State.FIGHT:
  _play(&"Fishing_Catch" if _tension > 0.25 else &"Fishing_Reel")
 elif fishing:
  _play(&"Fishing_Reel", fishing_idle_speed if _reeling > 0.1 else 0.0)
 elif moving:
  _greeting_remaining = 0.0
  if running:
   _play(&"Sprint", ground_speed * animation_player.get_animation("Sprint").length / run_cycle_distance * (-1.0 if backwards else 1.0))
  else:
   _play(&"Walk", signed_rate)
 elif _greeting_remaining > 0.0:
  _play(&"Greeting")
 else:
  _play(&"Idle_A")

func rod_tip_position() -> Vector3:
 if first_person and is_instance_valid(first_person_rod): return first_person_rod.tip.global_position
 if rod_mesh is FishingRodVisual:
  return rod_mesh.tip.global_position
 var tip := rod_mesh.find_child("Tip", true, false) as Node3D if is_instance_valid(rod_mesh) else null
 return tip.global_position if tip != null else rod_grip.global_position

func _play(action: StringName, speed: float = 1.0) -> void:
 var direction := -1.0 if speed < 0.0 else 1.0
 var playback: StringName = StringName("carry/" + String(action)) if carrying and action in [&"Walk", &"Sprint", &"Idle_A"] else action
 if current_action == action and direction == _direction and _played_action == playback:
  animation_player.speed_scale = absf(speed)
  return
 current_action = action
 _played_action = playback
 _direction = direction
 animation_player.speed_scale = absf(speed)
 if not locomotion_active:
  animation_player.play(playback, 0.0 if is_zero_approx(speed) else blend_time, direction, speed < 0.0)
  if is_zero_approx(speed):
   animation_player.seek(0.0, true)

func equip_line(item: TackleItem) -> void:
 if rod_mesh is FishingRodVisual: rod_mesh.set_line_attached(item != null)
 if rod_mesh is DetailedFishingRod and item != null:
  rod_mesh.set_line_style(item.line_visual_style)
