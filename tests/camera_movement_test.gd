extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if value:
  print("PASS: ", message)
 else:
  failures += 1
  push_error("FAIL: " + message)

func frames(count: int = 4) -> void:
 for index in count:
  await physics_frame

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var player: AnglerPlayer = load("res://actors/player/player.tscn").instantiate()
 var camera: AnglerCameraRig = load("res://features/gameplay/camera_rig.tscn").instantiate()
 var joystick: TouchJoystick = load("res://shared/ui/virtual_joystick.tscn").instantiate()
 root.add_child(camera)
 root.add_child(joystick)
 root.add_child(player)
 player.movement_reference = camera
 player.joystick = joystick
 player.facing_follows_camera = true
 # Deliberately disagree with the camera: animation/model facing must not
 # determine where screen up/right walks.
 player.visual.rotation.y = 0.37
 var directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
 var actions := ["move_forward", "move_back", "move_left", "move_right"]
 for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
  camera.rotation = Vector3(0, yaw, 0)
  for index in directions.size():
   var expected := Vector3(directions[index].x, 0, directions[index].y).rotated(Vector3.UP, yaw)
   for keyboard in [false, true]:
    player.global_position = Vector3(0, 3, 0)
    player.velocity = Vector3.ZERO
    var start := player.global_position
    if keyboard:
     Input.action_press(actions[index])
    else:
     joystick.direction = directions[index]
    await frames()
    var movement := player.global_position - start
    movement.y = 0
    expect(movement.length() > 0.01 and movement.normalized().dot(expected) > 0.995, "%s direction %d follows camera at yaw %.0f" % ["keyboard" if keyboard else "joystick", index, rad_to_deg(yaw)])
    Input.action_release(actions[index])
    joystick.direction = Vector2.ZERO
    await frames(2)
 # Holding forward while panning through the back view must immediately
 # change travel direction without releasing and grabbing the joystick.
 joystick.direction = Vector2.UP
 for yaw in [0.0, PI * 0.5, PI, -PI * 0.5, 0.0]:
  camera.rotation = Vector3(deg_to_rad(40), yaw, 0)
  player.global_position = Vector3(0, 3, 0)
  await frames()
  var flat_velocity := Vector3(player.velocity.x, 0, player.velocity.z)
  var expected := Vector3.FORWARD.rotated(Vector3.UP, yaw)
  expect(flat_velocity.normalized().dot(expected) > 0.995 and is_equal_approx(flat_velocity.length(), player.move_speed), "held joystick follows pan at yaw %.0f without pitch reducing speed" % rad_to_deg(yaw))
 joystick.direction = Vector2.ZERO
 player.input_enabled = false
 Input.action_press("move_forward")
 await frames()
 expect(is_zero_approx(player.velocity.x) and is_zero_approx(player.velocity.z), "disabled movement still blocks keyboard input")
 Input.action_release("move_forward")
 player.queue_free()
 camera.queue_free()
 joystick.queue_free()
 await process_frame
 print("CAMERA MOVEMENT RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
