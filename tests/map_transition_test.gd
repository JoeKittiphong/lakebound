extends SceneTree

var failures := 0

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
 else:
  print("PASS: ", message)

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.get_node("AnglerSave").data.identity.name = "Map QA"
 for entry in RegionCatalog.MAPS:
  change_scene_to_file("res://features/menu/main_menu.tscn")
  await scene_changed
  var old_scene: WeakRef = weakref(current_scene)
  var menu: Control = current_scene
  menu._select_region(entry.id)
  menu._on_play_pressed()
  menu = null
  await scene_changed
  expect(current_scene.scene_file_path.ends_with("map_transition.tscn"), "light transition for " + entry.id)
  expect(old_scene.get_ref() == null, "old cinematic freed before map request: " + entry.id)
  var deadline := Time.get_ticks_msec() + 30000
  while (not is_instance_valid(current_scene) or current_scene.scene_file_path != entry.scene) and Time.get_ticks_msec() < deadline:
   await process_frame
  expect(is_instance_valid(current_scene) and current_scene.scene_file_path == entry.scene, "selected map ready: " + entry.id)
  if is_instance_valid(current_scene) and current_scene.scene_file_path == entry.scene:
   expect(current_scene.map_id == entry.id, "correct map save namespace: " + entry.id)
 # A missing scene must leave a usable error screen instead of quitting.
 set_meta("pending_map_scene", "res://missing-map.tscn")
 change_scene_to_file("res://features/loading/map_transition.tscn")
 await scene_changed
 for frame in 5:
  await process_frame
 expect(current_scene.get_node("Center/Content/Retry").visible, "load failure offers retry")
 current_scene._on_back_pressed()
 await scene_changed
 expect(current_scene.scene_file_path.ends_with("main_menu.tscn"), "failed load can return to menu")
 current_scene.queue_free()
 await process_frame
 print("MAP TRANSITION RESULT: ", failures, " failures")
 quit(0 if failures == 0 else 1)
