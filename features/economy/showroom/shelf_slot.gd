class_name ShopShelfSlot
extends Node3D
var item: TackleItem
var model: Node3D

func clear() -> void:
 item = null
 if has_node("FitBadge"):$FitBadge.text=""
 if is_instance_valid(model):
  $Socket.remove_child(model)
  model.queue_free()
 model = null

func mount(entry: TackleItem) -> AABB:
 clear()
 item = entry
 if item == null or item.model_scene == null: return AABB()
 model = item.model_scene.instantiate() as Node3D
 $Socket.add_child(model)
 if model is FishingRodVisual:
  model.set_load(0, 0)
  if is_instance_valid(model.held_reel):
   model.held_reel.get_parent().remove_child(model.held_reel)
   model.held_reel.queue_free();model.held_reel=null
  if item.mount_layout in ["spinning", "fly", "ice", "fixed"]: model.rotation.y = PI
  for path in ["GuideLine", "FeedLine"]:
   if model.has_node(path): model.get_node(path).hide()
 else:
  model.rotation.y = -.12
 _freeze(model)
 return local_bounds()

func _freeze(node: Node) -> void:
 node.set_process(false); node.set_physics_process(false)
 for child in node.get_children(): _freeze(child)

func _points(node: Node3D) -> PackedVector3Array:
 var points := PackedVector3Array()
 if node is MeshInstance3D and node.visible and node.mesh != null:
  for i in 8: points.append($Socket.to_local(node.global_transform * node.get_aabb().get_endpoint(i)))
 for child in node.get_children():
  if child is Node3D: points.append_array(_points(child))
 return points

func local_bounds() -> AABB:
 if not is_instance_valid(model): return AABB()
 var points := _points(model)
 if points.is_empty(): return AABB()
 var box := AABB(points[0], Vector3.ZERO)
 for point in points: box = box.expand(point)
 return box

func place(scale_value: float) -> void:
 if not is_instance_valid(model): return
 model.scale = Vector3.ONE * scale_value
 var box := local_bounds()
 model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)

func hit_distance(origin: Vector3, direction: Vector3) -> float:
 if item == null: return INF
 var hit: CollisionShape3D = $Hit/Shape
 var shape := hit.shape as BoxShape3D
 var box := AABB(-shape.size * .5, shape.size)
 var inverse := hit.global_transform.affine_inverse()
 var point: Variant = box.intersects_ray(inverse * origin, inverse.basis * direction)
 return origin.distance_to(hit.global_transform * point) if point is Vector3 else INF
