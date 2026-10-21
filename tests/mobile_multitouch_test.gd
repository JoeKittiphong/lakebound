extends SceneTree

var errors := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  errors += 1
  push_error("FAIL: " + message)

func touch(id: int, down: bool, point: Vector2, canceled: bool = false) -> void:
 var event := InputEventScreenTouch.new()
 event.index = id
 event.pressed = down
 event.canceled = canceled
 event.position = point
 root.push_input(event, true)

func mouse(down: bool, point: Vector2) -> void:
 var event := InputEventMouseButton.new()
 event.device = InputEvent.DEVICE_ID_EMULATION
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = down
 event.position = point
 root.push_input(event, true)

func drag(id: int, point: Vector2, relative: Vector2) -> void:
 var event := InputEventScreenDrag.new()
 event.index = id
 event.position = point
 event.relative = relative
 root.push_input(event, true)

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingController").set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 var camera: AnglerCameraRig = scene.get_node("CameraRig")
 var move: TouchJoystick = scene.get_node("HUD/FishingHUD").move_joystick
 var rod: TouchJoystick = scene.get_node("HUD/FishingHUD").rod_joystick
 await process_frame
 await process_frame
 for resolution in [Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(2340, 1080)]:
  root.size = resolution
  for frame in 5:
   await process_frame
  for camera_first in [false, true]:
   for mouse_first in [false, true]:
    for repeat in 4:
     scene.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
     var move_point := move.get_global_rect().get_center() + Vector2(0, -45)
     var camera_point := Vector2(root.get_visible_rect().size.x * 0.70, 160)
     var move_id := repeat % 2
     var camera_id := 1 - move_id
     for which in (["camera", "move"] if camera_first else ["move", "camera"]):
      var point := camera_point if which == "camera" else move_point
      var id := camera_id if which == "camera" else move_id
      if mouse_first:
       mouse(true, point)
      touch(id, true, point)
      if not mouse_first:
       mouse(true, point)
     expect(move.touch_index == move_id and camera.look_finger == camera_id, "both fingers acquired regardless of press order and mouse emulation")
     var yaw := camera.rotation.y
     drag(move_id, move_point + Vector2(4, -5), Vector2(4, -5))
     drag(camera_id, camera_point + Vector2(40, 10), Vector2(40, 10))
     expect(move.direction.length() > 0.2 and not is_equal_approx(yaw, camera.rotation.y), "walking and camera drag update together")
     if repeat % 2 == 0:
      touch(camera_id, false, camera_point)
      mouse(false, camera_point)
      expect(move.touch_index == move_id and move.direction.length() > 0.2, "releasing camera preserves walking")
      touch(camera_id, true, camera_point)
      expect(camera.look_finger == camera_id, "camera finger can be reused while walking continues")
     else:
      touch(move_id, false, move_point)
      mouse(false, move_point)
      expect(camera.look_finger == camera_id, "releasing walking preserves camera")
      touch(move_id, true, move_point)
      expect(move.touch_index == move_id, "walking finger can be reused while camera continues")
     touch(move_id, false, move_point)
     touch(camera_id, false, camera_point)
     mouse(false, camera_point)
     expect(move.touch_index == -1 and camera.look_finger == -1 and not move.mouse_active and not camera.look_mouse, "release clears both owners without stuck input")
 var releases := [0]
 rod.drag_released.connect(func(): releases[0] += 1)
 var rod_point := rod.get_global_rect().get_center() + Vector2(0, -40)
 touch(0, true, rod_point)
 touch(0, false, rod_point, true)
 expect(rod.touch_index == -1 and releases[0] == 0, "canceled mobile touch resets aim without casting")
 var move_point := move.get_global_rect().get_center() + Vector2(0, -45)
 var camera_point := Vector2(root.get_visible_rect().size.x * 0.70, 160)
 for notification in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
  touch(0, true, move_point)
  touch(1, true, camera_point)
  touch(2, true, move_point)
  expect(move.touch_index == 0 and camera.look_finger == 1, "third finger cannot steal either control")
  scene.propagate_notification(notification)
  expect(move.touch_index == -1 and move.direction == Vector2.ZERO and camera.look_finger == -1, "app interruption clears both controls")
  touch(0, true, move_point)
  touch(1, true, camera_point)
  expect(move.touch_index == 0 and camera.look_finger == 1, "controls recover together after an interruption")
  touch(1, false, camera_point, true)
  expect(move.touch_index == 0 and camera.look_finger == -1, "canceling camera preserves walking")
  touch(1, true, camera_point)
  touch(0, false, move_point, true)
  expect(move.touch_index == -1 and camera.look_finger == 1, "canceling walking preserves camera")
  touch(1, false, camera_point)
 scene.queue_free()
 await process_frame
 print("MOBILE MULTITOUCH RESULT: ", checks, " checks, ", errors, " failures")
 quit(0 if errors == 0 else 1)
