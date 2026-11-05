extends SceneTree

var failures := 0
var checks := 0
var game: Node3D
var player: AnglerPlayer
var stick: TouchJoystick
var button: Button
var hud: FishingHUD

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1

func frames(count: int = 4) -> void:
 for i in count: await physics_frame

func touch(id: int, down: bool, point: Vector2) -> void:
 var event := InputEventScreenTouch.new()
 event.index = id; event.pressed = down; event.position = point
 root.push_input(event, true)

func drag(id: int, point: Vector2, relative := Vector2.ZERO) -> void:
 var event := InputEventScreenDrag.new()
 event.index = id; event.position = point; event.relative = relative
 root.push_input(event, true)

func toggle_run() -> void:
 var point := button.get_global_rect().get_center()
 touch(4, true, point); touch(4, false, point)

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join(label + ".png"))

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 game = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled = false
 root.add_child(game); current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 game.get_node("PondEcosystem").set_physics_process(false)
 game.get_node("FishingController").set_physics_process(false)
 player = game.get_node("Player")
 hud = game.get_node("HUD/FishingHUD")
 stick = hud.move_joystick
 button = hud.get_node("SafeArea/MovementActions/LeftActions/Run")
 await frames(25)
 hud.get_node("SafeArea/FirstCatch")._skip()
 # Keep physical motion deterministic and away from water/bank constraints.
 player.pond = null
 player.gravity = 0
 player.velocity = Vector3.ZERO
 player.position = Vector3(0, 8, 0)
 var camera: AnglerCameraRig = game.get_node("CameraRig")
 expect(stick.run_outside_base and not hud.rod_joystick.run_outside_base, "only movement stick enables outer-circle running")
 for resolution in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(2400, 1080)]:
  root.size = resolution
  await frames()
  var center := stick.get_global_transform_with_canvas() * (stick.size * 0.5)
  var edge := minf(stick.size.x, stick.size.y) * 0.5
  touch(0, true, center)
  for direction in [Vector2.UP, Vector2.RIGHT, Vector2(1, -1).normalized()]:
   for distance in [edge - 1, edge, edge + 1, edge + 60, edge - 1]:
    var point: Vector2 = stick.get_global_transform_with_canvas() * (stick.size * 0.5 + direction * distance)
    drag(0, point)
    await frames()
    expect(player.running == (distance > edge), "circle boundary %s distance %.1f" % [resolution, distance])
    var speed := Vector2(player.velocity.x, player.velocity.z).length()
    expect(is_equal_approx(speed, player.run_speed if distance > edge else player.move_speed), "walk/run uses expected physical speed")
  touch(0, false, center)
  await frames()
  expect(not player.running and stick.direction == Vector2.ZERO and not stick.run_requested, "release clears outer sprint")
  toggle_run()
  await frames()
  expect(player.run_requested and player.running and button.button_pressed and button.text == "หยุดวิ่ง", "touch toggles auto-run with no joystick")
  for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
   camera.rotation = Vector3(0.15, yaw, 0)
   await frames()
   var velocity := Vector3(player.velocity.x, 0, player.velocity.z)
   expect(velocity.normalized().dot(Vector3.FORWARD.rotated(Vector3.UP, yaw)) > 0.999 and is_equal_approx(velocity.length(), player.run_speed), "auto-run follows camera yaw at full speed")
  var look_point := Vector2(root.get_visible_rect().size.x * 0.7, 160)
  var old_yaw := camera.rotation.y
  touch(2, true, look_point)
  drag(2, look_point + Vector2(80, 0), Vector2(80, 0))
  await frames()
  expect(camera.look_finger == 2 and not is_equal_approx(camera.rotation.y, old_yaw) and player.running, "real camera touch pans while auto-running")
  touch(2, false, look_point)
  touch(0, true, center)
  drag(0, center + Vector2(62, 0))
  await frames()
  expect(player.run_requested and player.running and stick.direction.x > 0.9, "manual joystick steers while auto-run remains active")
  touch(0, false, center)
  await frames()
  expect(player.running, "releasing manual steering resumes auto-run")
  expect(root.get_visible_rect().encloses(button.get_global_rect()) and not button.get_global_rect().intersects(stick.get_global_rect()), "active run button fits and clears stick")
  await capture("auto_run_%dx%d" % [resolution.x, resolution.y])
  toggle_run()
  await frames()
  expect(not player.run_requested and not player.running and Vector2(player.velocity.x, player.velocity.z).is_zero_approx() and not button.button_pressed, "second touch cancels and stops motion")
 toggle_run(); await frames()
 game.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 await frames()
 expect(not player.run_requested and not button.button_pressed and not player.running, "focus loss cancels auto-run and synchronizes button")
 toggle_run(); await frames()
 game._on_collection_visibility_changed(true)
 expect(not player.run_requested and not button.button_pressed, "modal cancels synchronously before tree pauses")
 game._on_collection_visibility_changed(false)
 await frames()
 expect(not player.running, "closing modal never resumes auto-run")
 toggle_run(); await frames()
 player.fishing_active = true
 await frames()
 expect(not player.run_requested and not player.running and not button.button_pressed, "fishing cancels auto-run")
 player.fishing_active = false
 toggle_run(); await frames()
 player.input_enabled = false
 await frames()
 expect(not player.run_requested and not player.running, "disabled controls cancel auto-run")
 player.input_enabled = true
 # Verify actual grounded Sprint animation, water entry, and boarding as well.
 player.pond = game.get_node("World")
 var definition := player.pond.definition as RiverDefinition
 var dry := Vector2(definition.center_at(42) - definition.half_width_at(42) - 12, 42)
 player.position = Vector3(dry.x, definition.ground_height(dry) + 0.1, dry.y)
 player.gravity = 20
 player.velocity = Vector3.ZERO
 camera.rotation = Vector3.ZERO
 await frames(20)
 toggle_run(); await frames(10)
 expect(player.is_on_floor() and player.running and player.character_model.current_action == &"Sprint", "grounded auto-run uses Sprint animation")
 await capture("auto_run_grounded")
 toggle_run(); await frames(6)
 expect(player.character_model.current_action == &"Idle_A", "cancel restores grounded idle animation")
 toggle_run(); await frames()
 player.position = Vector3(definition.center_at(0), definition.surface_height() - 1.0, 0)
 player.velocity = Vector3.ZERO
 await frames()
 expect(player.swimming and not player.run_requested and not player.running and not button.button_pressed, "entering actual river cancels auto-run")
 player.position = Vector3(dry.x, definition.ground_height(dry) + 0.1, dry.y)
 await frames(20)
 toggle_run(); await frames()
 player.embark(game.get_node("FishingBoat"))
 await frames()
 expect(not player.run_requested and not player.running and not button.button_pressed, "boarding cancels auto-run")
 player.disembark(Vector3(dry.x, definition.ground_height(dry) + 0.1, dry.y))
 # Shared rod stick still clamps normally outside its base.
 var rod: TouchJoystick = hud.rod_joystick
 rod._update_direction(rod.get_global_transform_with_canvas() * (rod.size * 0.5 + Vector2(200, 0)))
 expect(not rod.run_requested and is_equal_approx(rod.direction.length(), 1), "rod control retains original clamped direction")
 rod.reset()
 game.queue_free(); await frames(2)
 print("joystick_run: ", checks, " checks, ", failures, " failures")
 quit(1 if failures else 0)
