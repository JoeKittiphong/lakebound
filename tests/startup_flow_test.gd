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
 var loading: Control = load("res://features/loading/loading.tscn").instantiate()
 loading.minimum_display_seconds = 0.05
 root.add_child(loading)
 current_scene = loading
 var started := Time.get_ticks_msec()
 while is_instance_valid(loading) and Time.get_ticks_msec() - started < 15000:
  if loading.failed:
   break
  await create_timer(0.01).timeout
 var menu_ready := is_instance_valid(current_scene) and current_scene.scene_file_path == "res://features/menu/main_menu.tscn"
 expect(menu_ready, "threaded loading reaches the menu with all gameplay dependencies")
 if menu_ready:
  current_scene._on_play_pressed()
  await process_frame
  await process_frame
  var gameplay_ready := current_scene.scene_file_path == "res://features/gameplay/gameplay.tscn"
  expect(gameplay_ready, "menu Play opens the composed gameplay session")
  if gameplay_ready:
   var session := current_scene
   session.get_node("FishingEffects").audio_enabled = false
   session._on_back_pressed()
   await process_frame
   await process_frame
   expect(current_scene.scene_file_path == "res://features/menu/main_menu.tscn", "session Back returns to menu without leaving a paused tree")
   expect(not paused, "navigation preserves an active scene tree")
 if is_instance_valid(current_scene):
  current_scene.queue_free()
 await process_frame
 await process_frame
 print("STARTUP RESULT: ", failures, " failures")
 quit(0 if failures == 0 else 1)
