extends SceneTree

var failures := 0

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error("FAIL: " + message)

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var screen: Control = load("res://features/loading/loading.tscn").instantiate()
 # A loadable resource of the wrong type exercises error handling without a missing-file log.
 screen.next_scene_path = "res://shared/ui/game_theme.tres"
 root.add_child(screen)
 current_scene = screen
 screen._on_start_pressed()
 expect(current_scene == screen, "early Start cannot leave the loading screen")
 var deadline := Time.get_ticks_msec() + 10000
 while not screen.failed and Time.get_ticks_msec() < deadline:
  await process_frame
 expect(screen.failed and screen.retry_button.visible, "invalid destination shows retry instead of transitioning")
 expect(not screen.start_button.visible, "failed load cannot expose Start")
 screen.next_scene_path = "res://features/menu/main_menu_ui.tscn"
 screen._on_retry_pressed()
 expect(not screen.retry_button.visible and not screen.failed, "retry resets error UI")
 deadline = Time.get_ticks_msec() + 20000
 while not screen.ready_to_start and Time.get_ticks_msec() < deadline:
  await create_timer(0.02).timeout
 expect(screen.ready_to_start, "retry reaches ready with a valid scene")
 expect(screen.cinematic.finished, "retry preserves and completes the cinematic")
 var settled_position: Vector3 = screen.cinematic.actor_motion.position
 await create_timer(1.0).timeout
 expect(screen.cinematic.actor_motion.position.is_equal_approx(settled_position), "waiting loop does not restart the walk")
 expect(current_scene == screen, "ready state remains visible until input")
 if screen.ready_to_start:
  screen._on_start_pressed()
  screen._on_start_pressed()
  await process_frame
  await process_frame
  expect(current_scene == screen and is_instance_valid(screen.menu_ui), "double tap opens the menu on the existing scene")
  expect(screen.get_children().filter(func(child: Node) -> bool: return child.name == &"MainMenuUI").size() == 1, "double tap creates only one menu UI")
 if is_instance_valid(current_scene):
  current_scene.queue_free()
 await process_frame
 await process_frame
 # Allow the audio mixing thread to release stopped preview streams before quitting.
 await create_timer(0.1).timeout
 print("LOADING FLOW RESULT: ", failures, " failures")
 quit(0 if failures == 0 else 1)
