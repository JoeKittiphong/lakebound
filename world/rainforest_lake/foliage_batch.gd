@tool
extends MultiMeshInstance3D
## CPU-side authored data survives headless builds; a GPU MultiMesh buffer is rebuilt on entering the tree.
@export var authored_mesh: Mesh
@export var authored_transforms: Array[Transform3D]=[]
@export var authored_colors: Array[Color]=[]
## Large batches are partitioned spatially; each child retains all shadow/range settings.
@export_range(10.0, 50.0) var culling_cell_size := 25.0
@export var minimum_partition_instances := 24
var _partitions: Array[MultiMeshInstance3D] = []

func _validate_property(property: Dictionary) -> void:
 if property.name=="multimesh":property.usage=PROPERTY_USAGE_EDITOR

func _enter_tree() -> void:
 if authored_mesh==null:return
 var groups: Dictionary = {}
 if authored_transforms.size() >= minimum_partition_instances:
  for i in authored_transforms.size():
   var p := authored_transforms[i].origin
   var key := Vector2i(floori(p.x/culling_cell_size), floori(p.z/culling_cell_size))
   if not groups.has(key): groups[key] = []
   groups[key].append(i)
 if groups.size() > 1:
  multimesh = null
  for indices in groups.values():
   var part := MultiMeshInstance3D.new()
   part.name = "CullCell%d" % _partitions.size()
   for property in ["cast_shadow", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode", "layers", "material_override", "material_overlay", "lod_bias", "extra_cull_margin"]:
    part.set(property, get(property))
   part.multimesh = _make_batch(indices)
   add_child(part)
   _partitions.append(part)
  return
 multimesh = _make_batch(range(authored_transforms.size()))

func _make_batch(indices: Array) -> MultiMesh:
 var mm:=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_colors=true
 mm.mesh=authored_mesh
 mm.instance_count=indices.size()
 for local_index in indices.size():
  var i: int = indices[local_index]
  mm.set_instance_transform(local_index,authored_transforms[i])
  mm.set_instance_color(local_index,authored_colors[i] if i<authored_colors.size() else Color.WHITE)
 return mm

func _exit_tree() -> void:
 multimesh=null
 for part in _partitions:
  remove_child(part)
  part.queue_free()
 _partitions.clear()
