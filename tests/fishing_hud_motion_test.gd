extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
func frames(count: int = 3) -> void:
 for i in count:
  await process_frame
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = "res://../output/fishing-hud-motion/test-profile.cfg"
 profile.data.equipped.bait = "minnow"
 var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 await frames(8)
 scene.set_process(false)
 scene.player.set_physics_process(false)
 scene.fishing.set_physics_process(false)
 scene.pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 scene.hud.get_node("SafeArea/FirstCatch").active = false
 scene.hud.get_node("SafeArea/FirstCatch").hide()
 scene.fishing.bind_profile(profile)
 expect(not scene.hud.rod_joystick.has_node("Reel"), "HUD reel viewport is removed")
 expect(not scene.hud.move_joystick.has_node("Reel"), "movement joystick does not allocate a reel viewport")
 var view: FishingEquipmentView = scene.camera_rig.get_node("FishingCamera3D/EquipmentView")
 view.set_process(false)
 for state in [FishingController.State.CASTING, FishingController.State.WAITING, FishingController.State.BITE, FishingController.State.FIGHT]:
  scene.fishing._change_state(state)
  scene._on_fishing_state_changed()
  for aboard in [false, true]:
   scene.hud.set_boat_state(true, aboard, false, true, true)
   await frames()
   scene.hud._process(0)
   for path in ["BaitDock", "OrbitButton", "BoatActions", "TopBar", "RankingButton", "Minimap", "RodInstructions", "MovementActions"]:
    expect(not scene.hud.get_node("SafeArea/" + path).is_visible_in_tree(), "hide non-fishing HUD: " + path)
 for resolution in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1024,768)]:
  root.size = resolution
  scene.fishing._change_state(FishingController.State.WAITING)
  scene._on_fishing_state_changed()
  await frames()
  var status: Control = scene.hud.get_node("SafeArea/Status")
  var safe: Control = scene.hud.get_node("SafeArea")
  var rhythm: Control = status.get_node("Content/LureRhythm")
  expect(rhythm.is_visible_in_tree(), "lure recipe actually visible")
  expect(rhythm.get_child_count() == 2, "formula is exactly two authored lines")
  expect(safe.get_global_rect().encloses(status.get_global_rect()), "top formula fits safe area")
  expect(status.global_position.y <= safe.global_position.y + 12, "announcement is at safe top")
  expect(not status.get_global_rect().intersects(scene.hud.rod_joystick.get_global_rect()), "announcement leaves rod controls clear")
  expect(not scene.hud.get_node("SafeArea/LineInfo").get_global_rect().intersects(scene.hud.rod_joystick.get_global_rect()), "line readout stays clear of joystick")
  for side in [-1.0, 1.0]:
   view.visual_stick = Vector2.ZERO
   view.stick_velocity = Vector2.ZERO
   for i in range(120): view.update_rod_pose(1.0 / 120, Vector2(side, 0))
   var camera: Camera3D = view.get_parent()
   var point := camera.unproject_position(view.rod.handle_pivot_world())
   expect(absf(point.x - camera.get_viewport().get_visible_rect().size.x * 0.5) < 0.1, "handle stays centered during both sweeps")
   expect(absf(view.socket.rotation.y) > deg_to_rad(35), "rod turns with lateral sweep")
   var before: float = view.visual_stick.x
   view.update_rod_pose(1.0 / 60, Vector2.ZERO)
   expect(absf(view.visual_stick.x) > 0.9 and absf(before-view.visual_stick.x) < 0.04, "release does not snap")
   for i in range(72): view.update_rod_pose(1.0 / 120, Vector2.ZERO)
   expect(absf(view.visual_stick.x) < 0.025 and view.visual_stick.x * side >= 0, "release settles without oscillation")
 # Compare equivalent time sampled at different frame rates.
 var outcomes: Array[Vector2] = []
 for fps in [30, 60, 120]:
  view.visual_stick = Vector2.ZERO
  view.stick_velocity = Vector2.ZERO
  for i in range(fps): view.update_rod_pose(1.0/fps, Vector2.RIGHT)
  for i in range(fps / 2): view.update_rod_pose(1.0/fps, Vector2.ZERO)
  outcomes.append(view.visual_stick)
 expect(outcomes[0].distance_to(outcomes[2]) < 0.0001, "smooth return is frame-rate independent")
 scene.fishing._change_state(FishingController.State.FIGHT)
 scene.fishing.active_fish = scene.pond.fish[0]
 scene.fishing.tension = 0.7
 scene._on_fishing_state_changed()
 scene.fishing.rod_input = Vector2.ZERO
 for side in [-1.0, 1.0]:
  var camera: Camera3D = view.get_parent()
  scene.fishing.active_fish.position = scene.player.global_position - camera.global_basis.z * 12 + camera.global_basis.x * 10 * side
  scene.fishing.active_fish.position.y = 1.0
  for i in range(120): view._process(1.0 / 120)
  var target: Vector3 = scene.fishing.active_fish.position
  target.y = -0.18 - target.y
  var actual := (target-view.rod.tip.global_position).normalized()
  expect(view.rod.pull_direction.dot(actual) > 0.995, "bend follows the actual fish")
  expect(view.rod.ribbon.endpoint_error < 0.00001, "line remains through all guides")
 scene.fishing._change_state(FishingController.State.READY)
 scene._on_fishing_state_changed()
 scene.hud.set_boat_state(true, false, false, true, true)
 await frames()
 expect(scene.hud.get_node("SafeArea/BaitDock").is_visible_in_tree(), "bait/depth restored after retrieval")
 expect(scene.hud.get_node("SafeArea/OrbitButton").is_visible_in_tree(), "eye restored after retrieval")
 expect(scene.hud.get_node("SafeArea/BoatActions").is_visible_in_tree(), "boat actions restored after retrieval")
 scene.queue_free()
 await process_frame
 print("FISHING HUD / MOTION: %d checks, %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

