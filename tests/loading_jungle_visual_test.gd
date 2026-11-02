extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	root.get_node("FishCollection").recording_enabled = false
	var screen = load("res://features/loading/loading.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	await create_timer(9.5).timeout
	for size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
		root.size = size
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		var path = OS.get_environment("LAKEBOUND_QA_DIR").path_join("loading_%dx%d.png" % [size.x,size.y])
		root.get_texture().get_image().save_png(path)
		print("CAPTURE ",path," DRAW CALLS ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," PRIMITIVES ",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("LOADING JUNGLE VISUAL: three loading-screen aspect ratios rendered")
	quit()
