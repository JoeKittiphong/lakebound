extends SceneTree

const Gestures = preload("res://features/fishing/lure_gestures.gd")
var checks := 0
var failures := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: " + message)

func frames(count: int = 4) -> void:
 for frame in count:
  await process_frame

func touch(id: int, down: bool, point: Vector2, canceled: bool = false) -> void:
 var event := InputEventScreenTouch.new()
 event.index = id
 event.pressed = down
 event.position = point
 event.canceled = canceled
 root.push_input(event, true)

func drag(id: int, point: Vector2) -> void:
 var event := InputEventScreenDrag.new()
 event.index = id
 event.position = point
 root.push_input(event, true)

func capture(name: String) -> void:
 if output.is_empty() or DisplayServer.get_name() == "headless":
  return
 await frames(6)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/" + name + ".png")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var gestures := Gestures.new()
 var event: Dictionary
 for side in [-1, 1, -1, 1]:
  event = gestures.advance(0.4, Vector2(side, 0), "walk_the_dog")
 expect(event.pattern == "Walk the Dog", "four alternating timed twitches complete Walk the Dog")
 expect(not gestures.advance(1.0, Vector2.RIGHT, "walk_the_dog").pattern, "holding a direction cannot repeat the reward")
 gestures.reset()
 for side in [-1, 1, -1, 1, -1, 1]:
  event = gestures.advance(0.03, Vector2(side, 0), "walk_the_dog")
 expect(event.pattern.is_empty() and gestures.walk_steps == 1, "rapid stick spam does not complete a rhythm")
 gestures.reset()
 for side in [-1, 1, -1, 1]:
  event = gestures.advance(1.1, Vector2(side, 0), "walk_the_dog")
 expect(event.pattern.is_empty(), "overlong pauses expire the sequence")
 gestures.reset()
 for side in [-1, 1, -1, 1]:
  event = gestures.advance(0.4, Vector2(side, 0), "stop_and_go")
 expect(event.pattern.is_empty(), "a lure only rewards its authored technique")
 gestures.reset()
 for cycle in 2:
  gestures.advance(0.4, Vector2.DOWN, "stop_and_go")
  event = gestures.advance(0.3, Vector2.ZERO, "stop_and_go")
 expect(event.pattern == "Stop & Go", "two sustained retrieves with real pauses complete Stop and Go")
 gestures.reset()
 expect(gestures.advance(0.1, Vector2.UP, "stop_and_go").jerk, "upward edge triggers a jerk immediately")
 expect(not gestures.advance(0.5, Vector2.UP, "stop_and_go").jerk, "holding up does not machine-gun jerks")
 gestures.advance(0.1, Vector2.ZERO, "stop_and_go")
 expect(gestures.advance(0.1, Vector2.UP, "stop_and_go").jerk, "returning to center rearms a jerk")
 gestures.reset()
 expect(gestures.advance(0.2, Vector2(0.1, -0.1), "walk_the_dog").side == 0, "small thumb jitter is ignored")
 gestures.reset()
 for cycle in 8:
  gestures.advance(0.1, Vector2.DOWN, "stop_and_go")
  event = gestures.advance(0.3, Vector2.ZERO, "stop_and_go")
 expect(event.pattern.is_empty() and gestures.stop_cycles == 0, "brief taps cannot accumulate into sustained retrieves")
 var positions: Array[Vector3] = []
 for side in [-1.0, 1.0]:
  var fish := FishState.new()
  fish.species = load("res://data/fish/tilapia.tres")
  fish.id = 400
  fish.weight = 1.0
  fish.position = Vector3(10, 1, 0)
  var simulation := FightSimulation.new()
  simulation.line_length = 11.0
  simulation.advance(0.1, Vector3.ZERO, fish, Vector2(side, 0), FishingTuning.new())
  positions.append(fish.position)
 expect(positions[0].z < positions[1].z, "opposite rod pressures change the hooked fish's real lateral path")

 root.size = Vector2i(1280, 720)
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 await frames(10)
 scene.set_process(false)
 var controller: FishingController = scene.get_node("FishingController")
 var pond: PondEcosystem = scene.get_node("PondEcosystem")
 var player: AnglerPlayer = scene.get_node("Player")
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var camera: AnglerCameraRig = scene.get_node("CameraRig")
 controller.set_physics_process(false)
 pond.set_physics_process(false)
 player.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 var profile := AnglerProfile.new()
 profile.data = profile.defaults()
 profile.data.equipped.bait = "minnow"
 controller.bind_profile(profile)
 controller.cast_position = pond.constrain_to_water(player.global_position + Vector3(10, 1.5, 0))
 controller.cast_position.y = 1.5
 controller.line_length = 20.0
 pond.set_bait(controller.cast_position, &"lure")
 controller._change_state(controller.State.WAITING)
 controller.advance(0.02, player.global_position)
 var original := controller.cast_position
 controller.rod_input = Vector2.UP
 controller.advance(0.1, player.global_position)
 expect(controller.cast_position.y < original.y, "jerk moves the actual underwater lure upward")
 var depth := controller.cast_position.y
 controller.advance(0.1, player.global_position)
 expect(is_equal_approx(controller.cast_position.y, depth), "held jerk does not keep lifting a swimming lure")
 controller.rod_input = Vector2.ZERO
 controller.advance(0.1, player.global_position)
 original = controller.cast_position
 controller.rod_input = Vector2.LEFT
 controller.advance(0.1, player.global_position)
 expect(absf(controller.cast_position.z - original.z) > 0.2, "side twitch changes the real lateral bait position")
 expect(pond.bait_position == controller.cast_position, "ecosystem and lure visuals share the same position")
 controller.rod_input = Vector2.ZERO
 controller.advance(0.1, player.global_position)
 for cycle in 2:
  controller.rod_input = Vector2.DOWN
  controller.advance(0.4, player.global_position)
  controller.rod_input = Vector2.ZERO
  controller.advance(0.3, player.global_position)
 expect(is_equal_approx(pond.lure_appeal, 0.2), "successful rhythm grants the capped temporary detection bonus")
 pond.step(1.0)
 expect(pond.lure_appeal < 0.2, "appeal decays instead of stacking permanently")
 pond.reserved_fish = null
 profile.data.equipped.bait = "soft_plastic"
 controller.cast_position.y = 0.12
 original = controller.cast_position
 controller.advance(0.2, player.global_position)
 expect(controller.cast_position.y > original.y, "neutral sinking lure falls naturally")
 profile.data.equipped.bait = "frog"
 controller.advance(0.1, player.global_position)
 expect(is_equal_approx(controller.cast_position.y, 0.12), "neutral floating lure remains on the surface")
 profile.data.equipped.bait = "minnow"
 controller.cast_position.y = 1.5

 for resolution in [Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1024, 768)]:
  root.size = resolution
  await frames()
  controller.rod_input = Vector2.ZERO
  controller._change_state(controller.State.WAITING)
  controller.advance(0.01, player.global_position)
  await frames()
  player.set_fishing_animation_state(controller.State.WAITING, 0.0, 0.0)
  player.character_model.update_motion(0.1, false, 0.0, false)
  var rod := hud.rod_joystick
  var reel: Control = rod
  var safe: Control = hud.get_node("SafeArea")
  expect(not rod.has_node("Reel") and rod.get_node("Base").visible and rod.get_node("Knob").visible, "analog control remains visible without the HUD reel at %s" % resolution)
  expect(not rod.has_node("Reel"), "the duplicate reel viewport has been removed at %s" % resolution)
  expect(safe.get_global_rect().encloses(reel.get_global_rect()) and safe.get_global_rect().encloses(rod.get_global_rect()), "both controls remain in the mobile safe region at %s" % resolution)
  expect(not hud.move_joystick.get_global_rect().intersects(reel.get_global_rect()), "reel does not overlap the walking thumb at %s" % resolution)
  var center := rod.get_global_rect().get_center()
  var left_center := hud.move_joystick.get_global_rect().get_center()
  var yaw := camera.rotation.y
  touch(0, true, left_center + Vector2(0, -40))
  touch(1, true, center)
  drag(1, center + Vector2(48, 48))
  expect(hud.move_joystick.touch_index == 0 and rod.touch_index == 1 and rod.direction.x > 0.4 and rod.direction.y > 0.4, "two independent thumbs support diagonal rod control at %s" % resolution)
  expect(is_equal_approx(camera.rotation.y, yaw), "rod gesture does not drag the camera at %s" % resolution)
  touch(0, false, left_center)
  touch(1, false, center)
  await capture("lure_%dx%d" % [resolution.x, resolution.y])
  var fish: FishState = pond.fish[0]
  fish.position = controller.cast_position
  pond.reserved_fish = fish
  controller.rod_input = Vector2.DOWN
  touch(1, true, center + Vector2(0, 50))
  controller._on_fish_biting(fish)
  drag(1, center + Vector2(0, 60))
  controller.rod_input = rod.direction
  controller.advance(0.02, player.global_position)
  expect(controller.state == controller.State.BITE and rod.direction == Vector2.ZERO, "held retrieve cannot auto-strike across the bite transition at %s" % resolution)
  touch(1, false, center)
  controller.rod_input = Vector2.ZERO
  controller.advance(0.02, player.global_position)
  touch(1, true, center + Vector2(0, 50))
  controller.rod_input = rod.direction
  controller.advance(0.02, player.global_position)
  expect(controller.state == controller.State.FIGHT, "a fresh downward touch strikes the same fish at %s" % resolution)
  drag(1, center + Vector2(50, 50))
  expect(rod.direction == Vector2.ZERO, "strike gesture must release before fighting at %s" % resolution)
  touch(1, false, center)
  controller.rod_input = Vector2.ZERO
  controller.advance(0.02, player.global_position)
  controller.tension = (controller.yellow_start + controller.red_start) * 0.5
  player.set_rod_pose(true, controller.tension, 0.0)
  player.set_fishing_animation_state(controller.State.FIGHT, 0.0, controller.tension)
  player.character_model.update_motion(0.1, false, 0.0, false)
  player.character_model.set_rod_load(controller.tension, 0.0)
  await frames()
  expect(hud.meter.get_global_rect().end.x < reel.get_global_rect().position.x and safe.get_global_rect().encloses(hud.meter.get_global_rect()), "original tension meter remains left of the reel and readable at %s" % resolution)
  expect(not hud.get_node("SafeArea/LineInfo").get_global_rect().intersects(reel.get_global_rect()), "line readout does not cover the reel at %s" % resolution)
  expect(not hud.get_node("SafeArea/OrbitButton").is_visible_in_tree(), "orbit button does not cover the original reel at %s" % resolution)
  await capture("fight_%dx%d" % [resolution.x, resolution.y])
  touch(1, true, center + Vector2(-45, -45))
  scene.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
  expect(rod.direction == Vector2.ZERO and rod.touch_index == -1, "focus loss clears the rod finger at %s" % resolution)
  controller.cancel()
  pond.reserved_fish = null
  controller.cast_position = pond.constrain_to_water(player.global_position + Vector3(10, 1.5, 0))
  controller.cast_position.y = 1.5
  pond.set_bait(controller.cast_position, &"lure")
  controller._change_state(controller.State.WAITING)
 scene.queue_free()
 await process_frame
 profile.free()
 print("LURE CONTROL RESULT: %d checks, %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
