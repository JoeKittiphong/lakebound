extends Node3D

var record: RefCounted
var preview_mode := false
@onready var model: FishModel = $Model

func setup(fish: RefCounted) -> void:
 record = fish
 preview_mode = false
 set_process(true)
 var definition: Resource = fish.species
 if definition.model_scene == null:
  push_error("Fish species has no authored model: " + String(definition.id))
  hide()
  return
 if model.scene_file_path != definition.model_scene.resource_path:
  remove_child(model)
  model.queue_free()
  model = definition.model_scene.instantiate()
  model.name = "Model"
  add_child(model)
 var typical_weight: float = (definition.min_weight + definition.max_weight) * 0.5
 var size_factor := clampf(pow(fish.weight / typical_weight, 1.0 / 3.0), 0.6, 1.4)
 scale = Vector3.ONE * definition.visual_length_m * size_factor * definition.body_scale
 model.set_motion(fish.state, fish.stamina)
 model.reset_phase(fish.id)
 model.set_active(is_visible_in_tree())

func _process(_delta: float) -> void:
 if record == null or not is_visible_in_tree():
  return
 if preview_mode:
  model.set_motion(&"resting")
 else:
  model.set_motion(record.state, record.stamina)

func configure_preview(animated: bool = false) -> void:
 preview_mode = true
 basis = Basis(Vector3.RIGHT, deg_to_rad(record.species.preview_tilt_degrees)) * Basis(Vector3.UP, PI * 0.5)
 set_process(animated)
 if animated:
  model.set_motion(&"resting")
  model.set_active(true)
 else:
  model.freeze_preview()

func set_animation_active(value: bool) -> void:
 model.set_active(value)

func _notification(what: int) -> void:
 if what == NOTIFICATION_VISIBILITY_CHANGED and is_instance_valid(model):
  model.set_active(is_visible_in_tree() and (not preview_mode or is_processing()))
