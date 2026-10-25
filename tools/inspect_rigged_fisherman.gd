extends SceneTree

func _initialize() -> void:
 var path := "res://actors/player/models/fisherman_rigged.glb"
 var model := load(path).instantiate() as Node3D
 root.add_child(model)
 model.print_tree_pretty()
 for node in model.find_children("*", "MeshInstance3D", true, false):
  print("MESH: ", node.name, " bounds=", node.get_aabb())
  var total := 0
  for surface in node.mesh.get_surface_count():
   total += node.mesh.surface_get_array_index_len(surface) / 3
   var material := node.get_active_material(surface) as StandardMaterial3D
   print("MATERIAL: ", material, " texture=", material.albedo_texture if material != null else null)
  print("TRIANGLES: ", total)
 var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
 for bone in skeleton.get_bone_count():
  print("BONE: ", skeleton.get_bone_name(bone))
 var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
 print("CLIPS: ", player.get_animation_list())
 for name in player.get_animation_list():
  var clip := player.get_animation(name)
  print(name, " length=", clip.length, " tracks=", clip.get_track_count())
  if clip.get_track_count() > 0:
   print("TRACK: ", clip.track_get_path(0))
 model.queue_free()
 quit()
