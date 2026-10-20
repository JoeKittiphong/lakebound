extends SceneTree

func _initialize() -> void:
 call_deferred("inspect_models")

func inspect_models() -> void:
 var report := {}
 var directory := DirAccess.open("res://world/pond/models/glb")
 for filename in directory.get_files():
  if not filename.ends_with(".glb"):
   continue
  var model: Node3D = load("res://world/pond/models/glb/" + filename).instantiate()
  root.add_child(model)
  var item := {"animations": {}, "triangles": 0, "meshes": 0}
  var bounds := AABB()
  var first := true
  for node in model.find_children("*", "MeshInstance3D", true, false):
   item.meshes += 1
   var transformed: AABB = node.global_transform * node.get_aabb()
   bounds = transformed if first else bounds.merge(transformed)
   first = false
   for surface in node.mesh.get_surface_count():
    item.triangles += node.mesh.surface_get_array_index_len(surface) / 3
   var material: BaseMaterial3D = node.get_active_material(0)
   item["cull_mode"] = material.cull_mode
   item["texture_size"] = str(material.albedo_texture.get_size())
  for player in model.find_children("*", "AnimationPlayer", true, false):
   item["animation_player_path"] = str(model.get_path_to(player))
   for clip in player.get_animation_list():
    var animation: Animation = player.get_animation(clip)
    item.animations[clip] = {"length": animation.length, "loop": animation.loop_mode, "tracks": animation.get_track_count()}
  item["bounds_position"] = str(bounds.position)
  item["bounds_size"] = str(bounds.size)
  report[filename.get_basename()] = item
  if filename == "tilapia.glb":
   model.print_tree_pretty()
  model.free()
 var file := FileAccess.open("res://exports/qa-fish-models/import-report.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 print("INSPECTED FISH: ", report.size())
 quit()
