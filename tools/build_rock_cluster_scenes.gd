extends SceneTree
func _initialize() -> void:
 var gallery: Node3D=load("res://assets/environment/rocks/rock_clusters_20_21.glb").instantiate()
 root.add_child(gallery)
 var meshes:=gallery.find_children("*","MeshInstance3D",true,false)
 assert(meshes.size()==5)
 var folder:="res://world/river/props/rock_clusters_20_21"
 DirAccess.make_dir_recursive_absolute(folder)
 for model: MeshInstance3D in meshes:
  var label:=String(model.name).to_lower()
  var mesh_path:=folder.path_join(label+"_mesh.tres")
  var shape_path:=folder.path_join(label+"_collision.tres")
  assert(ResourceSaver.save(model.mesh,mesh_path)==OK)
  var shape: Shape3D=model.mesh.create_trimesh_shape() if label.begins_with("rock_") else model.mesh.create_convex_shape(true,true)
  assert(ResourceSaver.save(shape,shape_path)==OK)
  var source:='[gd_scene format=3]\n[ext_resource type="ArrayMesh" path="%s" id="mesh"]\n[ext_resource type="Shape3D" path="%s" id="shape"]\n[node name="%s" type="StaticBody3D"]\n[node name="Visual" type="MeshInstance3D" parent="."]\nmesh = ExtResource("mesh")\n[node name="CollisionShape3D" type="CollisionShape3D" parent="."]\nshape = ExtResource("shape")\n'%[mesh_path,shape_path,model.name]
  var file:=FileAccess.open(folder.path_join(label+".tscn"),FileAccess.WRITE)
  file.store_string(source)
  print("ROCK SCENE ",label,": ",model.mesh.surface_get_array_index_len(0)/3," triangles, ",shape.get_class()," collider")
 gallery.free()
 quit()
