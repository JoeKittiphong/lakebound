extends SceneTree

var Gameplay: PackedScene
var output := OS.get_environment("LAKEBOUND_QA_DIR") if not OS.get_environment("LAKEBOUND_QA_DIR").is_empty() else "res://exports/qa/screenshots"
var errors := 0

func _initialize() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 call_deferred("run_checks")

func expect(condition: bool, message: String) -> void:
 if not condition:
  errors += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func frames(count: int = 5) -> void:
 for index in count:
  await process_frame

func capture(name: String) -> void:
 await frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/" + name + ".png")

func touch(index: int, pressed: bool, position: Vector2) -> void:
 var event := InputEventScreenTouch.new()
 event.index = index
 event.pressed = pressed
 event.position = position
 Input.parse_input_event(event)

func center(control: Control) -> Vector2:
 return control.get_global_transform_with_canvas() * (control.size * 0.5)

func drag(index: int, position: Vector2, motion: Vector2) -> void:
 var event := InputEventScreenDrag.new()
 event.index = index
 event.position = position
 event.relative = motion
 Input.parse_input_event(event)

func inside(control: Control) -> void:
 expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(control.get_global_rect()), "responsive bounds: " + String(control.name))

func run_checks() -> void:
 root.get_node("FishCollection").recording_enabled = false
 Gameplay = load("res://features/gameplay/gameplay.tscn")
 root.size = Vector2i(1280, 720)
 var scene := Gameplay.instantiate()
 root.add_child(scene)
 current_scene = scene
 await frames(12)
 var hud := scene.get_node("HUD/FishingHUD")
 var controller := scene.get_node("FishingController")
 var pond := scene.get_node("PondEcosystem")
 var player := scene.get_node("Player")
 expect(hud.get_node("SafeArea/BaitPanel/Content/BaitRow/BaitSelect").item_count == 3, "three editor-authored bait options")
 expect(hud.get_node("SafeArea/CollectionButton").icon != null and hud.get_node("SafeArea/CollectionButton").text.is_empty(), "collection opens with a book icon instead of a text button")
 expect(not hud.get_node("SafeArea/BaitPanel").visible and not hud.get_node("SafeArea/Status").visible and not hud.get_node("SafeArea/MoveLabel").visible and not hud.get_node("SafeArea/RodInstructions").visible, "ready HUD keeps instructions and configuration off the playfield")
 var bait_button: Button = hud.get_node("SafeArea/BaitDock/BaitButton")
 touch(31, true, center(bait_button))
 touch(31, false, center(bait_button))
 await frames()
 expect(controller.selected_bait == &"dough", "touching the bait icon changes the actual fishing bait")
 var depth_button: Button = hud.get_node("SafeArea/BaitDock/DepthButton")
 touch(32, true, center(depth_button))
 touch(32, false, center(depth_button))
 await frames()
 expect(hud.get_node("SafeArea/BaitPanel").visible, "depth icon opens the optional settings panel")
 hud.get_node("SafeArea/BaitPanel/Content/DepthRow/Depth").value = 2.5
 await frames()
 expect(is_equal_approx(controller.selected_depth, 2.5) and depth_button.text == "2.5", "depth slider updates the compact dock and fishing depth")
 touch(32, true, center(depth_button))
 touch(32, false, center(depth_button))
 await frames()
 expect(not hud.get_node("SafeArea/BaitPanel").visible, "depth icon closes settings to restore the clear playfield")
 hud.get_node("SafeArea/BaitPanel/Content/BaitRow/BaitSelect").select(0)
 hud.get_node("SafeArea/BaitPanel/Content/DepthRow/Depth").value = 1.5
 hud._on_config_changed()
 await create_timer(2.0).timeout
 expect(not hud.get_node("SafeArea/Toast").visible, "bait feedback disappears instead of adding permanent HUD text")
 for size in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1024, 768)]:
  root.size = size
  await frames()
  for path in ["SafeArea/Status", "SafeArea/MoveJoystick", "SafeArea/RodJoystick", "SafeArea/BaitPanel", "SafeArea/ActionButton", "SafeArea/CollectionButton", "SafeArea/EcologyButton", "SafeArea/BackButton", "SafeArea/BaitDock"]:
   inside(hud.get_node(path))
  expect(not hud.get_node("SafeArea/BaitDock").get_global_rect().intersects(hud.get_node("SafeArea/MoveJoystick").get_global_rect()) and not hud.get_node("SafeArea/BaitDock").get_global_rect().intersects(hud.get_node("SafeArea/RodJoystick").get_global_rect()), "bait dock does not overlap either touch joystick")
  await capture("fishing-ready-%dx%d" % [size.x, size.y])
 root.size = Vector2i(1280, 720)
 await frames()
 var rig := scene.get_node("CameraRig")
 touch(20, true, Vector2(900, 200))
 drag(20, Vector2(960, 210), Vector2(60, 10))
 await frames()
 expect(rig.rotation.y < -0.1 and rig.rotation.x < 0, "empty right area rotates camera yaw and pitch")
 expect(is_equal_approx(player.visual.rotation.y, rig.rotation.y) and is_zero_approx(player.visual.rotation.x), "character follows yaw only")
 var aimed: Vector3 = controller.get_aim_position() - player.global_position
 expect(aimed.x > 1.0, "casting target rotates with character facing")
 touch(20, false, Vector2(960, 210))
 controller.aim_yaw = PI
 expect(not controller.cast() and controller.state == controller.State.READY, "casting onto land is rejected without moving bait into pond")
 touch(23, true, Vector2(900, 200))
 scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 touch(23, false, Vector2(900, 200))
 expect(rig.look_finger == -1, "focus loss clears camera finger")
 rig.rotation = Vector3.ZERO
 await frames()
 var left := hud.move_joystick as Control
 var right := hud.rod_joystick as Control
 touch(7, true, center(right) + Vector2(0, -45))
 await frames()
 right.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 await frames()
 expect(controller.state == controller.State.READY, "focus loss resets aim without accidentally casting")
 var start: Vector3 = player.position
 touch(8, true, center(left) + Vector2(0, -46))
 touch(9, true, center(right) + Vector2(25, -47))
 await create_timer(0.3).timeout
 expect(left.touch_index == 8 and right.touch_index == 9, "walking and aiming retain independent fingers")
 expect(player.position.z < start.z - 0.3, "left joystick moves angler while aiming")
 expect(controller.aim_offset.x > 0.3, "right joystick aims across actual pond positions")
 touch(9, false, center(right))
 await frames()
 expect(controller.state == controller.State.CASTING, "releasing the aiming joystick starts the cast animation")
 await create_timer(0.65).timeout
 expect(controller.state == controller.State.WAITING, "bait enters the pond after the cast arc finishes")
 var cast_anchor: Vector3 = controller.cast_position
 touch(21, true, Vector2(900, 200))
 drag(21, Vector2(970, 200), Vector2(70, 0))
 await frames()
 expect(controller.cast_position == cast_anchor, "camera rotation leaves waiting bait fixed in world space")
 touch(21, false, Vector2(970, 200))
 rig.rotation = Vector3.ZERO
 await frames()
 expect(left.touch_index == 8, "casting and camera input preserve walking finger")
 touch(8, false, Vector2(500, 200))
 await frames()
 controller.cancel()
 await frames()
 controller.selected_bait = &"lure"
 controller.aim_offset = Vector3(0, 0, -14)
 hud.get_node("SafeArea/ActionButton").pressed.emit()
 await frames()
 expect(controller.state == controller.State.CASTING, "cast button works")
 await create_timer(0.65).timeout
 controller.set_physics_process(false)
 pond.set_physics_process(false)
 for tick in 600:
  pond.step(0.15)
  if controller.state == controller.State.BITE:
   break
 expect(controller.state == controller.State.BITE, "real ecosystem reaches bite state")
 await frames()
 expect(hud.get_node("SafeArea/ActionButton").icon == hud.HOOK_ICON and hud.get_node("SafeArea/ActionButton").text.is_empty(), "bite state switches the action icon to a hook")
 await capture("fishing-bite")
 hud.get_node("SafeArea/ActionButton").pressed.emit()
 await frames()
 expect(controller.state == controller.State.FIGHT, "strike button enters fight")
 touch(10, true, center(right) + Vector2(-28, 48))
 await frames()
 expect(controller.rod_input.y > 0.1, "battle joystick sends reel-in command")
 var reel := right.get_node("Reel")
 expect(reel.visible and not right.get_node("Knob").visible and left.get_node("Base").visible, "battle shows reel only; walking joystick remains unchanged")
 reel.set_process(false)
 reel.command = Vector2(0.5, 1)
 reel.slipping = false
 var before_spin: float = reel.spin
 var before_crank: float = reel.crank
 reel._process(0.2)
 expect(reel.spin > before_spin and reel.crank > before_crank and reel.tilt > 0, "pulling turns spool and crank inward and lateral input tilts reel")
 expect(is_equal_approx(reel.model.get_node("Spool").rotation.x, reel.spin) and is_equal_approx(reel.model.get_node("Crank").rotation.x, reel.crank), "actual 3D spool and crank pivots receive the animation")
 expect(reel.get_node("Viewport").own_world_3d and reel.get_node("Viewport/Camera").projection == Camera3D.PROJECTION_ORTHOGONAL, "reel uses isolated 3D viewport and overhead orthographic camera")
 expect(reel.equip(load("res://features/equipment/reels/baitcaster.tscn")), "reel model can be replaced without changing input control")
 expect(not reel.equip(load("res://world/pond/fish_visual.tscn")), "incompatible equipment scene is rejected safely")
 reel.command = Vector2(0, -1)
 before_spin = reel.spin
 reel._process(0.2)
 expect(reel.spin < before_spin, "pushing reverses reel rotation")
 reel.command = Vector2.ZERO
 before_spin = reel.spin
 before_crank = reel.crank
 reel._process(0.2)
 expect(reel.spin == before_spin and reel.crank == before_crank, "neutral stops reel without drag slip")
 reel.slipping = true
 reel._process(0.2)
 expect(reel.spin < before_spin and reel.crank == before_crank, "drag pays out spool without rotating idle crank")
 reel.set_process(true)
 var fish_anchor: Vector3 = controller.active_fish.position
 touch(22, true, Vector2(900, 200))
 drag(22, Vector2(950, 200), Vector2(50, 0))
 await frames()
 expect(rig.look_finger == 22 and right.touch_index == 10, "camera and fighting joystick track separate fingers")
 expect(controller.active_fish.position == fish_anchor, "rotating view does not teleport hooked fish")
 touch(22, false, Vector2(950, 200))
 var yaw_after_release: float = rig.rotation.y
 drag(22, Vector2(1000, 200), Vector2(50, 0))
 await frames()
 expect(is_equal_approx(rig.rotation.y, yaw_after_release), "released camera finger cannot keep rotating")
 var meter := hud.meter as Control
 expect(meter.get_global_rect().end.x < right.get_global_rect().position.x, "straight tension meter sits left of joystick")
 var battle_position: Vector3 = player.position
 touch(11, true, center(left) + Vector2(0, 46))
 await create_timer(0.3).timeout
 expect(player.position.z > battle_position.z + 0.2 and right.touch_index == 10, "walking during battle preserves rod control")
 touch(11, false, Vector2(450, 300))
 await frames()
 controller.advance(0.15, player.position)
 await capture("fishing-fight-16x9")
 root.size = Vector2i(1600, 720)
 await frames()
 for path in ["SafeArea/TensionMeter", "SafeArea/LineInfo", "SafeArea/CancelButton"]:
  inside(hud.get_node(path))
 await capture("fishing-fight-20x9")
 touch(10, false, Vector2.ZERO)
 await frames()
 scene.set_process(false)
 for tick in 7200:
  var vertical: float = 1.0 if controller.tension < 0.72 else -0.72
  controller.rod_input = Vector2(-controller.lateral_direction, vertical).limit_length(1.0)
  controller.advance(1.0 / 60.0, player.position)
  if controller.state != controller.State.FIGHT:
   break
 scene.set_process(true)
 await frames()
 expect(controller.state == controller.State.RESULT, "full battle reaches catch result")
 expect(not left.enabled and not right.enabled, "result modal disables both gameplay joysticks")
 var result_position: Vector3 = player.position
 Input.action_press("move_forward")
 await create_timer(0.15).timeout
 Input.action_release("move_forward")
 expect(Vector2(player.position.x, player.position.z).distance_to(Vector2(result_position.x, result_position.z)) < 0.02, "result modal also blocks keyboard movement")
 await capture("fishing-catch-result")
 var count: int = pond.fish.size()
 var id: int = controller.active_fish.id if controller.active_fish != null else -1
 hud.get_node("ResultLayer/Card/Content/ReleaseButton").pressed.emit()
 await frames()
 expect(controller.state == controller.State.READY and pond.fish.size() == count, "release result button returns to ready without removing fish")
 var same_fish := false
 for record in pond.fish:
  if record.id == id and record.caution > 0.9:
   same_fish = true
 expect(same_fish, "released visible fish is the original simulated individual")
 hud.get_node("SafeArea/EcologyButton").pressed.emit()
 await capture("fishing-ecosystem")
 print("VISUAL/INPUT RESULT: ", errors, " failures")
 quit(0 if errors == 0 else 1)

