extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var boat: FishingBoat = load("res://actors/boat/fishing_boat.tscn").instantiate()
 root.add_child(boat)
 var triangles := 0
 var meshes := 0
 var materials := {}
 for node in boat.get_node("Model").find_children("*", "MeshInstance3D", true, false):
  meshes += 1
  for surface in node.mesh.get_surface_count():
   triangles += node.mesh.surface_get_array_index_len(surface) / 3
   var material: Material = node.mesh.surface_get_material(surface)
   materials[material.get_instance_id()] = true
 assert(meshes == 5, "boat has five editable mesh components")
 assert(triangles == 3511, "evaluated GLB triangle budget includes cooler")
 assert(materials.size() == 1, "all components share one atlas material")
 assert(is_equal_approx(boat.driver_anchor.position.y, 0.28))
 assert(is_equal_approx(boat.fishing_anchor.position.y, 0.36))
 print("BOAT MODEL RESULT: ", triangles, " triangles, ", meshes, " meshes, one material; anchors preserved")
 boat.queue_free()
 await process_frame
 quit(0)
