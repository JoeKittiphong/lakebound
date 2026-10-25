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
 expect(ResourceLoader.exists("res://assets/ui/modern/eye.svg"), "runtime orbit icon survives export filters")
 var loading: Control = load("res://features/loading/loading.tscn").instantiate()
 loading.minimum_display_seconds = 0.05
 root.add_child(loading)
 current_scene = loading
 var original_cinematic: Node3D = loading.cinematic
 var cinematic_id: int = original_cinematic.get_instance_id()
 var original_camera: Camera3D = original_cinematic.get_node("Camera3D")
 var started := Time.get_ticks_msec()
 while is_instance_valid(loading) and not loading.ready_to_start and Time.get_ticks_msec() - started < 20000:
  if loading.failed:
   break
  await create_timer(0.01).timeout
 expect(is_instance_valid(loading) and loading.ready_to_start, "loading becomes ready after the cinematic and threaded resources finish")
 if is_instance_valid(loading) and loading.ready_to_start:
  expect(current_scene == loading, "ready screen waits for player input")
  expect(loading.cinematic.finished, "angler finishes walking and casting before Start appears")
  expect(loading.cinematic.bobber.visible, "cast leaves a floating bobber in the lake")
  expect(loading.cinematic.angler.rod_mesh.visible, "angler keeps the rod while waiting")
  loading.start_button.pressed.emit()
  await process_frame
  await process_frame
 var menu_ready := is_instance_valid(loading) and is_instance_valid(loading.menu_ui)
 expect(menu_ready, "threaded loading displays the main menu UI")
 if menu_ready:
  expect(current_scene == loading and loading.cinematic.get_instance_id() == cinematic_id, "Start preserves the exact live 3D scene")
  expect(root.get_camera_3d() == original_camera, "Start preserves the active camera")
  expect(loading.cinematic.stage == loading.cinematic.Stage.WAITING, "main menu keeps the angler waiting instead of replaying the intro")
  expect(not loading.get_node("SafeArea").visible, "loading controls are hidden beneath the main menu UI")
  # Play now opens a region scene inheriting Gameplay, not gameplay.tscn
  # itself. Wait for the asynchronous scene change and assert its exact route.
  var selected_region: String = loading.menu_ui.selected_region
  var expected_scene: String = RegionCatalog.find(selected_region).scene
  loading.menu_ui._on_play_pressed()
  var deadline := Time.get_ticks_msec() + 10000
  while (not is_instance_valid(current_scene) or current_scene.scene_file_path != expected_scene) and Time.get_ticks_msec() < deadline:
   await process_frame
  var gameplay_ready := is_instance_valid(current_scene) and current_scene.scene_file_path == expected_scene
  expect(gameplay_ready, "menu Play opens the selected region's composed gameplay session")
  if gameplay_ready:
   var session := current_scene
   expect(session.map_id == selected_region, "selected region retains its save namespace")
   session.get_node("FishingEffects").audio_enabled = false
   session._on_back_pressed()
   await process_frame
   await process_frame
   expect(current_scene.scene_file_path == "res://features/menu/main_menu.tscn", "session Back returns to menu without leaving a paused tree")
   expect(current_scene.get_node("Cinematic").finished, "returning from gameplay starts directly in the waiting scene")
   expect(not paused, "navigation preserves an active scene tree")
 if is_instance_valid(current_scene):
  current_scene.queue_free()
 await process_frame
 await process_frame
 await create_timer(0.1).timeout
 print("STARTUP RESULT: ", failures, " failures")
 quit(0 if failures == 0 else 1)
