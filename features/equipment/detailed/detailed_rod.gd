class_name DetailedFishingRod
extends FishingRodVisual
@export var rod_id: String = "01_spinning"
@export var rod_spec: RodSpec
@export_file("*.json") var config_path: String = "res://features/equipment/detailed/rods.json"
var _guide_frame := -1
var _guide_transform := Transform3D.IDENTITY
var config: Dictionary
var rig: Skeleton3D
var guide_points: PackedVector3Array = PackedVector3Array()
var load_amount: float = 0.0
var _side: float = 0.0
var external_pull_enabled: bool = false
var pull_direction := Vector3.FORWARD
var _model_rest: Transform3D
var _mount_rest: Transform3D
var mount_layout: String = "spinning"
var line_style: String = "mono"
var payout_amount: float = 0.0
var fill_fraction: float = 1.0
@onready var ribbon: MeshInstance3D = $GuideLine
@onready var feed_ribbon: MeshInstance3D = $FeedLine
func _ready() -> void:
 config = JSON.parse_string(FileAccess.get_file_as_string(config_path))[rod_id]
 rig = _find_skeleton($Model)
 _model_rest = $Model.transform
 _mount_rest = $ReelMount.transform
 mount_layout = config.get("mount_layout", "spinning")
 tip = $Tip
 set_held_reel(default_reel)
 set_load(0, 0)
func _find_skeleton(node: Node) -> Skeleton3D:
 if node is Skeleton3D: return node
 for child in node.get_children():
  var found := _find_skeleton(child)
  if found != null: return found
 return null
func set_held_reel(scene: PackedScene, axis: Vector3 = Vector3.RIGHT) -> void:
 if scene == null:
  clear_held_reel()
  return
 if not accepts_reel or scene == null or scene == _held_scene: return
 # Validate the candidate before removing the currently mounted compatible reel.
 var candidate := scene.instantiate() as Node3D
 if not candidate is DetailedReelVisual or not EquipmentFit.accepts(mount_layout, candidate.mount_family):
  candidate.free()
  return
 if is_instance_valid(held_reel):
  held_reel.get_parent().remove_child(held_reel)
  held_reel.queue_free()
 held_reel = candidate
 $ReelMount.add_child(held_reel)
 # Both markers describe the actual contact plane, including offset spincast feet.
 held_reel.transform = held_reel.get_node("ReelFoot").transform.affine_inverse()
 _held_scene = scene
 _spool_axis = axis
 if held_reel is DetailedReelVisual: held_reel.set_line_style(line_style)
func set_line_style(style: String) -> void:
 line_style = style
 if held_reel is DetailedReelVisual: held_reel.set_line_style(style)
 var color: Color = {"mono": Color(0.44,0.67,0.78), "fluoro": Color(0.69,0.74,0.68), "braid": Color(0.47,0.58,0.27), "fly": Color(0.91,0.38,0.15)}[style]
 if is_instance_valid(ribbon):
  var mat := ribbon.material_override as ShaderMaterial
  mat.set_shader_parameter("line_color", color)
  ribbon.width = 0.001 if style == "fly" else 0.0007
  feed_ribbon.width = ribbon.width
func advance_reel(delta: float, amount: float) -> void:
 if held_reel is DetailedReelVisual: held_reel.advance(delta, amount, payout_amount, fill_fraction)
func left_hand_contact(mode: GripMode) -> Vector3:
 if mode == GripMode.CAST: return $ButtGrip.global_position
 if mode == GripMode.SUPPORT or not is_instance_valid(held_reel): return $SupportGrip.global_position
 if held_reel is DetailedReelVisual: return held_reel.hand_position()
 return $SupportGrip.global_position
func set_load(tension: float, side: float) -> void:
 load_amount = clampf(tension, 0, 1)
 _side = clampf(side, -1, 1)
 if not is_instance_valid(rig): return
 var angles: PackedFloat32Array
 if rod_spec != null:
  angles = rod_spec.joint_angles(load_amount)
 else:
  # Existing families keep their stats but now use their authored power/action.
  var amplitude: float = {"UL": 1.85, "L": 1.7, "M": 1.45, "MH": 1.25, "H": 1.12, "XH": 0.95, "5 WT": 1.5}.get(config.get("power", "M"), 1.45)
  angles = RodSpec.calculate_angles(config.get("action", "Moderate-Fast"), amplitude, 0.22, load_amount)
 # Convert the pull plane through each rest basis so model roll preserves bend direction.
 for i in range(12):
  var index := rig.find_bone("Bend_%02d" % (i + 1))
  if index >= 0:
   var angle := angles[i]
   var radial := Vector3(_side * 0.3, 0, -1)
   if external_pull_enabled:
    var local_pull := global_basis.inverse() * pull_direction
    radial = Vector3(local_pull.x, 0, local_pull.z)
    if radial.length_squared() < 0.000001: radial = Vector3.FORWARD
   var bend_axis := Vector3.UP.cross(radial.normalized())
   var local_axis := (rig.get_bone_global_rest(index).basis.inverse() * rig.global_basis.inverse() * global_basis * bend_axis).normalized()
   rig.set_bone_pose_rotation(index, Quaternion(local_axis, angle))
 rig.force_update_all_bone_transforms()
 update_guides()
