extends SceneTree

var failures := 0

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for index in count:
  await physics_frame

func expect(value: bool, message: String) -> void:
 print("PASS: " if value else "FAIL: ", message)
 if not value:
  failures += 1

func touch(index: int, pressed: bool, point: Vector2) -> void:
 var event := InputEventScreenTouch.new()
 event.index = index
 event.pressed = pressed
 event.position = point
 root.push_input(event, true)

func run() -> void:
 root.size = Vector2i(1280, 720)
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var player: AnglerPlayer = scene.get_node("Player")
 var camera: AnglerCameraRig = scene.get_node("CameraRig")
 var joystick: TouchJoystick = scene.get_node("HUD/FishingHUD/SafeArea/MoveJoystick")
 scene.get_node("FishingEffects").audio_enabled = false
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingController").set_physics_process(false)
 await frames(30)
 var spawn := player.global_position
 print("SPAWN ", spawn, " floor=", player.is_on_floor(), " enabled=", player.input_enabled, " ref=", player.movement_reference)
 for yaw in [-PI * 0.5, 0.0, PI, PI * 0.5]:
  for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
   player.global_position = spawn
   player.velocity = Vector3.ZERO
   camera.rotation.y = yaw
   await frames(3)
   var start := player.global_position
   var point: Vector2 = joystick.get_global_rect().get_center() + direction * 52
   touch(8, true, point)
   await frames(30)
   var displacement := player.global_position - start
   displacement.y = 0
   print("MOVE yaw=", rad_to_deg(yaw), " input=", joystick.direction, " delta=", displacement, " velocity=", player.velocity, " floor=", player.is_on_floor(), " collisions=", player.get_slide_collision_count())
   expect(joystick.touch_index == 8 and joystick.direction.length() > 0.1, "actual HUD touch reaches movement joystick")
   expect(displacement.length() > 0.5, "actual character moves with touch input on authored terrain")
   # Spawn is on a bank: movement into deep water may stop at the edge,
   # but walking along or away from the bank must remain possible.
   if absf(displacement.x) + absf(displacement.z) < 0.02:
    for index in player.get_slide_collision_count():
     var hit := player.get_slide_collision(index)
     print("BLOCK ", hit.get_collider(), " normal=", hit.get_normal(), " depth=", hit.get_depth())
   touch(8, false, point)
   await frames(2)
 camera.rotation.y = -PI * 0.5
 for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
  player.global_position = spawn
  player.velocity = Vector3.ZERO
  await frames(3)
  var start := player.global_position
  var center := joystick.get_global_rect().get_center()
  var button := InputEventMouseButton.new()
  button.device = InputEvent.DEVICE_ID_EMULATION
  button.button_index = MOUSE_BUTTON_LEFT
  button.pressed = true
  button.position = center
  root.push_input(button, true)
  await frames(2)
  var motion := InputEventMouseMotion.new()
  motion.device = InputEvent.DEVICE_ID_EMULATION
  motion.button_mask = MOUSE_BUTTON_MASK_LEFT
  motion.position = center + direction * 52
  motion.relative = direction * 52
  root.push_input(motion, true)
  await frames(30)
  var displacement := player.global_position - start
  displacement.y = 0
  print("MOUSE input=", joystick.direction, " active=", joystick.mouse_active, " displacement=", displacement, " device=", motion.device, " camera_mouse=", camera.look_mouse)
  expect(joystick.mouse_active and displacement.length() > 0.5, "mouse center press then drag moves character on actual terrain")
  button.pressed = false
  button.position = motion.position
  root.push_input(button, true)
  await frames(2)
  expect(not joystick.mouse_active and joystick.direction == Vector2.ZERO, "mouse release stops the joystick")
 # A touch produces mouse duplicates on some platforms; those duplicates
 # must not move or release the joystick owned by that finger.
 var release_count := [0]
 joystick.drag_released.connect(func(): release_count[0] += 1)
 var touch_point := joystick.get_global_rect().get_center() + Vector2(0, -52)
 touch(18, true, touch_point)
 var touch_direction := joystick.direction
 var duplicate := InputEventMouseButton.new()
 duplicate.device = InputEvent.DEVICE_ID_EMULATION
 duplicate.button_index = MOUSE_BUTTON_LEFT
 duplicate.pressed = true
 duplicate.position = touch_point
 root.push_input(duplicate, true)
 var duplicate_motion := InputEventMouseMotion.new()
 duplicate_motion.device = InputEvent.DEVICE_ID_EMULATION
 duplicate_motion.position = touch_point + Vector2(50, 50)
 duplicate_motion.relative = Vector2(50, 50)
 root.push_input(duplicate_motion, true)
 duplicate.pressed = false
 root.push_input(duplicate, true)
 expect(joystick.touch_index == 18 and not joystick.mouse_active and joystick.direction == touch_direction, "synthetic mouse events cannot steal or alter an active touch joystick")
 touch(18, false, touch_point)
 root.push_input(duplicate, true)
 expect(release_count[0] == 1 and joystick.direction == Vector2.ZERO, "touch plus synthetic mouse release emits exactly one joystick release")
 # The camera must also accept the same forwarded desktop mouse source.
 var camera_press := InputEventMouseButton.new()
 camera_press.device = InputEvent.DEVICE_ID_EMULATION
 camera_press.button_index = MOUSE_BUTTON_LEFT
 camera_press.pressed = true
 camera_press.position = Vector2(900, 200)
 var yaw_before := camera.rotation.y
 root.push_input(camera_press, true)
 var camera_motion := InputEventMouseMotion.new()
 camera_motion.device = InputEvent.DEVICE_ID_EMULATION
 camera_motion.position = Vector2(960, 200)
 camera_motion.relative = Vector2(60, 0)
 camera_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
 root.push_input(camera_motion, true)
 expect(camera.look_mouse and not is_equal_approx(camera.rotation.y, yaw_before), "forwarded desktop mouse pans the camera")
 camera_press.pressed = false
 root.push_input(camera_press, true)
 expect(not camera.look_mouse, "forwarded mouse release clears camera ownership")
 var rod: TouchJoystick = scene.get_node("HUD/FishingHUD/SafeArea/RodJoystick")
 var rod_point := rod.get_global_rect().get_center() + Vector2(0, -40)
 touch(19, true, rod_point)
 duplicate.position = rod_point
 duplicate.pressed = true
 root.push_input(duplicate, true)
 expect(not camera.look_mouse and rod.touch_index == 19, "mouse duplicate from rod touch cannot claim the camera")
 touch(20, true, Vector2(900, 200))
 expect(camera.look_finger == 20 and rod.touch_index == 19, "camera and rod keep separate real fingers after synthetic mouse input")
 touch(20, false, Vector2(900, 200))
 touch(19, false, rod_point)
 duplicate.pressed = false
 root.push_input(duplicate, true)
 scene.queue_free()
 await process_frame
 print("ACTIVE MOVEMENT RESULT: ", failures, " failures")
 quit(failures)
