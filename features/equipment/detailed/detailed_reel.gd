class_name DetailedReelVisual
extends Node3D
# Explicit dependencies must be included in Android selected-resource exports.
const LINE_MATERIALS: Dictionary = {
 "mono": preload("res://features/equipment/detailed/materials/mono.tres"),
 "fluoro": preload("res://features/equipment/detailed/materials/fluoro.tres"),
 "braid": preload("res://features/equipment/detailed/materials/braid.tres"),
 "fly": preload("res://features/equipment/detailed/materials/fly.tres")
}
@export var reel_id: String = "01_spinning"
@export_enum("spinning", "low", "round", "star", "lever", "spincast", "fly", "ice") var mount_family: String = "spinning"
var config: Dictionary
var _baseline: Dictionary = {}
var turns: float = 0.0
var payout_turns: float = 0.0
var line_style: String = "mono"
@onready var fill: MeshInstance3D = $FillSurface
func _ready() -> void:
 var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://features/equipment/detailed/reels.json"))
 for cfg in catalog["reels"]:
  if cfg["id"] == reel_id: config = cfg
 _cache_transforms($Model)
 set_line_style(line_style)
 advance(0, 0, 0)
func _cache_transforms(node: Node) -> void:
 if node is Node3D: _baseline[node.get_instance_id()] = node.transform
 for child in node.get_children(): _cache_transforms(child)
func part(part_name: String) -> Node3D:
 return $Model.find_child(part_name, true, false) as Node3D
func rotate_part(node: Node3D, axis: Vector3, angle: float) -> void:
 if node == null: return
 var initial: Transform3D = _baseline[node.get_instance_id()]
 node.transform = Transform3D(initial.basis * Basis(Quaternion(axis, angle)), initial.origin)
func translate_part(node: Node3D, axis: Vector3, distance: float) -> void:
 if node == null: return
 var initial: Transform3D = _baseline[node.get_instance_id()]
 node.position = initial.origin + axis * distance
func set_line_style(style: String) -> void:
 line_style = style if LINE_MATERIALS.has(style) else "mono"
 if not is_node_ready(): return
 var source := LINE_MATERIALS.get(line_style) as StandardMaterial3D
 if source == null:
  push_error("Fishing line material is unavailable: " + line_style)
  return
 var mat := source.duplicate() as StandardMaterial3D
 if mat == null: return
 mat.uv1_scale.y = float(config["width"]) / 0.0255
 fill.material_override = mat
func advance(delta: float, retrieve: float, payout: float, amount: float = 1.0) -> void:
 turns += maxf(retrieve, 0) * delta * 1.1
 payout_turns += maxf(payout, 0) * delta * 0.65
 var family: String = config["family"]
 var axial := family in ["spinning", "spincast"]
 var axis := Vector3.RIGHT if axial else Vector3.FORWARD
 if axial:
  rotate_part(part("RotorPivot"), axis, -turns * float(config["ratio"]) * TAU)
  rotate_part(part("SpoolPivot"), axis, payout_turns * TAU)
  translate_part(part("TraversePivot"), axis, (0.010 if family == "spinning" else 0.004) * 0.5 * (1 - cos(turns * TAU / 5)))
 else:
  rotate_part(part("SpoolPivot"), axis, (turns * float(config["ratio"]) - payout_turns) * TAU)
 rotate_part(part("CrankPivot"), Vector3.FORWARD, turns * TAU)
 for grip_name in config["grips"]:
  rotate_part(part(grip_name), Vector3.FORWARD, -(turns - payout_turns if family == "fly" else turns) * TAU)
 translate_part(part("LevelwindPivot"), Vector3.FORWARD, float(config["levelwind_travel"]) * sin(turns * TAU / 5))
 var radius := sqrt(lerpf(pow(float(config["core_radius"]), 2), pow(float(config["maximum_radius"]), 2), clampf(amount, 0.02, 1)))
 var slot := part("LineFillSlot")
 var alignment := Basis(Quaternion(Vector3.UP, axis))
 fill.global_transform = Transform3D(slot.global_basis * alignment.scaled_local(Vector3(radius, float(config["width"]), radius)), slot.global_position)
func exit_position(target: Vector3) -> Vector3:
 var marker := part("LineExit")
 if bool(config["tangent_exit"]):
  var xyz: Array = config["spool_center_blender"]
  var center := Vector3(xyz[0], xyz[2], -xyz[1])
  var direction := to_local(target) - center
  var flat := Vector2(direction.x, direction.y)
  var radius := fill.global_basis.x.length() / global_basis.x.length()
  var squared := flat.length_squared()
  if squared > radius * radius + 0.0000001:
   var offset := Vector2(-flat.y, flat.x) * radius * sqrt(squared - radius * radius) / squared
   var base := flat * radius * radius / squared
   var first := base + offset
   var second := base - offset
   var pick := first if first.y > second.y else second
   marker.position = center + Vector3(pick.x, pick.y, 0)
 return marker.global_position
func hand_position() -> Vector3:
 var grip := part("GripPivot0")
 return grip.global_position if grip != null else global_position

func feed_path(exit_point: Vector3) -> PackedVector3Array:
 if mount_family == "spinning":
  var center := fill.global_position
  var axis := fill.global_basis.y.normalized()
  var radial := exit_point - center
  radial -= axis * radial.dot(axis)
  if radial.length_squared() < 0.000001: return PackedVector3Array()
  var lip := center + radial.normalized() * fill.global_basis.x.length() + axis * fill.global_basis.y.length() * 0.5
  return PackedVector3Array([lip, exit_point])
 if mount_family in ["low", "round"]:
  var xyz: Array = config["spool_center_blender"]
  var center := Vector3(xyz[0], xyz[2], -xyz[1])
  var target := to_local(exit_point)
  var flat := Vector2(target.x-center.x, target.y-center.y)
  var radius := fill.global_basis.x.length() / global_basis.x.length()
  var squared := flat.length_squared()
  if squared > radius * radius:
   var base := flat * radius * radius / squared
   var offset := Vector2(-flat.y, flat.x) * radius * sqrt(squared-radius*radius) / squared
   var first := base + offset
   var second := base - offset
   var pick := first if first.y > second.y else second
   return PackedVector3Array([to_global(center+Vector3(pick.x,pick.y,target.z-center.z)),exit_point])
 return PackedVector3Array()
