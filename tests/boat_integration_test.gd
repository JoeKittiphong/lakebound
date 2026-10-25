extends SceneTree

var failures := 0
var checks := 0
var scene: Node3D
var player: AnglerPlayer
var boat: FishingBoat
var hud: FishingHUD
var fishing: FishingController

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

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("boat_" + label + ".png"))

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.size = Vector2i(1280, 720)
 scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 player = scene.get_node("Player")
 boat = scene.get_node("FishingBoat")
 hud = scene.get_node("HUD/FishingHUD")
 fishing = scene.get_node("FishingController")
 fishing.set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 await ticks(25)
 hud.get_node("SafeArea/FirstCatch")._skip()
 var model := player.character_model
 var calf := model.skeleton.find_bone("calf_r")
 var standing_knee := model.skeleton.get_bone_pose_rotation(calf)
 expect(model.get_node("Asset").scene_file_path.ends_with("fisherman_rigged.glb"), "player uses the new rigged fisherman")
 for clip in ["Driving", "Sitting_Idle", "Fishing_Cast", "Fishing_Catch", "Fishing_Reel", "Walk", "Idle_A", "Sprint", "Jump_2", "Swim_Fwd", "Swim_Idle", "Greeting"]:
  expect(model.animation_player.has_animation(clip), "selected clip exists: " + clip)
 expect(not hud.get_node("SafeArea/BoatActions").visible, "boat prompt hidden out of range")
 expect(not boat.board(player), "boarding from far away is rejected")
 # Walk toward the moored boat using the real movement stick.
 player.facing_follows_camera = false
 var near := false
 for i in 240:
  var offset := boat.global_position - player.global_position
  hud.move_joystick.direction = Vector2(offset.x, offset.z).normalized()
  await physics_frame
  if boat.can_board(player):
   near = true
   break
 hud.move_joystick.direction = Vector2.ZERO
 for i in 4:
  await process_frame
 expect(near and hud.get_node("SafeArea/BoatActions/Action").text == "ขับเรือ" and hud.get_node("SafeArea/BoatActions").visible, "walking close reveals Drive Boat button")
 await capture("nearby")
 hud.get_node("SafeArea/BoatActions/Action").pressed.emit()
 await ticks(35)
 expect(player.boat == boat and boat.passenger == player, "Drive Boat boards the nearby boat")
 expect(model.current_action == &"Sitting_Idle" and not model.rod_mesh.visible, "stationary boat driver sits without a rod")
 expect(not player.request_jump() and player.collision_mask == 0, "passenger cannot jump out or collide with own boat")
 expect(player.global_position.distance_to(boat.driver_anchor.global_position) < 0.05, "seated player follows driver marker")
 for i in 4:
  await process_frame
 expect(standing_knee.angle_to(model.skeleton.get_bone_pose_rotation(calf)) > 0.5, "seated animation actually bends knees instead of standing")
 await capture("driving")
 expect(not player.can_fish() and not fishing.cast(), "casting is blocked while driving")
 var start := boat.global_position
 var wake_count: int = scene.get_node("WaterInteractions").emitted_count
 Input.action_press("move_forward")
 await ticks(100)
 Input.action_release("move_forward")
 expect(boat.global_position.distance_to(start) > 3.0, "movement stick drives boat across water")
 expect(model.current_action == &"Driving", "moving boat uses active seated steering animation")
 expect(scene.get_node("WaterInteractions").emitted_count > wake_count, "moving boat produces a stern wake")
 var yaw := boat.rotation.y
 Input.action_press("move_right")
 await ticks(20)
 Input.action_release("move_right")
 expect(absf(angle_difference(boat.rotation.y, yaw)) > 0.15, "horizontal input steers boat")
 expect(player.global_position.distance_to(boat.driver_anchor.global_position) < 0.05, "passenger stays attached while boat moves and turns")
 hud.get_node("SafeArea/BoatActions/Action").pressed.emit()
 await ticks(12)
 expect(boat.mode == FishingBoat.Mode.FISHING and not model.driving and model.current_action == &"Fishing_Reel", "Fish button stops boat and stands character in fishing pose")
 expect(player.can_fish() and model.rod_mesh.visible, "standing passenger holds equipped rod and may cast")
 expect(is_zero_approx(boat.forward_speed) and boat.velocity.length() < 0.01, "fishing mode anchors boat immediately")
 expect(player.global_position.distance_to(boat.fishing_anchor.global_position) < 0.05, "standing player uses fishing marker")
 Input.action_press("move_forward")
 await ticks(20)
 Input.action_release("move_forward")
 expect(boat.velocity.length() < 0.01 and player.global_position.distance_to(boat.fishing_anchor.global_position) < 0.05, "walking input cannot drift standing passenger off deck")
 await capture("standing")
 for size in [Vector2i(1024, 768), Vector2i(1600, 720)]:
  root.size = size
  for i in 4:
   await process_frame
  var actions: Control = hud.get_node("SafeArea/BoatActions")
  expect(root.get_visible_rect().encloses(actions.get_global_rect()) and not actions.get_global_rect().intersects(hud.rod_joystick.get_global_rect()), "boat controls remain visible and clear of fishing stick at " + str(size))
  await capture("standing_%dx%d" % [size.x, size.y])
 root.size = Vector2i(1280, 720)
 expect(fishing.cast(), "standing on boat can cast into real river")
 await ticks(5)
 expect(model.current_action == &"Fishing_Cast", "boat casting plays original fishing cast")
 await capture("cast")
 fishing.advance(fishing.tuning.cast_duration + 0.01, player.global_position)
 await ticks(5)
 expect(fishing.state == FishingController.State.WAITING, "cast from boat enters waiting")
 fishing.rod_input = Vector2(0, 1)
 await ticks(5)
 expect(model.current_action == &"Fishing_Reel", "boat fishing retains reel animation")
 var fish: FishState = scene.get_node("PondEcosystem").fish[0]
 fishing.active_fish = fish
 fishing._change_state(FishingController.State.BITE)
 expect(fishing.strike(), "fish can be hooked while standing aboard")
 fishing.tension = 0.6
 await ticks(25)
 expect(model.current_action == &"Fishing_Catch", "boat fight retains original catch/pull animation")
 var tip: Marker3D = scene.get_node("FishingEffects").rod_tip
 for i in 3:
  await process_frame
 expect(tip.global_position.distance_to(model.rod_tip_position()) < 0.1, "line still follows held rod while fighting aboard")
 await capture("fight")
 # Returning to driving during fishing cancels bait and clears the rod.
 hud.get_node("SafeArea/BoatActions/Action").pressed.emit()
 await ticks(8)
 expect(fishing.state == FishingController.State.READY and boat.mode == FishingBoat.Mode.DRIVING and not model.rod_mesh.visible, "Drive Boat safely cancels active fishing and returns to seated driving")
 boat.rotation.y = -PI / 2
 Input.action_press("move_back")
 await ticks(180)
 Input.action_release("move_back")
 expect(boat.pond.definition.water_depth_at(Vector2(boat.global_position.x, boat.global_position.z)) >= boat.minimum_depth - 0.05, "boat cannot drive onto dry bank")
 boat.global_position = Vector3(0, -0.18, 0)
 boat.forward_speed = 0
 await ticks(25)
 expect(not boat.disembark(), "disembarking in deep open water is refused")
 expect(hud.get_node("SafeArea/BoatActions/Exit").disabled, "shore exit button disabled far from land")
 var roof := StaticBody3D.new()
 var roof_collision := CollisionShape3D.new()
 var roof_shape := BoxShape3D.new()
 roof_shape.size = Vector3(5, 0.2, 7)
 roof_collision.shape = roof_shape
 roof.add_child(roof_collision)
 scene.add_child(roof)
 roof.global_position = boat.global_position + Vector3(0, 2.25, 0)
 await ticks(5)
 expect(not boat.can_stand_to_fish(), "low overhead obstacle prevents standing through a bridge")
 hud.get_node("SafeArea/BoatActions/Action").pressed.emit()
 expect(boat.mode == FishingBoat.Mode.DRIVING, "blocked standing request leaves driver safely seated")
 roof.queue_free()
 await ticks(5)
 expect(boat.can_stand_to_fish(), "standing available again in open water")
 # Return to mooring, then use the authored Exit button.
 boat.global_position = start
 boat.rotation.y = -PI / 2
 boat.forward_speed = 0
 await ticks(25)
 expect(boat.exit_point.is_finite(), "near shore finds collision-free landing point")
 hud.get_node("SafeArea/BoatActions/Exit").pressed.emit()
 await ticks(20)
 expect(player.boat == null and boat.passenger == null and player.collision_mask != 0, "Exit restores walking collisions and releases passenger")
 expect(not model.driving and not player.swimming and player.is_on_floor(), "disembarked player stands safely on bank or shallows")
 await capture("disembarked")
 # Empty boat does not accept phantom input or keep sailing.
 var parked := boat.global_position
 Input.action_press("move_forward")
 await ticks(12)
 Input.action_release("move_forward")
 expect(boat.global_position.distance_to(parked) < 0.05, "unoccupied boat stays parked")
 print("BOAT INTEGRATION RESULT: ", checks, " checks, ", failures, " failures")
 scene.queue_free()
 await process_frame
 quit(failures)
