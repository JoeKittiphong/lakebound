extends SceneTree

var report := {"nodes": 0, "mesh_nodes": 0, "multimesh_groups": 0, "multimesh_instances": 0, "unique_mesh_resources": 0, "by_branch": {}}
var meshes := {}

func _initialize() -> void:
 call_deferred("run")

func walk(node: Node, branch: String) -> void:
 report.nodes += 1
 if not report.by_branch.has(branch):
  report.by_branch[branch] = {"nodes": 0, "meshes": 0, "batches": 0, "instances": 0}
 var entry: Dictionary = report.by_branch[branch]
 entry.nodes += 1
 if node is MeshInstance3D and node.mesh != null:
  report.mesh_nodes += 1
  entry.meshes += 1
  meshes[node.mesh.get_instance_id()] = true
 if node is MultiMeshInstance3D and node.multimesh != null:
  report.multimesh_groups += 1
  report.multimesh_instances += node.multimesh.instance_count
  entry.batches += 1
  entry.instances += node.multimesh.instance_count
  if node.multimesh.mesh != null:
   meshes[node.multimesh.mesh.get_instance_id()] = true
 for child in node.get_children():
  walk(child, String(child.name) if node.name == "RiverWorld" else branch)

func run() -> void:
 var scene: Node = load("res://world/river/river_world.tscn").instantiate()
 walk(scene, String(scene.name))
 report.unique_mesh_resources = meshes.size()
 DirAccess.make_dir_recursive_absolute("res://exports/size-audit")
 var file := FileAccess.open("res://exports/size-audit/scene.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, " "))
 file.close()
 print("SCENE SIZE AUDIT RESULT: ", JSON.stringify(report))
 scene.free()
 quit()
