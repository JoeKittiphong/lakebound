extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func frames() -> void:
 for frame in 8:
  await process_frame
 await RenderingServer.frame_post_draw
func run() -> void:
 var reel: SubViewportContainer = load("res://shared/ui/reel_control.tscn").instantiate()
 root.add_child(reel)
 var viewport: SubViewport = reel.get_node("Viewport")
 await frames()
 # Godot's node getter retains UPDATE_ONCE; RenderingServer consumes that
 # request internally. The getter is not the server's post-frame update state.
 expect(viewport.render_target_update_mode == SubViewport.UPDATE_ONCE and not reel._redraw_needed and viewport.get_texture().get_width() > 0, "idle reel retains a rendered texture with a consumed one-shot request")
 var cached_draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
 reel.continuous_rendering = true
 await frames()
 var continuous_draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
 expect(continuous_draws > cached_draws, "cached idle reel reduces measured draw calls compared with continuous redraw")
 print("REEL DRAW CALLS cached=", cached_draws, " continuous=", continuous_draws)
 reel.continuous_rendering = false
 var start: float = reel.spin
 reel.command = Vector2(0.5, 1)
 await frames()
 expect(reel.spin > start and reel.crank > 0 and reel.tilt > 0, "winding and lateral input still animate the real pivots")
 reel.command = Vector2.ZERO
 for frame in 100:
  await process_frame
 await RenderingServer.frame_post_draw
 start = reel.spin
 await frames()
 expect(reel.spin == start and not reel._redraw_needed and viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "settled neutral pose returns to cached rendering")
 reel.size = Vector2(256, 256)
 await frames()
 expect(viewport.get_texture().get_image().get_used_rect().has_area(), "resizing an idle reel refreshes its image instead of leaving a blank cache")
 reel.slipping = true
 await frames()
 expect(reel.spin < start, "brake slip continues to animate and request redraws without input")
 reel.slipping = false
 reel.hide()
 await frames()
 expect(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden reel disables rendering")
 reel.show()
 await frames()
 expect(viewport.get_texture().get_image().get_size().x > 0, "showing the reel refreshes its cached image")
 expect(reel.equip(load("res://features/equipment/reels/baitcaster.tscn")), "equipment replacement remains supported")
 await frames()
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("reel-cached.png"))
 reel.queue_free()
 await process_frame
 print("REEL RENDER RESULT: ", failures, " failures")
 quit(failures)
