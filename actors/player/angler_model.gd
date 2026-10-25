class_name AnglerModel
extends Node3D

@export var blend_time: float = 0.14
@export var fishing_idle_speed: float = 1.0
@export_range(0.1, 6.0) var walk_cycle_distance: float = 2.0
@export_range(0.1, 8.0) var run_cycle_distance: float = 3.0
@export var default_rod: PackedScene = preload("res://features/equipment/rods/light_rod.tscn")
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
var aiming := false
var driving := false
var driving_speed := 0.0
@onready var locomotion_tree: AnimationTree = $FishingLocomotion
@onready var rod_grip: Node3D = $RodHand/Grip

func _ready() -> void:
 animation_player = $Asset/AnimationPlayer
 skeleton = $"Asset/Scene/M2M_TPose_Rig/Skeleton3D"
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
 for name in ["Idle_A", "Walk", "Sprint", "Swim_Fwd", "Swim_Idle", "Fishing_Reel", "Fishing_Catch", "Driving", "Sitting_Idle"]:
  animation_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
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
 rod_mesh.visible = _is_fishing()

func set_rod_load(tension: float, side: float) -> void:
 if rod_mesh is FishingRodVisual:
  rod_mesh.set_load(tension, side)

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
  rod_mesh.visible = fishing
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
 if rod_mesh is FishingRodVisual:
  return rod_mesh.tip.global_position
 var tip := rod_mesh.find_child("Tip", true, false) as Node3D if is_instance_valid(rod_mesh) else null
 return tip.global_position if tip != null else rod_grip.global_position

func _play(action: StringName, speed: float = 1.0) -> void:
 var direction := -1.0 if speed < 0.0 else 1.0
 if current_action == action and direction == _direction:
  animation_player.speed_scale = absf(speed)
  return
 current_action = action
 _direction = direction
 animation_player.speed_scale = absf(speed)
 if not locomotion_active:
  animation_player.play(action, 0.0 if is_zero_approx(speed) else blend_time, direction, speed < 0.0)
  if is_zero_approx(speed):
   animation_player.seek(0.0, true)
