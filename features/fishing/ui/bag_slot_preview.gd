extends Control
## Small static 3D stage shared by the eight bag slots.
@export_range(1.0, 1.5) var frame_padding := 1.12
@export var rod_rotation := Vector3(0, 0, -32)
@export_range(0.2, 0.8) var visible_rod_shaft := 0.32
@export var equipment_rotation := Vector3(-12, -20, -12)
@export var fish_rotation := Vector3(0, 78, 0)
var resource: Resource
var model: Node3D
var _generation := 0
@onready var viewport: SubViewport = $View/Viewport
@onready var pivot: Node3D = $View/Viewport/Stage/Pivot
@onready var camera: Camera3D = $View/Viewport/Stage/Camera
func _ready() -> void:
 visibility_changed.connect(_visibility_changed)
 resized.connect(_resize_preview)
func set_resource(value: Resource) -> void:
 if resource == value:
  return
 resource = value
 _clear()
 if is_visible_in_tree():_load_model()
func _visibility_changed() -> void:
 if not is_node_ready():return
 if is_visible_in_tree():
  if model == null:_load_model()
 else:_clear()
func _clear() -> void:
 _generation += 1
 if is_instance_valid(model):
  pivot.remove_child(model)
  model.queue_free()
 model = null
 viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
func _load_model() -> void:
 if resource == null or resource.model_scene == null:return
 _generation += 1
 var generation := _generation
 model = resource.model_scene.instantiate() as Node3D
 pivot.add_child(model)
 if resource is TackleItem and resource.kind == "rod":
  model.rotation_degrees = rod_rotation
  if model is FishingRodVisual:
   model.set_load(0, 0)
   if is_instance_valid(model.held_reel):
    model.held_reel.get_parent().remove_child(model.held_reel)
    model.held_reel.queue_free()
    model.held_reel = null
   for path in ["GuideLine", "FeedLine"]:
    if model.has_node(path):model.get_node(path).hide()
 elif resource is FishSpecies:
  model.rotation_degrees = fish_rotation
 else:model.rotation_degrees = equipment_rotation
 _freeze(model)
 await get_tree().process_frame
 if generation != _generation or not is_instance_valid(model):return
 _fit()
 viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
func _freeze(node: Node) -> void:
 if node is AnimationPlayer:
  node.pause()
 node.set_process(false)
 node.set_physics_process(false)
 for child in node.get_children():_freeze(child)
func _points(node: Node3D) -> PackedVector3Array:
 var points := PackedVector3Array()
 if not node.visible:return points
 if node is MeshInstance3D and node.mesh != null:
  for i in 8:points.append(node.global_transform * node.get_aabb().get_endpoint(i))
 for child in node.get_children():
  if child is Node3D:points.append_array(_points(child))
 return points
func _framing_points() -> PackedVector3Array:
 if model is DetailedFishingRod:
  var grip: float = model.config.grip_x
  var end: float = minf(model.config.length - grip, visible_rod_shaft)
  var box := AABB(Vector3(-0.12, -grip, -0.15), Vector3(0.24, end + grip, 0.30))
  var points := PackedVector3Array()
  for i in 8:points.append(model.global_transform * box.get_endpoint(i))
  return points
 return _points(model)
func _fit() -> void:
 var points := _framing_points()
 if points.is_empty():return
 var bounds := AABB(points[0], Vector3.ZERO)
 for point in points:bounds = bounds.expand(point)
 model.position -= pivot.to_local(bounds.get_center())
 var side := -1.0 if resource is TackleItem and resource.kind == "rod" else 1.0
 camera.position = Vector3(0.7, 0.5, side * 4.0).normalized() * maxf(1.0, bounds.size.length() * 2.0)
 camera.look_at(Vector3.ZERO)
 points = _framing_points()
 var projected := AABB(camera.to_local(points[0]), Vector3.ZERO)
 for point in points:projected = projected.expand(camera.to_local(point))
 var aspect := float(viewport.size.x) / float(viewport.size.y)
 camera.size = maxf(0.015, maxf(projected.size.y, projected.size.x / aspect) * frame_padding)

func _resize_preview() -> void:
 if not is_node_ready():return
 var generation := _generation
 await get_tree().process_frame
 if generation != _generation or not is_instance_valid(model):return
 _fit()
 viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
