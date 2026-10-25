extends SceneTree

var failures := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 scene.set_process(false)
 var fishing: FishingController = scene.get_node("FishingController")
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var player: AnglerPlayer = scene.get_node("Player")
 var camera: AnglerCameraRig = scene.get_node("CameraRig")
 fishing.set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 # Traversal now requires grounded footing before a cast can start.
 for frame in 25:
  await physics_frame
 hud.get_node("SafeArea/FirstCatch")._skip()
 # The same physical drag starts as reeling, transitions to READY, then releases.
 for iteration in 20:
  fishing._change_state(FishingController.State.WAITING)
  hud.rod_joystick.drag_started.emit()
  fishing.cast_position = fishing.ecosystem.constrain_to_water(player.global_position)
  fishing.advance(0.1, player.global_position)
  hud.rod_joystick.drag_released.emit()
  expect(fishing.state == FishingController.State.READY, "Retrieval release does not recast %d" % iteration)
  hud.rod_joystick.drag_started.emit()
  hud.rod_joystick.drag_released.emit()
  expect(fishing.state == FishingController.State.CASTING, "Fresh gesture casts %d" % iteration)
  fishing.reset_cast()
 var yaw := camera.rotation.y
 var facing := player.visual.rotation.y
 hud.get_node("SafeArea/OrbitButton").orbit_started.emit()
 camera._process(1.0)
 expect(is_equal_approx(camera.rotation.y, yaw), "Holding eye without dragging does not rotate")
 camera.drag_orbit(-PI / camera.look_sensitivity)
 scene._process(0.0)
 expect(camera.orbiting and absf(angle_difference(yaw, camera.rotation.y)) > 3.0, "Holding button orbits to face")
 expect(is_equal_approx(player.visual.rotation.y, facing) and is_equal_approx(fishing.aim_yaw, yaw), "Orbit preserves character facing and cast heading")
 hud.get_node("SafeArea/OrbitButton").orbit_ended.emit()
 expect(not camera.orbiting and is_equal_approx(camera.rotation.y, yaw), "Release restores fishing view")
 camera.set_orbiting(true)
 camera.reset_input()
 expect(not camera.orbiting and is_equal_approx(camera.rotation.y, yaw), "Focus loss cancels orbit safely")
 var eye: Button = hud.get_node("SafeArea/OrbitButton")
 expect(eye.get_global_rect().end.x < hud.rod_joystick.get_global_rect().position.x, "Eye icon sits left of reel without overlapping touch pad")
 var eye_press := InputEventScreenTouch.new()
 eye_press.index = 19
 eye_press.position = eye.get_global_rect().get_center()
 eye_press.pressed = true
 eye._input(eye_press)
 camera._process(0.5)
 expect(camera.orbiting and is_equal_approx(camera.rotation.y, yaw), "Eye touch holds inspection without automatic spin")
 var eye_drag := InputEventScreenDrag.new()
 eye_drag.index = 19
 eye_drag.position = eye_press.position + Vector2(-150, 0)
 eye_drag.relative = Vector2(-150, 80)
 eye._input(eye_drag)
 expect(is_equal_approx(angle_difference(yaw, camera.rotation.y), 150 * camera.look_sensitivity), "Eye rotates proportionally to horizontal drag outside icon")
 var held_yaw := camera.rotation.y
 camera._process(0.5)
 expect(is_equal_approx(camera.rotation.y, held_yaw), "Camera stops rotating when finger stops moving")
 eye_drag.relative = Vector2(150, -80)
 eye._input(eye_drag)
 expect(is_equal_approx(angle_difference(yaw, camera.rotation.y), 0.0), "Reverse drag rotates back by the same amount")
 eye_press.pressed = false
 eye_press.position = eye_drag.position
 eye._input(eye_press)
 expect(not camera.orbiting, "Releasing outside eye ends inspection")
 # Exercise the actual joystick input path, including the held pointer across reset.
 for use_touch in [false, true]:
  fishing._change_state(FishingController.State.WAITING)
  var point := hud.rod_joystick.get_global_rect().get_center() + Vector2(0, 40)
  if use_touch:
   var press := InputEventScreenTouch.new()
   press.index = 7
   press.pressed = true
   press.position = point
   hud.rod_joystick._input(press)
  else:
   var press := InputEventMouseButton.new()
   press.button_index = MOUSE_BUTTON_LEFT
   press.pressed = true
   press.position = point
   hud.rod_joystick._input(press)
  fishing.cast_position = fishing.ecosystem.constrain_to_water(player.global_position)
  fishing.advance(0.1, player.global_position)
  var offset_before := fishing.aim_offset
  for frame in 30:
   if use_touch:
    var motion := InputEventScreenDrag.new()
    motion.index = 7
    motion.position = point + Vector2(0, 20)
    motion.relative = Vector2(0, 2)
    hud.rod_joystick._input(motion)
   else:
    var motion := InputEventMouseMotion.new()
    motion.position = point + Vector2(0, 20)
    motion.relative = Vector2(0, 2)
    hud.rod_joystick._input(motion)
   scene._process(0.016)
  expect(fishing.state == FishingController.State.READY and fishing.aim_offset == offset_before and hud.rod_direction() == Vector2.ZERO, "Held retrieval finger cannot aim or recast while moving")
  if use_touch:
   var release := InputEventScreenTouch.new()
   release.index = 7
   release.position = point
   hud.rod_joystick._input(release)
  else:
   var release := InputEventMouseButton.new()
   release.button_index = MOUSE_BUTTON_LEFT
   release.position = point
   hud.rod_joystick._input(release)
  expect(fishing.state == FishingController.State.READY, "Physical pointer release after retrieval waits for choice: touch=%s" % use_touch)
  if use_touch:
   var duplicate := InputEventMouseButton.new()
   duplicate.device = InputEvent.DEVICE_ID_EMULATION
   duplicate.button_index = MOUSE_BUTTON_LEFT
   duplicate.position = point
   duplicate.pressed = true
   hud.rod_joystick._input(duplicate)
   duplicate.pressed = false
   hud.rod_joystick._input(duplicate)
   expect(fishing.state == FishingController.State.READY, "Synthetic mouse after touch cannot recast")
   var fresh := InputEventScreenTouch.new()
   fresh.index = 8
   fresh.position = point
   fresh.pressed = true
   hud.rod_joystick._input(fresh)
   fresh.pressed = false
   hud.rod_joystick._input(fresh)
   expect(fishing.state == FishingController.State.CASTING, "Lifting and touching again allows intentional cast")
   fishing.reset_cast()
 var profile := AnglerProfile.new()
 profile.data = profile.defaults()
 fishing.profile = profile
 for remaining in [65.0, 8.0, 3.0, 1.0, 0.5, 0.0]:
  profile.data.line_remaining = remaining
  for depth in [0.5, 1.5, 5.0, 12.0]:
   fishing.selected_depth = depth
   var target := fishing.get_aim_position()
   var planar := Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length()
   expect(planar > 0.5 and target.is_finite(), "Aim stays away from angler: line %.1f depth %.1f" % [remaining, depth])
   if remaining >= 1.0:
    expect(Vector2(planar, target.y).length() <= remaining, "Aim fits available line")
   else:
    expect(not fishing.cast() and "สาย" in fishing.feedback, "Insufficient line explains equipment repair")
 profile.data.line_remaining = 65.0
 expect(fishing.get_aim_position().distance_to(player.global_position) > 5.0, "Replacing line restores full aiming range")
 fishing.profile = null
 profile.free()
 fishing.selected_depth = 1.5
 fishing.reset_cast()
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 if DisplayServer.get_name() != "headless":
  for resolution in [Vector2i(1280, 720), Vector2i(1600, 720)]:
   root.size = resolution
   for frame in 5:
    await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../exports/tutorial-qa/feedback-%d.png" % resolution.x)
  root.size = Vector2i(1280, 720)
  camera.set_process(false)
  camera.set_orbiting(true)
  camera.drag_orbit(-PI / camera.look_sensitivity)
  camera._process(1.0)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../exports/tutorial-qa/feedback-face.png")
  camera.set_orbiting(false)
 scene.queue_free()
 await process_frame
 quit(1 if failures else 0)
