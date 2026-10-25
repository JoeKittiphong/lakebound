extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.size = Vector2i(1280, 720)
 var screen: Control = load("res://features/loading/loading.tscn").instantiate()
 root.add_child(screen)
 current_scene = screen
 var output := OS.get_environment("LAKEBOUND_QA_DIR")
 DirAccess.make_dir_recursive_absolute(output)
 var elapsed := 0.0
 for shot in [{"time": 0.5, "name": "01_establishing"}, {"time": 3.2, "name": "02_walking"}, {"time": 5.9, "name": "03_cast"}, {"time": 9.0, "name": "04_waiting"}]:
  await create_timer(float(shot.time) - elapsed).timeout
  elapsed = float(shot.time)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join(shot.name + ".png"))
  print("CAPTURE: ", shot.name, " actor=", screen.cinematic.actor_motion.position, " action=", screen.cinematic.angler.current_action, " ready=", screen.ready_to_start)
  if shot.name == "04_waiting":
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
 quit()
