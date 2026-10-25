extends SceneTree

var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")
var scene: Node3D
var player: AnglerPlayer
var model: AnglerModel
var fishing: FishingController
var definition: RiverDefinition

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func ticks(count: int) -> void:
 for i in count:
  await physics_frame

func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless" or output.is_empty():
  return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("traversal_" + name + ".png"))

func teleport(point: Vector3) -> void:
 player.global_position = point
 player.velocity = Vector3.ZERO
 player._swim_exit_cooldown = 0.0

func touch(index: int, down: bool, point: Vector2) -> void:
 var event := InputEventScreenTouch.new()
 event.index = index
 event.pressed = down
 event.position = point
 root.push_input(event, true)

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.size = Vector2i(1280, 720)
 scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 scene.get_node("PondEcosystem").set_physics_process(false)
 fishing = scene.get_node("FishingController")
 fishing.set_physics_process(false)
 player = scene.get_node("Player")
 model = player.character_model
 definition = scene.get_node("World").definition
 await ticks(25)
 scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip()
 expect(model.skeleton.get_bone_count() >= 22, "new Mesh2Motion skeleton imports")
 var required := ["Fishing_Cast", "Fishing_Catch", "Fishing_Reel", "Swim_Fwd", "Swim_Idle", "Walk", "Jump_2", "Sprint", "Idle_A", "Greeting"]
 for clip in required:
  expect(model.animation_player.has_animation(clip), "game has clip " + clip)
 var body := model.skeleton.get_child(0) as MeshInstance3D
 expect(body != null and body.skin != null, "textured body is skinned")
 var material := body.get_active_material(0) as StandardMaterial3D
 expect(material != null and material.albedo_texture != null and material.albedo_texture.get_width() > 0, "Mesh2Motion color atlas is bound")
 expect(is_equal_approx(player.visual.scale.x, 1.4868) and is_equal_approx(player.get_node("CollisionShape3D").shape.height, 2.142), "character and collision reduced by ten percent")
 expect(player.is_on_floor() and model.current_action == &"Idle_A", "spawn settles into grounded idle")
 expect(InputMap.has_action("sprint") and InputMap.has_action("jump") and InputMap.has_action("greet"), "traversal input map exists")
 await capture("idle")
 for size in [Vector2i(1024, 768), Vector2i(1600, 720)]:
  root.size = size
  for frame in 4:
   await process_frame
  var buttons: Control = scene.get_node("HUD/FishingHUD/SafeArea/MovementActions/Jump")
  var stick_rect: Rect2 = scene.get_node("HUD/FishingHUD").move_joystick.get_global_rect()
  expect(root.get_visible_rect().encloses(buttons.get_global_rect()) and not buttons.get_global_rect().intersects(stick_rect), "movement buttons remain visible above joystick at " + str(size))
  expect(buttons.get_global_rect().position.x > root.get_visible_rect().size.x * 0.5, "movement buttons occupy right thumb area at " + str(size))
  var left_buttons: Control = scene.get_node("HUD/FishingHUD/SafeArea/MovementActions/LeftActions")
  expect(left_buttons.get_global_rect().end.x < root.get_visible_rect().size.x * 0.5 and not left_buttons.get_global_rect().intersects(stick_rect), "run and wave remain on left above movement stick at " + str(size))
  await capture("ui_%dx%d" % [size.x, size.y])
 root.size = Vector2i(1280, 720)
 await ticks(3)

 # Jump through the real HUD signal while holding the keyboard movement input.
 var origin := player.global_position
 Input.action_press("move_back")
 scene.get_node("HUD/FishingHUD/SafeArea/MovementActions/Jump").pressed.emit()
 await ticks(8)
 expect(not player.is_on_floor() and player.global_position.y > origin.y + 0.35, "HUD jump produces physical lift while moving")
 expect(model.current_action == &"Jump_2", "airborne movement plays Jump_2")
 var falling_speed := player.velocity.y
 player.request_jump()
 await ticks(1)
 expect(player.velocity.y < falling_speed, "jump cannot reset upward speed in midair")
 await capture("jump")
 Input.action_release("move_back")
 await ticks(65)
 expect(player.is_on_floor() and model.current_action == &"Idle_A", "jump lands and restores idle")
 var stick: TouchJoystick = scene.get_node("HUD/FishingHUD").move_joystick
 var jump_button: Button = scene.get_node("HUD/FishingHUD/SafeArea/MovementActions/Jump")
 var stick_point := stick.get_global_rect().get_center() + Vector2(0, 48)
 var jump_point := jump_button.get_global_rect().get_center()
 touch(0, true, stick_point)
 touch(1, true, jump_point)
 touch(1, false, jump_point)
 await ticks(7)
 expect(stick.touch_index == 0 and stick.direction.length() > 0.3 and not player.is_on_floor(), "second finger jumps while first finger keeps walking")
 touch(0, false, stick_point)
 await ticks(65)

 var dry := Vector2(definition.center_at(42) - definition.half_width_at(42) - 8, 42)
 teleport(Vector3(dry.x, definition.ground_height(dry) + 0.1, dry.y))
 await ticks(15)
 Input.action_press("move_back")
 await ticks(12)
 expect(model.current_action == &"Walk", "ordinary travel uses Walk")
 Input.action_press("sprint")
 await ticks(12)
 expect(model.current_action == &"Sprint" and player.actual_ground_speed > player.move_speed * 1.4, "Shift runs faster and uses Sprint")
 var travel_direction := Vector3(player.velocity.x, 0, player.velocity.z).normalized()
 expect((-player.visual.global_basis.z).dot(travel_direction) > 0.95 and model._direction > 0, "game camera preserves joystick-facing and forward gait for back input")
 await capture("run")
 Input.action_release("sprint")
 Input.action_release("move_back")
 await ticks(4)
 player.request_greeting()
 await ticks(10)
 expect(model.current_action == &"Greeting", "wave control plays Greeting")

 # Select actual equipment resources via the production controller refresh path.
 var profile: AnglerProfile = root.get_node("AnglerSave")
 fishing.bind_profile(profile)
 var light := model.rod_mesh
 profile.data.equipped.rod = "heavy_rod"
 fishing.refresh_equipment()
 expect(model.rod_mesh != light and model.rod_mesh.name == "HeavyRod", "equipped heavy rod changes held model")
 var heavy := model.rod_mesh
 fishing.refresh_equipment()
 expect(model.rod_mesh == heavy and model.rod_grip.get_child_count() == 1, "repeated equipment sync does not duplicate rod models")
 profile.data.equipped.rod = "light_rod"
 fishing.refresh_equipment()
 expect(model.rod_mesh.name == "LightRod", "equipping light rod restores its visual")
 # Avoid writing or consuming inventory during the fishing animation checks.
 fishing.profile = null
 teleport(origin)
 await ticks(20)
 var aiming_hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var aim_point := aiming_hud.rod_joystick.get_global_rect().get_center() + Vector2(0, -42)
 touch(2, true, aim_point)
 await ticks(5)
 expect(fishing.state == FishingController.State.READY and model.rod_mesh.visible and model.current_action == &"Fishing_Reel", "aiming raises equipped rod before casting")
 await capture("aiming")
 aiming_hud.rod_joystick.reset()
 for frame in 3:
  await process_frame
 await ticks(4)
 expect(not model.rod_mesh.visible and not model.aiming and fishing.state == FishingController.State.READY, "cancelled aim lowers rod without casting")
 touch(2, true, aim_point)
 await ticks(3)
 touch(2, false, aim_point)
 expect(fishing.state == FishingController.State.CASTING, "releasing aim casts from held-rod pose")
 await ticks(4)
 expect(model.current_action == &"Fishing_Cast" and model.rod_mesh.visible, "cast clip and held rod follow controller")
 expect(is_equal_approx(model.animation_player.speed_scale * fishing.tuning.cast_duration, model.animation_player.get_animation("Fishing_Cast").length), "cast clip is timed to bait flight")
 await capture("cast")
 fishing.advance(fishing.tuning.cast_duration + 0.01, player.global_position)
 await ticks(5)
 expect(model.current_action == &"Fishing_Reel" and model.animation_player.speed_scale == 0.0, "waiting holds a quiet fishing pose")
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 for size in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1600, 720)]:
  root.size = size
  for frame in 4:
   await process_frame
  var eye_rect: Rect2 = hud.get_node("SafeArea/OrbitButton").get_global_rect()
  var distance_rect: Rect2 = hud.get_node("SafeArea/LineInfo").get_global_rect()
  expect(root.get_visible_rect().encloses(eye_rect) and not eye_rect.intersects(distance_rect) and not eye_rect.intersects(hud.rod_joystick.get_global_rect()), "orbit button clears distance label and rod control at " + str(size))
  expect(not hud.get_node("SafeArea/MovementActions").visible, "fishing hides unavailable movement actions at " + str(size))
  await capture("waiting_layout_%dx%d" % [size.x, size.y])
 root.size = Vector2i(1280, 720)
 await ticks(3)
 var hand := model.skeleton.find_bone("hand_r")
 var hand_position := model.skeleton.global_transform * model.skeleton.get_bone_global_pose(hand).origin
 expect(model.rod_grip.global_position.distance_to(hand_position) < 0.12, "swappable rod grip follows animated hand")
 var rod_reach := model.rod_tip_position().distance_to(model.rod_grip.global_position)
 expect(rod_reach > 1.0 and rod_reach < 2.2, "held rod keeps playable world size despite imported rig units")
 var tip: Marker3D = scene.get_node("FishingEffects").rod_tip
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
 expect(tip.global_position.distance_to(model.rod_tip_position()) < 0.1, "line proxy follows equipped rod tip")
 var straight_tip := model.rod_tip_position()
 player.set_rod_pose(true, 0.9, 0.0)
 model.set_rod_load(0.9, 0.0)
 expect(model.rod_tip_position().distance_to(straight_tip) > 0.05, "tension bends equipped rod and moves its real tip")
 Input.action_press("reel_in")
 await ticks(6)
 expect(model.animation_player.speed_scale > 0.0, "reel input animates the held rod")
 Input.action_release("reel_in")
 var fish: FishState = scene.get_node("PondEcosystem").fish[0]
 fishing.active_fish = fish
 fishing._change_state(FishingController.State.BITE)
 fishing.strike()
 fishing.tension = 0.6
 await ticks(25)
 expect(model.current_action == &"Fishing_Catch", "loaded fight uses Fishing_Catch")
 Input.action_press("move_back")
 await ticks(10)
 expect(model.locomotion_active, "walking in a fight layers legs under rod action")
 Input.action_release("move_back")
 await capture("fight")

 # Walk through the real bank into deep water; no teleport into water.
 fishing.cancel()
 var edge_x := definition.center_at(42) - definition.half_width_at(42)
 teleport(Vector3(edge_x - 1.0, definition.ground_height(Vector2(edge_x - 1.0, 42)) + 0.08, 42))
 player.facing_follows_camera = false
 Input.action_press("move_right")
 var entered := false
 for i in 260:
  await physics_frame
  if player.swimming:
   entered = true
   break
 expect(entered, "walk transitions through shallows into swimming")
 await ticks(45)
 expect(player.swimming and model.current_action == &"Swim_Fwd", "deep-water movement plays Swim_Fwd")
 expect(absf(player.global_position.y - (definition.water_height - player.swim_float_depth)) < 0.15, "buoyancy holds player at water surface")
 expect(not model.rod_mesh.visible and not fishing.cast(), "swimming hides rod and rejects casting")
 await capture("swim")
 Input.action_release("move_right")
 await ticks(20)
 expect(model.current_action == &"Swim_Idle", "releasing swim input treads water")
 var chest := model.skeleton.find_bone("spine_03")
 var chest_y := (model.skeleton.global_transform * model.skeleton.get_bone_global_pose(chest)).origin.y
 expect(absf(chest_y - definition.water_height) < 0.12, "idle floating puts chest at water level")
 await capture("swim_idle")
 var before_wake: int = scene.get_node("WaterInteractions").emitted_count
 Input.action_press("move_left")
 await ticks(25)
 expect((-player.visual.global_basis.z).dot(Vector3.LEFT) > 0.95, "swimming turns model toward reverse travel instead of camera yaw")
 expect(scene.get_node("WaterInteractions").emitted_count > before_wake, "swimming produces water wake")
 var exited := false
 for i in 450:
  await physics_frame
  if not player.swimming and player.is_on_floor() and player.global_position.x < edge_x - 0.5:
   exited = true
   break
 Input.action_release("move_left")
 await ticks(10)
 expect(exited and player.can_fish(), "swimmer climbs the actual bank and can fish again")
 expect(model.current_action == &"Idle_A", "leaving water restores grounded animation")
 # Jump from water, with a cooldown preventing immediate buoyancy recapture.
 var deep := Vector3(edge_x + 7, definition.water_height - player.swim_float_depth, 42)
 teleport(deep)
 await ticks(20)
 expect(player.swimming, "deep-water test is swimming")
 player.request_jump()
 await ticks(5)
 expect(not player.swimming and player.velocity.y > 0.0, "water jump breaks surface buoyancy")
 await ticks(70)
 expect(player.swimming, "water jump falls back into swimming")
 # Entering water during fishing clears controller and character fishing state.
 fishing._change_state(FishingController.State.WAITING)
 player._set_swimming(false)
 player._update_swimming()
 await ticks(3)
 expect(fishing.state == FishingController.State.READY and not player.fishing_active, "entering water cancels fishing safely")
 player.input_enabled = false
 player.run_requested = true
 Input.action_press("move_forward")
 player.request_jump()
 await ticks(3)
 expect(is_zero_approx(player.velocity.x) and is_zero_approx(player.velocity.z) and not player.running, "disabled input blocks movement, sprint and jump")
 Input.action_release("move_forward")

 print("TRAVERSAL EQUIPMENT RESULT: ", checks, " checks, ", failures, " failures")
 scene.queue_free()
 await process_frame
 quit(failures)
