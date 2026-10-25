extends SceneTree

var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")
var scene: Node3D
var controller: FishingController
var pond: PondEcosystem
var hud: FishingHUD
var profile: AnglerProfile

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func frames() -> void:
 for i in 6:
  await process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw

func capture(name: String) -> void:
 await frames()
 if DisplayServer.get_name() != "headless":
  root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func click(control: Control) -> void:
 var point := control.get_global_rect().get_center()
 var motion := InputEventMouseMotion.new()
 motion.position = point
 root.push_input(motion, true)
 for down in [true, false]:
  var event := InputEventMouseButton.new()
  event.position = point
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = down
  root.push_input(event, true)
  await process_frame
 await frames()

func land(fish: FishState, bait: String = "worm", depth: float = 1.0) -> void:
 controller.reset_cast()
 profile.equip(bait)
 controller.cast_bait_id = bait
 controller._change_state(FishingController.State.WAITING)
 controller.cast_position = Vector3(fish.position.x, depth, fish.position.z)
 controller._on_fish_biting(fish)
 controller._change_state(FishingController.State.RESULT)
 controller.fish_landed.emit(fish)

func run() -> void:
 if output.is_empty():
  output = "res://exports/qa-missions/screenshots"
 DirAccess.make_dir_recursive_absolute(output)
 profile = root.get_node("AnglerSave")
 profile.save_path = "user://mission-visual-%d.cfg" % Time.get_ticks_usec()
 profile.data = profile.defaults()
 var collection := root.get_node("FishCollection")
 collection.records.clear()
 collection.recording_enabled = false
 scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 hud = scene.get_node("HUD/FishingHUD")
 var tutorial = hud.get_node("SafeArea/FirstCatch")
 tutorial.save_path = "user://mission-tutorial-%d.cfg" % Time.get_ticks_usec()
 root.add_child(scene)
 current_scene = scene
 scene.set_process(false)
 controller = scene.get_node("FishingController")
 pond = scene.get_node("PondEcosystem")
 controller.set_physics_process(false)
 pond.set_physics_process(false)
 scene.get_node("Player").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 await frames()
 expect(tutorial.active and not profile.data.missions.started, "fresh tutorial precedes missions")
 expect(not hud.get_node("SafeArea/TackleButton").visible, "bag button does not overlap tutorial card")
 await capture("missions-tutorial-1280")
 hud._on_missions_pressed()
 expect(not hud.get_node("MissionPanel").visible and not paused, "mission modal cannot interrupt tutorial")
 var first: FishState = pond.fish[0]
 land(first)
 expect(not profile.data.missions.started and profile.data.missions.entries.is_empty(), "tutorial landing excluded even after completion signal")
 controller.resolve_catch(false)
 tutorial._process(10.0)
 scene._start_missions_if_ready()
 expect(profile.data.missions.started, "missions activate after tutorial finishes")
 hud._process(0.0)
 await capture("missions-hud-1280")
 land(first)
 expect(MissionProgress.entry(profile.data.missions, MissionCatalog.find("first_three")).progress == 1, "real gameplay landing advances mission")
 controller.resolve_catch(false)
 land(first)
 controller.resolve_catch(false)
 expect(MissionProgress.entry(profile.data.missions, MissionCatalog.find("first_three")).progress == 1, "release and recatch path does not farm same fish")
 var second: FishState = pond.fish[1]
 land(second)
 controller.resolve_catch(true)
 expect(profile.data.catches.size() == 1 and second not in pond.fish, "keep path still stores actual fish")
 land(pond.fish[2])
 controller.resolve_catch(false)
 hud._process(0.1)
 expect(hud.get_node("SafeArea/MissionToast").visible, "completion toast shown after result closes")
 await capture("missions-complete-1280")
 var panel: Control = hud.get_node("MissionPanel")
 for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 720)]:
  root.size = viewport_size
  await frames()
  await click(hud.get_node("SafeArea/MissionButton"))
  expect(panel.visible and paused and not scene.get_node("CameraRig").enabled, "mission button opens modal and pauses camera %d" % viewport_size.x)
  expect(panel.rows.size() == 12, "twelve editable row instances")
  for tier in 4:
   panel.get_node("Card/Content/Tiers").current_tab = tier
   await frames()
   var visible_rows := 0
   for row in panel.rows:
    visible_rows += int(row.visible)
   expect(visible_rows == 3, "tier filter %d at %d" % [tier, viewport_size.x])
   var scroll: ScrollContainer = panel.get_node("Card/Content/Scroll")
   expect(scroll.size.x <= root.size.x and scroll.size.y > 180, "list fits viewport and scrolls %d" % viewport_size.x)
   await capture("missions-tier-%d-%d" % [tier, viewport_size.x])
   scroll.scroll_vertical = 100000
   await frames()
   var last_row: Control = panel.rows[tier * 3 + 2]
   expect(scroll.get_global_rect().encloses(last_row.get_node("Content/Footer/Claim").get_global_rect()), "last reward reachable by scrolling tier %d at %d" % [tier, viewport_size.x])
   scroll.scroll_vertical = 0
  panel.get_node("Card/Content/Tiers").current_tab = 0
  await frames()
  var before: int = profile.data.coins
  var row: Control = panel.rows[0]
  if viewport_size.x == 1280:
   expect(not row.get_node("Content/Footer/Claim").disabled, "completed reward button enabled")
   await click(row.get_node("Content/Footer/Claim"))
   expect(profile.data.coins == before + 20 and row.get_node("Content/Footer/Claim").disabled, "real claim button pays then disables")
   row.get_node("Content/Footer/Claim").pressed.emit()
   expect(profile.data.coins == before + 20, "duplicate UI claim cannot pay twice")
   panel.rows[2].get_node("Content/Footer/Track").pressed.emit()
   expect(profile.data.missions.tracked == "two_species", "row track button persists selected mission")
  await capture("missions-claimed-%d" % viewport_size.x)
  scene._on_back_pressed()
  expect(not panel.visible and not paused and scene.get_node("CameraRig").enabled, "back closes mission modal and restores simulation")
  hud._process(0.0)
  expect(hud.get_node("SafeArea/MissionTracker").visible, "one tracked mission appears in gameplay")
  await capture("missions-tracker-%d" % viewport_size.x)
 controller._change_state(FishingController.State.FIGHT)
 hud._process(0.0)
 expect(not hud.get_node("SafeArea/MissionButton").visible and not hud.get_node("SafeArea/MissionTracker").visible, "mission HUD does not obstruct fishing fight")
 controller.reset_cast()
 var old_path := profile.save_path
 land(pond.fish[3])
 # A fresh event whose first attempt fails must remain on the result screen.
 controller.resolve_catch(false)
 profile.save_path = "user://missing-mission-directory/profile.cfg"
 land(pond.fish[4])
 var catch_id: String = controller.catch_record.catch_id
 controller.resolve_catch(false)
 expect(controller.state == FishingController.State.RESULT, "save failure preserves catch result for retry")
 profile.save_path = old_path
 controller.resolve_catch(false)
 expect(controller.state == FishingController.State.READY and profile.data.journal[-1].catch_id == catch_id, "retry persists same landed event once")
 collection.records.clear()
 var skip_tutorial: Control = load("res://features/tutorial/first_catch.tscn").instantiate()
 skip_tutorial.save_path = "user://mission-skip-%d.cfg" % Time.get_ticks_usec()
 root.add_child(skip_tutorial)
 skip_tutorial.bind(controller, hud)
 await frames()
 expect(skip_tutorial.active, "fresh optional tutorial can be skipped")
 await click(skip_tutorial.get_node("Card/Content/Skip"))
 var saved := ConfigFile.new()
 expect(not skip_tutorial.active and saved.load(skip_tutorial.save_path) == OK and saved.get_value("tutorial", "completed", false), "skip button persists tutorial completion")
 skip_tutorial.free()
 scene.free()
 expect(not paused, "session cleanup restores pause")
 print("MISSIONS VISUAL RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
