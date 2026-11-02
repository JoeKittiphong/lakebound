class_name FishingRodVisual
extends Node3D
enum GripMode { REEL, CAST, SUPPORT }

## Rod scenes use +Y along the shaft; origin is the hand grip. Tip drives the line.
@export var bend_per_joint: float = 0.13
@export var accepts_reel := true
@export var default_reel: PackedScene = preload("res://features/equipment/reels/models/basic.glb")
@onready var tip: Node3D = find_child("Tip", true, false)
var joints: Array[Node3D] = []
var held_reel: Node3D
var line_attached := true
var _held_scene: PackedScene
var _spool_axis := Vector3.RIGHT
var _crank_angle := 0.0
var _spool_angle := 0.0

func _ready() -> void:
 for index in range(1,6):
  joints.append(find_child("Joint%d" % index, true, false) as Node3D)
 set_held_reel(default_reel)

func set_held_reel(scene: PackedScene, axis: Vector3 = Vector3.RIGHT) -> void:
 if scene == null:
  clear_held_reel()
  return
 if not accepts_reel or scene == null or scene == _held_scene:
  return
 var mount := find_child("ReelMount", true, false) as Node3D
 if mount == null:
  return
 if is_instance_valid(held_reel):
  mount.remove_child(held_reel)
  held_reel.queue_free()
 held_reel = scene.instantiate() as Node3D
 mount.add_child(held_reel)
 _held_scene = scene
 _spool_axis = axis

func clear_held_reel() -> void:
 if is_instance_valid(held_reel):
  held_reel.get_parent().remove_child(held_reel)
  held_reel.queue_free()
 held_reel = null
 _held_scene = null

func set_line_attached(value: bool) -> void:
 line_attached = value
 if is_instance_valid(held_reel) and held_reel.has_node("FillSurface"):
  held_reel.get_node("FillSurface").visible = value
 for path in ["GuideLine", "FeedLine"]:
  if has_node(path): get_node(path).visible = value

func advance_reel(delta: float, amount: float) -> void:
 if not is_instance_valid(held_reel):
  return
 _crank_angle += amount * delta * 7.0
 _spool_angle += amount * delta * 9.0
 var crank := held_reel.find_child("Crank", true, false) as Node3D
 var spool := held_reel.find_child("Spool", true, false) as Node3D
 crank.rotation = (Vector3.UP if _spool_axis == Vector3.UP else Vector3.RIGHT) * _crank_angle
 spool.rotation = _spool_axis * _spool_angle

func left_hand_contact(mode: GripMode) -> Vector3:
 if mode == GripMode.CAST:
  return (find_child("ButtGrip", true, false) as Node3D).global_position
 if mode == GripMode.SUPPORT or not is_instance_valid(held_reel):
  return (find_child("SupportGrip", true, false) as Node3D).global_position
 var crank_grip := held_reel.find_child("HandGrip", true, false) as Node3D
 return crank_grip.global_position

func set_load(tension: float, side: float) -> void:
 for joint in joints:
  joint.rotation.x = -clampf(tension, 0.0, 1.0) * bend_per_joint
 joints[0].rotation.z = -clampf(side, -1.0, 1.0) * 0.25
