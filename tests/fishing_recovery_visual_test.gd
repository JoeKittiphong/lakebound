extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func capture(name: String) -> void:
 for frame in 3:
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR") + "/" + name + ".png")
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 for frame in 30:
  await physics_frame
 scene.set_process(false)
 var controller: FishingController = scene.get_node("FishingController")
 controller.set_physics_process(false)
 controller.haptics_enabled = false
 scene.get_node("PondEcosystem").set_physics_process(false)
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 var profile := AnglerProfile.new()
 profile.data = profile.defaults()
 controller.profile = profile
 controller.refresh_equipment()
 for resolution in [Vector2i(1280, 720), Vector2i(2340, 1080)]:
  root.size = resolution
  for frame in 5:
   await process_frame
  profile.data.catches = [{"weight": profile.equipped("box").capacity * 0.85}]
  profile.data.stock.worm = 0
  controller.reset_cast()
  hud._process(0.01)
  expect(hud.get_node("SafeArea/FishBox/Row/Icon").texture != null, "fish box illustration imported")
  expect(hud.get_node("SafeArea/CastReason").visible and "เหยื่อหมด" in hud.get_node("SafeArea/CastReason").text, "cast reason visible at " + str(resolution))
  expect(not hud.get_node("SafeArea/FishBox").get_global_rect().intersects(hud.get_node("SafeArea/BackButton").get_global_rect()), "box does not overlap Back at " + str(resolution))
  await capture("bait-empty-" + str(resolution.x))
  profile.data.stock.worm = 20
  profile.data.line_remaining = 0
  profile.data.catches = [{"weight": profile.equipped("box").capacity}]
  await capture("line-empty-box-full-" + str(resolution.x))
  profile.data.line_remaining = 65
  var fish := FishState.new()
  fish.species = load("res://data/fish/tilapia.tres")
  fish.id = 2
  fish.weight = 2
  fish.position = controller.ecosystem.constrain_to_water(controller.get_aim_position())
  controller.active_fish = fish
  controller.fight.begin(fish)
  controller.line_length = Vector2(fish.position.x - controller.player.global_position.x, fish.position.z - controller.player.global_position.z).length() + 0.3
  controller.fight.line_strength = 80
  controller.tension = 1.0
  controller._change_state(FishingController.State.FIGHT)
  for frame in 3:
   await process_frame
  var rod := hud.rod_joystick
  var point := rod.get_global_rect().get_center()
  var press := InputEventScreenTouch.new()
  press.index = 8
  press.pressed = true
  press.position = point
  root.push_input(press, true)
  var drag := InputEventScreenDrag.new()
  drag.index = 8
  drag.position = point - Vector2(0, rod.radius)
  drag.relative = Vector2(0, -rod.radius)
  root.push_input(drag, true)
  expect(rod.direction.y < -0.95, "upward touch sends full payout at " + str(resolution))
  var recovered := false
  for tick in 65:
   controller.rod_input = hud.rod_direction()
   controller._fight_step(1.0 / 60.0, controller.player.global_position)
   if controller.tension >= controller.yellow_start and controller.tension < controller.red_start:
    recovered = true
    break
  expect(recovered, "real touch recovers red into yellow at " + str(resolution))
  hud._process(0.01)
  await capture("fight-recovered-" + str(resolution.x))
  var release := InputEventScreenTouch.new()
  release.index = 8
  release.position = drag.position
  root.push_input(release, true)
  expect(rod.direction == Vector2.ZERO, "finger release clears command")
  controller.reset_cast()
 controller.profile = null
 profile.free()
 scene.queue_free()
 await process_frame
 await process_frame
 print("FISHING RECOVERY VISUAL RESULT: ", failures, " failures")
 quit(failures)
