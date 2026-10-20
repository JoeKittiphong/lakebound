extends SubViewportContainer

@export var reel_scene: PackedScene = preload("res://features/equipment/reels/baitcaster.tscn")
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
 return true

func _update_rendering() -> void:
 $Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
 if not is_visible_in_tree():
  return
 crank += command.y * delta * 7.0
 spin += (-3.0 if slipping and absf(command.y) < 0.1 else command.y * 9.0) * delta
 tilt = lerpf(tilt, command.x * 0.16, 1.0 - exp(-12.0 * delta))
 _apply_pose()

func _apply_pose() -> void:
 model.rotation.z = tilt
 model.get_node("Spool").rotation.x = spin
 model.get_node("Crank").rotation.x = crank
