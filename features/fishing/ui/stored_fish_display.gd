class_name StoredFishDisplay
extends Node3D

@export var fit_size := Vector3(1.22, 0.4, 1.12)
@export_range(-180.0, 180.0) var display_turn_degrees := 180.0
var record_index := -1
var disabled := true
var model: Node3D
var species_id := ""

func bind(record: Dictionary, index: int, selected: bool) -> void:
 record_index = index
 disabled = false
 visible = true
 var id := str(record.species)
 if model == null or id != species_id:
  if is_instance_valid(model):
   remove_child(model)
   model.queue_free()
   model = null
  var species := FishCatalog.find(StringName(id))
  if species == null or species.model_scene == null:
   bind_empty()
   return
  model = species.model_scene.instantiate() as Node3D
  add_child(model)
  species_id = id
  if model.has_method("freeze_preview"):
   model.freeze_preview()
  _freeze(model)
  # Lay the fish on its side and fit its real mesh to the compartment.
  model.rotation.z = PI * 0.5
  var bounds := mesh_bounds()
  if bounds.size.z > bounds.size.x:
   model.rotate_y(PI * 0.5)
  model.rotate_y(deg_to_rad(display_turn_degrees))
  bounds = mesh_bounds()
  var factor := minf(fit_size.x / maxf(bounds.size.x, 0.001), minf(fit_size.y / maxf(bounds.size.y, 0.001), fit_size.z / maxf(bounds.size.z, 0.001)))
  model.scale = Vector3.ONE * factor
  model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor + Vector3(0, 0.035, 0)
 $Number.text = str(index + 1)
 set_pressed_no_signal(selected)

func bind_empty() -> void:
 record_index = -1
 disabled = true
 visible = false
 if is_instance_valid(model):
  remove_child(model)
  model.queue_free()
 model = null
 species_id = ""

func set_pressed_no_signal(value: bool) -> void:
 $Selection.visible = value and not disabled

func _freeze(node: Node) -> void:
 if node is AnimationPlayer:
  node.stop()
  node.active = false
 node.set_process(false)
 node.set_physics_process(false)
 for child in node.get_children():
  _freeze(child)

func mesh_bounds() -> AABB:
 var result := AABB()
 var first := true
 if not is_instance_valid(model):
  return result
 for node in model.find_children("*", "MeshInstance3D", true, false):
  var mesh := node as MeshInstance3D
  var bounds: AABB = (global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
  if first:
   result = bounds
   first = false
  else:
   result = result.merge(bounds)
 return result

func pick_bounds() -> AABB:
 return mesh_bounds().grow(0.14)
