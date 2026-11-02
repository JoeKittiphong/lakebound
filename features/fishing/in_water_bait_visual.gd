extends Node3D
var item:TackleItem
var instance:Node3D
func set_item(value:TackleItem)->void:
 if value==item and is_instance_valid(instance):return
 release_model();item=value
 if item==null or item.model_scene==null:return
 instance=item.model_scene.instantiate() as Node3D
 $Model.add_child(instance)
 if item.attraction!=null:
  instance.rotation_degrees=item.attraction.model_rotation_degrees
  var box:=_bounds(instance)
  instance.scale*=item.attraction.visual_length_m/maxf(maxf(box.size.x,box.size.y),maxf(box.size.z,.001))
 var ties:=instance.find_children("*LineTie*","Node3D",true,false)
 if not ties.is_empty():instance.position-=$Model.to_local((ties[0] as Node3D).global_position)
 elif item.attraction!=null:instance.position-=item.attraction.attachment_offset*instance.scale
 _freeze(instance)
func _bounds(node:Node3D)->AABB:
 var points:=PackedVector3Array()
 _points(node,points)
 if points.is_empty():return AABB(Vector3.ZERO,Vector3.ONE*.1)
 var box:=AABB(points[0],Vector3.ZERO)
 for point in points:box=box.expand(point)
 return box
func _points(node:Node3D,result:PackedVector3Array)->void:
 if node is MeshInstance3D and node.mesh!=null:
  for i in 8:result.append($Model.to_local(node.global_transform*node.get_aabb().get_endpoint(i)))
 for child in node.get_children():
  if child is Node3D:_points(child,result)
func _freeze(node:Node)->void:
 node.set_process(false);node.set_physics_process(false)
 if node is GeometryInstance3D:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children():_freeze(child)
func release_model()->void:
 if is_instance_valid(instance):
  instance.get_parent().remove_child(instance);instance.queue_free()
 instance=null;item=null