func skin_point(record: Dictionary) -> Vector3:
 var values: Array = record["rest"]
 var rest := Vector3(values[0], values[1], values[2])
 var point := Vector3.ZERO
 for item in record["weights"]:
  var bone := rig.find_bone(item["bone"])
  if bone >= 0: point += (rig.get_bone_global_pose(bone) * rig.get_bone_global_rest(bone).affine_inverse() * rest) * float(item["weight"])
 return rig.global_transform * point
func update_guides() -> void:
 _guide_frame = Engine.get_process_frames()
 _guide_transform = global_transform
 guide_points.clear()
 for guide in config["guides"]: guide_points.append(skin_point(guide))
 tip.global_position = skin_point(config["tip"]) if guide_points.is_empty() else guide_points[-1]
 var camera := get_viewport().get_camera_3d()
 ribbon.visible = line_attached and camera != null and not guide_points.is_empty() and is_instance_valid(held_reel)
 feed_ribbon.visible = false
 if not ribbon.visible: return
 # Keep the physical tip current, but do not rebuild decorative guide/feed
 # ribbons when their entire bounds are outside a frustum plane.
 for plane in camera.get_frustum():
  var outside := plane.distance_to(held_reel.global_position) > 0.3
  for point in guide_points:
   if plane.distance_to(point) <= 0.3:
    outside = false
    break
  if outside:
   ribbon.hide()
   return
 ribbon.camera_path = ribbon.get_path_to(camera)
 var exit_point: Vector3 = held_reel.exit_position(guide_points[0]) if held_reel is DetailedReelVisual else held_reel.global_position
 $LineStart.global_position = exit_point
 ribbon.control_points = PackedVector3Array([exit_point]) + guide_points
 ribbon.refresh()
 var feed: PackedVector3Array = held_reel.feed_path(exit_point)
 if feed.size() >= 2:
  feed_ribbon.camera_path = feed_ribbon.get_path_to(camera)
  feed_ribbon.control_points = feed
  feed_ribbon.visible = true
  feed_ribbon.refresh()
func guide_frame(record: Dictionary) -> Transform3D:
 var center := skin_point(record)
 var along_u := record.duplicate(true)
 var along_v := record.duplicate(true)
 along_u["rest"] = record["u_point"]
 along_v["rest"] = record["v_point"]
 var u := skin_point(along_u) - center
 var v := skin_point(along_v) - center
 return Transform3D(Basis(u, v, u.cross(v).normalized()), center)
func _process(_delta: float) -> void:
 if not is_visible_in_tree() or get_viewport().disable_3d: return
 if _guide_frame != Engine.get_process_frames() or _guide_transform != global_transform:
  update_guides()



func set_pull_direction(world_direction: Vector3) -> void:
 if world_direction.length_squared() > 0.000001:
  external_pull_enabled = true
  pull_direction = world_direction.normalized()

func handle_pivot_world() -> Vector3:
 return global_transform * Vector3(0, -float(config["grip_x"]), 0)

func first_guide_facing() -> Vector3:
 if config["guides"].is_empty(): return Vector3.ZERO
 var guide: Dictionary = config["guides"][0]
 var center := guide.duplicate(true)
 var values: Array = guide["rest"]
 center["rest"] = [values[0], 0.0, 0.0]
 return (skin_point(guide) - skin_point(center)).normalized()

func first_guide_tangent() -> Vector3:
 if config["guides"].is_empty(): return global_basis.y.normalized()
 var guide: Dictionary = config["guides"][0]
 var center := guide.duplicate(true)
 var next := guide.duplicate(true)
 var values: Array = guide["rest"]
 center["rest"] = [values[0], 0.0, 0.0]
 next["rest"] = [float(values[0]) + 0.001, 0.0, 0.0]
 return (skin_point(next) - skin_point(center)).normalized()
