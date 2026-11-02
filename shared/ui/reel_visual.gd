extends SubViewportContainer

@export var reel_scene: PackedScene = preload("res://features/equipment/reels/baitcaster.tscn")
## Enable for replacement models with autonomous animations or time shaders.
@export var continuous_rendering := false
@export var imported_model_view_size := 2.8
var _redraw_needed := true
var spin := 0.0
var crank := 0.0
var tilt := 0.0
var command := Vector2.ZERO
var slipping := false
var spool_axis := Vector3.RIGHT
@onready var model: Node3D = $Viewport/Model
var spool_pivot: Node3D
var crank_pivot: Node3D
var guide_pivot: Node3D

func _pivot(root: Node3D, pivot_name: String) -> Node3D:
 if root is DetailedReelVisual:
  var names: Dictionary = {"Spool": "SpoolPivot", "Crank": "CrankPivot", "Guide": "LineExit"}
  var node: Node3D = root.part(names[pivot_name])
  if node == null and pivot_name == "Crank": node = root.part("GripPivot0")
  return node
 return root.find_child(pivot_name, true, false) as Node3D

func _bind_pivots() -> void:
 spool_pivot = _pivot(model, "Spool")
 crank_pivot = _pivot(model, "Crank")
 guide_pivot = _pivot(model, "Guide")

func _ready() -> void:
 _bind_pivots()
 if reel_scene != null and model.scene_file_path != reel_scene.resource_path:
  equip(reel_scene)
 visibility_changed.connect(_update_rendering)
 resized.connect(_request_redraw)
 $Viewport.size_changed.connect(_request_redraw)
 _update_rendering()

# Future equipment selection can provide another scene with the same pivot names.
func equip(scene: PackedScene, axis: Vector3 = Vector3.RIGHT) -> bool:
 if scene == null:
  return false
 var replacement := scene.instantiate()
 if not replacement is Node3D or _pivot(replacement, "Spool") == null or _pivot(replacement, "Crank") == null or _pivot(replacement, "Guide") == null:
  replacement.free()
  return false
 $Viewport.remove_child(model)
 model.queue_free()
 model = replacement
 $Viewport.add_child(model)
 reel_scene = scene
 spool_axis = axis
 _bind_pivots()
 _apply_pose()
 if model is DetailedReelVisual:
  $Viewport/Camera.size = 0.18
  $Viewport/Camera.position = Vector3(0.12, 0.08, 0.2)
  $Viewport/Camera.look_at(Vector3(0.01, -0.035 if model.config["family"] == "spinning" else 0.02, 0), Vector3.UP)
 else:
  $Viewport/Camera.size = imported_model_view_size if scene.resource_path.ends_with(".glb") else 4.0
 _request_redraw()
 return true

func _update_rendering() -> void:
 _redraw_needed = true
 $Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _request_redraw() -> void:
 _redraw_needed = true
 if is_visible_in_tree():
  $Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
 if not is_visible_in_tree():
  return
 var previous := Vector3(spin, crank, tilt)
 crank += command.y * delta * 7.0
 spin += (-3.0 if slipping else command.y * 9.0) * delta
 tilt = lerpf(tilt, command.x * 0.16, 1.0 - exp(-12.0 * delta))
 if absf(tilt - command.x * 0.16) < 0.00001:
  tilt = command.x * 0.16
 if model is DetailedReelVisual: model.advance(delta, maxf(0, command.y), 1.0 if slipping else 0.0)
 if not _redraw_needed and not continuous_rendering and previous == Vector3(spin, crank, tilt):
  return
 _apply_pose()
 $Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
 _redraw_needed = false

func _apply_pose() -> void:
 model.rotation.z = tilt
 if model is DetailedReelVisual: return
 spool_pivot.rotation = spool_axis * spin
 crank_pivot.rotation = (Vector3.UP if spool_axis == Vector3.UP else Vector3.RIGHT) * crank

func line_guide_screen_position() -> Vector2:
 var camera: Camera3D = $Viewport/Camera
 var guide: Node3D = guide_pivot
 var point := camera.unproject_position(guide.global_position) / Vector2($Viewport.size) * size
 return get_global_transform_with_canvas() * point

