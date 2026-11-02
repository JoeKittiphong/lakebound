extends SceneTree
var failures := 0
var scene: Node3D

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ",message)
 failures += int(not ok)

func deck_height(point: Vector3) -> float:
 var result := -INF
 for mesh: MeshInstance3D in scene.get_node("Dock/Visual").find_children("*","MeshInstance3D",true,false):
  if mesh.mesh == null: continue
  var inverse := mesh.global_transform.affine_inverse()
  var origin := inverse * (point + Vector3.UP * 3.0)
  var direction := inverse.basis * Vector3.DOWN
  for surface in mesh.mesh.get_surface_count():
   var arrays := mesh.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   var count := indices.size() if not indices.is_empty() else vertices.size()
   for i in range(0,count,3):
    var a := indices[i] if not indices.is_empty() else i
    var b := indices[i+1] if not indices.is_empty() else i+1
    var c := indices[i+2] if not indices.is_empty() else i+2
    var hit: Variant = Geometry3D.ray_intersects_triangle(origin,direction,vertices[a],vertices[b],vertices[c])
    if hit != null:
     result = maxf(result,mesh.to_global(hit).y)
 return result

func run() -> void:
 scene = load("res://features/loading/cinematic/loading_cinematic.tscn").instantiate()
 scene.play_intro = false
 root.add_child(scene)
 var cooler: Node3D = scene.get_node("Dock/IceCooler")
 check(not scene.has_node("Dock/TackleBox") and not scene.has_node("Dock/TackleLid"),"old loading box removed")
 var heights: Array = []
 for offset in [Vector3.ZERO,Vector3(-0.32,0,-0.16),Vector3(0.32,0,-0.16),Vector3(-0.32,0,0.16),Vector3(0.32,0,0.16)]:
  var point := cooler.to_global(offset)
  var height := deck_height(point)
  heights.append(height)
  print("DECK CONTACT sample=",offset," deck=",height," base=",point.y," gap=",point.y-height)
  check(is_finite(height),"cooler footprint is supported by actual wooden bridge mesh")
  check(absf(point.y-height) < 0.002,"cooler base rests on actual wooden surface within 2mm")
 var mesh_min := INF
 for mesh: MeshInstance3D in cooler.get_node("Body").find_children("*","MeshInstance3D",true,false):
  var bounds: AABB = (cooler.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
  mesh_min = minf(mesh_min,bounds.position.y)
 check(absf(mesh_min)<0.001,"imported cooler origin matches actual mesh bottom")
 if DisplayServer.get_name() != "headless":
  root.size = Vector2i(1280,720)
  for i in 8: await process_frame
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://exports/qa-loading-cooler")
  root.get_texture().get_image().save_png("res://exports/qa-loading-cooler/loading.png")
  var camera: Camera3D = scene.get_node("Camera3D")
  camera.look_at_from_position(cooler.global_position+Vector3(1.65,1.2,1.8),cooler.global_position+Vector3(0,0.22,0))
  for i in 5: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-loading-cooler/deck-contact.png")
 print("LOADING COOLER RESULT: ",failures," failures")
 scene.queue_free()
 await process_frame
 await process_frame
 quit(1 if failures else 0)

