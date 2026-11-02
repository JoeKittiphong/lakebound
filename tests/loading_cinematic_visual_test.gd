extends SceneTree
var failures := 0
func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ",message)
 if not ok: failures += 1

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.size = Vector2i(1280, 720)
 var screen: Control = load("res://features/loading/loading.tscn").instantiate()
 root.add_child(screen)
 current_scene = screen
 var school: Node3D = screen.cinematic.get_node("Scenery/FishSchool")
 var fish_start: Vector3 = school.get_child(0).position
 expect(school.get_child_count() == 6,"loading lake contains six animated 3D fish")
 var water: ShaderMaterial = screen.cinematic.get_node("Scenery/Lake").mesh.material
 expect(water.shader == load("res://world/water.gdshader") and water.get_shader_parameter("ripple_normal") != null,"loading uses gameplay water shader and ripple normals")
 expect(screen.cinematic.get_node("Scenery/BoatFloat/Boat").scene_file_path == "res://actors/boat/models/fishing_boat_b.glb","loading reuses the game boat model")
 var output := OS.get_environment("LAKEBOUND_QA_DIR")
 DirAccess.make_dir_recursive_absolute(output)
 var elapsed := 0.0
 for shot in [{"time": 0.5, "name": "01_establishing"}, {"time": 3.2, "name": "02_walking"}, {"time": 6.85, "name": "03_cast"}, {"time": 9.4, "name": "04_waiting"}]:
  await create_timer(float(shot.time) - elapsed).timeout
  elapsed = float(shot.time)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join(shot.name + ".png"))
  print("CAPTURE: ", shot.name, " actor=", screen.cinematic.actor_motion.position, " action=", screen.cinematic.angler.current_action, " ready=", screen.ready_to_start)
  if shot.name == "04_waiting":
   expect(school.get_child(0).position.distance_to(fish_start)>0.1,"fish swim while the intro plays")
   for fish in school.get_children():
    expect(fish.position.y < -0.2,"fish stay underwater")
    var previous_position: Vector3 = fish.position
    fish._process(0.01)
    var movement: Vector3 = fish.position - previous_position
    movement.y = 0.0
    expect((-fish.basis.z).dot(movement.normalized()) > 0.99,"fish nose faces swim direction")
   expect(absf(screen.cinematic.get_node("Scenery/BoatFloat").position.y)<0.06,"boat remains at the waterline while bobbing")
   print("DRAW CALLS: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " PRIMITIVES: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
 screen._on_start_pressed()
 await create_timer(0.4).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("07_main_menu.png"))
 root.size = Vector2i(1600, 720)
 await create_timer(0.3).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("05_wide.png"))
 root.size = Vector2i(1024, 768)
 await create_timer(0.3).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("06_tablet.png"))
 print("LOADING VISUAL RESULT: seven views rendered, including the continuous menu reveal")
 screen.queue_free()
 await process_frame
 await process_frame
 quit(1 if failures else 0)
