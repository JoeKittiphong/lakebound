extends SubViewportContainer

@export var reel_scene: PackedScene = preload("res://features/equipment/reels/baitcaster.tscn")
## Enable for replacement models with autonomous animations or time shaders.
@export var continuous_rendering := false
var _redraw_needed := true
var spin := 0.0
var crank := 0.0
var tilt := 0.0
var command := Vector2.ZERO
var slipping := false
@onready var model: Node3D = $Viewport/Model

func _ready() -> void:
 if reel_scene != null and model.scene_file_path != reel_scene.resource_path:
  equip(reel_scene)
 visibility_changed.connect(_update_rendering)
 resized.connect(_request_redraw)
 $Viewport.size_changed.connect(_request_redraw)
 _update_rendering()

# Future equipment selection can provide another scene with the same pivot names.
func equip(scene: PackedScene) -> bool:
 if scene == null:
  return false
 var replacement := scene.instantiate()
 if not replacement is Node3D or not replacement.get_node_or_null("Spool") is Node3D or not replacement.get_node_or_null("Crank") is Node3D:
  replacement.free()
  return false
 $Viewport.remove_child(model)
 model.queue_free()
 model = replacement
 $Viewport.add_child(model)
 reel_scene = scene
 _apply_pose()
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
 spin += (-3.0 if slipping and absf(command.y) < 0.1 else command.y * 9.0) * delta
 tilt = lerpf(tilt, command.x * 0.16, 1.0 - exp(-12.0 * delta))
 if absf(tilt - command.x * 0.16) < 0.00001:
  tilt = command.x * 0.16
 if not _redraw_needed and not continuous_rendering and previous == Vector3(spin, crank, tilt):
  return
 _apply_pose()
 $Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
 _redraw_needed = false

func _apply_pose() -> void:
 model.rotation.z = tilt
 model.get_node("Spool").rotation.x = spin
 model.get_node("Crank").rotation.x = crank

func line_guide_screen_position() -> Vector2:
 var camera: Camera3D = $Viewport/Camera
 var guide: Node3D = model.get_node("Guide")
 var point := camera.unproject_position(guide.global_position) / Vector2($Viewport.size) * size
 return get_global_transform_with_canvas() * point
