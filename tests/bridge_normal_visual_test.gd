extends SceneTree
var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")
func _initialize() -> void:
 call_deferred("run")
func expect(value: bool, label: String) -> void:
 checks += 1
 print("PASS: " if value else "FAIL: ", label)
 failures += int(not value)
func capture(label: String) -> Image:
 for i in 8:
  await process_frame
 await RenderingServer.frame_post_draw
 var picture := root.get_texture().get_image()
 picture.save_png(output.path_join(label + ".png"))
 return picture
func run() -> void:
 root.size = Vector2i(1200, 900)
 var scene: Node3D = load("res://world/river/props/wooden_bridge_preview.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var materials: Array[StandardMaterial3D] = []
 var triangles := 0
 var meshes := scene.get_node("Bridge").find_children("*", "MeshInstance3D", true, false)
 expect(meshes.size() == 1, "joined bridge imports as one mesh object")
 for mesh in meshes:
  for surface in mesh.mesh.get_surface_count():
   triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
   var arrays: Array = mesh.mesh.surface_get_arrays(surface)
   expect(arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty(), "wood atlas UVs survive GLB export")
   var material := mesh.get_active_material(surface) as StandardMaterial3D
   if not materials.has(material):
    materials.append(material)
 expect(triangles == 2168, "normal maps add no triangles to the bridge")
 for material in materials:
  expect(material.normal_enabled and material.normal_texture != null, "GLB imports normal map enabled")
  expect(material.albedo_texture != null, "baked wood albedo imports")
  expect(material.normal_texture.get_width() == 2048, "normal atlas retains 2048px resolution")
 if DisplayServer.get_name() != "headless":
  await capture("bridge_normal_full")
  var camera: Camera3D = scene.get_node("Camera3D")
  camera.size = 10.5
  camera.position = Vector3(9, 7.5, 13)
  camera.look_at(Vector3(0, 0.4, 10))
  for material in materials:
   material.normal_enabled = false
  var before := await capture("bridge_normal_off")
  for material in materials:
   material.normal_enabled = true
  var after := await capture("bridge_normal_on")
  var changed := 0
  for y in range(100, 800, 8):
   for x in range(100, 1100, 8):
    var a := before.get_pixel(x, y)
    var b := after.get_pixel(x, y)
    changed += int(absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b) > 0.025)
  expect(changed > 150, "normal map visibly changes wood lighting in Godot")
 scene.queue_free()
 await process_frame
 print("BRIDGE NORMAL RESULT: ", checks, " checks, ", failures, " failures")
 quit(int(failures > 0))
