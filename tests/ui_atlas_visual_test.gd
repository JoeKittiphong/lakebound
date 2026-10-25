extends SceneTree

var checks := 0
var failures := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error("FAIL: " + message)

func capture(name: String) -> void:
 for i in 8:
  await process_frame
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "rendered " + name)

func run() -> void:
 if output.is_empty():
  output = "res://exports/qa-ui-atlas/screenshots"
 DirAccess.make_dir_recursive_absolute(output)
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://atlas-visual-%d.cfg" % Time.get_ticks_usec()
 profile.data = profile.defaults()
 root.get_node("FishCollection").recording_enabled = false
 for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 720)]:
  root.size = viewport_size
  var suffix := str(viewport_size.x)
  var menu: Control = load("res://features/menu/main_menu.tscn").instantiate()
  root.add_child(menu)
  current_scene = menu
  await capture("atlas-menu-" + suffix)
  var play: Button = menu.get_node("SafeArea/PlayCard/Content/PlayButton")
  expect(play.get_theme_stylebox("normal") is StyleBoxTexture, "menu play is generated atlas " + suffix)
  menu.free()
  var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
  var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
  var tutorial = hud.get_node("SafeArea/FirstCatch")
  tutorial.save_path = "user://atlas-tutorial-%s-%d.cfg" % [suffix, Time.get_ticks_usec()]
  root.get_node("FishCollection").records.clear()
  root.add_child(scene)
  current_scene = scene
  scene.set_process(false)
  var controller: FishingController = scene.get_node("FishingController")
  var pond: PondEcosystem = scene.get_node("PondEcosystem")
  controller.set_physics_process(false)
  pond.set_physics_process(false)
  scene.get_node("Player").set_physics_process(false)
  scene.get_node("FishingEffects").audio_enabled = false
  await capture("atlas-tutorial-" + suffix)
  tutorial._skip()
  scene._start_missions_if_ready()
  await capture("atlas-hud-" + suffix)
  hud._on_missions_pressed()
  expect(paused and hud.get_node("MissionPanel").visible, "atlas mission button works " + suffix)
  await capture("atlas-missions-" + suffix)
  hud.get_node("MissionPanel").close()
  hud._on_tackle_pressed()
  expect(paused and hud.get_node("TacklePanel").visible, "atlas bag button works " + suffix)
  await capture("atlas-shop-" + suffix)
  hud.get_node("TacklePanel").close()
  hud._on_collection_pressed()
  expect(paused and hud.get_node("CollectionPanel").visible, "atlas journal button works " + suffix)
  await capture("atlas-collection-" + suffix)
  hud.close_collection()
  var fish: FishState = pond.fish[0]
  controller.active_fish = fish
  controller.cast_bait_id = "worm"
  controller._change_state(FishingController.State.RESULT)
  controller.fish_landed.emit(fish)
  await capture("atlas-catch-" + suffix)
  controller.resolve_catch(false)
  expect(controller.state == FishingController.State.READY and not paused, "atlas catch release preserves gameplay " + suffix)
  scene.free()
  var loading: Control = load("res://features/loading/loading.tscn").instantiate()
  loading.minimum_display_seconds = 3600.0
  root.add_child(loading)
  current_scene = loading
  loading.set_process(false)
  var bar: ProgressBar = loading.get_node("SafeArea/LoadPanel/Content/SwimmingProgress/ProgressBar")
  bar.value = 65.0
  loading.get_node("SafeArea/LoadPanel/Content/StatusRow/Percent").text = "65%"
  expect(bar.get_theme_stylebox("fill") is StyleBoxFlat, "3D loading screen uses the editable clean progress style " + suffix)
  await capture("atlas-loading-" + suffix)
  ResourceLoader.load_threaded_get(loading.next_scene_path)
  loading.free()
 print("UI ATLAS VISUAL RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
