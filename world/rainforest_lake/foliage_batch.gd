@tool
extends MultiMeshInstance3D
## CPU-side authored data survives headless builds; a GPU MultiMesh buffer is rebuilt on entering the tree.
@export var authored_mesh: Mesh
@export var authored_transforms: Array[Transform3D]=[]
@export var authored_colors: Array[Color]=[]

func _validate_property(property: Dictionary) -> void:
 if property.name=="multimesh":property.usage=PROPERTY_USAGE_EDITOR

func _enter_tree() -> void:
 if authored_mesh==null:return
 var mm:=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_colors=true
 mm.mesh=authored_mesh
 mm.instance_count=authored_transforms.size()
 for i in authored_transforms.size():
  mm.set_instance_transform(i,authored_transforms[i])
  mm.set_instance_color(i,authored_colors[i] if i<authored_colors.size() else Color.WHITE)
 multimesh=mm

func _exit_tree() -> void:
 multimesh=null
