extends SceneTree
func _initialize() -> void:
 var model: Node3D = load("res://assets/environment/rocks/rock_mobile.glb").instantiate()
 root.add_child(model)
 var meshes := model.find_children("*", "MeshInstance3D", true, false)
 if model is MeshInstance3D:meshes.push_front(model)
 assert(meshes.size()==1)
 var shape: ConvexPolygonShape3D = meshes[0].mesh.create_convex_shape(true,true)
 assert(shape.points.size()>=4)
 var status := ResourceSaver.save(shape,"res://world/river/props/rock_mobile_collision.tres")
 print("ROCK COLLISION: ",shape.points.size()," convex points, save=",status)
 model.free()
 quit(int(status!=OK))
