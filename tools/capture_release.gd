extends SceneTree

func _initialize() -> void:
 call_deferred("_run")

func _capture(path: String) -> void:
 for frame in range(20):
  await process_frame
 await RenderingServer.frame_post_draw
 var result := root.get_texture().get_image().save_png(path)
 assert(result == OK, "Screenshot failed")

func _run() -> void:
 root.size = Vector2i(1280, 720)
 change_scene_to_file("res://features/menu/main_menu.tscn")
 await process_frame
 await _capture("res://exports/play-store/01-menu.png")
 current_scene._on_play_pressed()
 await process_frame
 await process_frame
 assert(current_scene.name == "Gameplay")
 await _capture("res://exports/play-store/02-lakeside.png")
 var player: CharacterBody3D = current_scene.get_node("Player")
 var start := player.position
 Input.action_press("move_forward")
 for frame in range(40):
  await physics_frame
 Input.action_release("move_forward")
 assert(player.position.distance_to(start) > 0.1, "Movement failed")
 await _capture("res://exports/play-store/03-dock.png")
 current_scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await process_frame
 await process_frame
 assert(current_scene.name == "MainMenu", "Android back failed")
 root.size = Vector2i(1600, 720)
 await _capture("res://exports/play-store/qa-menu-wide.png")
 print("RELEASE_SMOKE_PASS: menu, play, movement, Android back, captures")
 quit()
