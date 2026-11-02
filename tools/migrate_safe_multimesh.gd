extends SceneTree
const BATCH = preload("res://world/rainforest_lake/foliage_batch.gd")
var report: Array = []
func _initialize() -> void: call_deferred("run")
func visit(node: Node, root_node: Node, records: Array) -> void:
 if node is MultiMeshInstance3D and node.owner==root_node and node.get_script()==null and node.multimesh!=null:
  var old: MultiMesh=node.multimesh
  var transforms: Array[Transform3D]=[]
  var colors: Array[Color]=[]
  for i in old.instance_count:
   transforms.append(old.get_instance_transform(i))
   colors.append(old.get_instance_color(i) if old.use_colors else Color.WHITE)
  records.append({"node":str(root_node.get_path_to(node)),"count":old.instance_count,"mesh":old.mesh.resource_path,"transforms":var_to_str(transforms),"colors":var_to_str(colors)})
  var mesh: Mesh=old.mesh
  node.set_script(BATCH)
  node.authored_mesh=mesh
  node.authored_transforms=transforms
  node.authored_colors=colors
  node.multimesh=null
 for child in node.get_children(): visit(child,root_node,records)
func scan(path: String, candidates: Array[String]) -> void:
 for directory in DirAccess.get_directories_at(path): scan(path.path_join(directory),candidates)
 for filename in DirAccess.get_files_at(path):
  if filename.ends_with(".tscn"):
   var file:=path.path_join(filename)
   if FileAccess.get_file_as_string(file).contains('[sub_resource type="MultiMesh"'): candidates.append(file)
func run() -> void:
 var candidates: Array[String]=[]
 scan("res://world",candidates)
 for path in candidates:
  print("CONVERT ",path)
  var scene: PackedScene=load(path)
  var root_node=scene.instantiate()
  var records: Array=[]
  visit(root_node,root_node,records)
  if not records.is_empty():
   var packed:=PackedScene.new()
   assert(packed.pack(root_node)==OK)
   assert(ResourceSaver.save(packed,path)==OK)
   report.append({"path":path,"batches":records})
  root_node.free()
 var f=FileAccess.open("res://../output/multimesh-fix/before-data.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 print("CONVERTED SCENES ",report.size())
 quit()
