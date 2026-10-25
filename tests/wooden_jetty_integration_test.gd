extends SceneTree
var checks := 0
var failures := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")
func _initialize() -> void:
 call_deferred("run")
func expect(value: bool, label: String) -> void:
 checks += 1
 print("PASS: " if value else "FAIL: ", label)
 failures += int(not value)
func ticks(count: int) -> void:
 for i in count:
  await physics_frame
func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func new_model(dock: Node) -> bool:
 return dock.get_node("Visual").scene_file_path.ends_with("wooden_bridge_joined.glb")
func floor_below(scene: Node3D, point: Vector3) -> Dictionary:
 return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP*3, point-Vector3.UP*5))
func run() -> void:
 root.size = Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled = false
 for path in ["res://features/loading/loading.tscn", "res://features/menu/main_menu.tscn"]:
  var screen: Node = load(path).instantiate()
  root.add_child(screen)
  current_scene = screen
  var cinematic: Node3D = screen.get_node("Cinematic")
  expect(new_model(cinematic.get_node("Dock")), "new timber model is authored in " + path)
  expect(not cinematic.get_node("Dock").has_node("Plank00"), "old dock meshes removed")
  if path.contains("loading.tscn"):
   screen.wait_for_intro = false
   cinematic.timeline.speed_scale = 0.0
   cinematic.timeline.seek(3.2, true)
  await ticks(8)
  var hit := floor_below(cinematic,cinematic.actor_motion.global_position)
  expect(not hit.is_empty() and absf(hit.position.y - cinematic.actor_motion.global_position.y)<.10, "cinematic actor stays on visible dock height")
  await capture("new_jetty_" + ("loading" if path.contains("loading.tscn") else "menu"))
  if path.contains("loading.tscn"):
   # Finish its asynchronous destination load before releasing and reloading
   # the same menu resources in the next test case.
   var deadline := Time.get_ticks_msec()+30000
   while not screen.ready_to_start and Time.get_ticks_msec()<deadline:
    await create_timer(.05).timeout
   expect(screen.ready_to_start, "loading completes with the new dock model")
  screen.queue_free()
  await process_frame
  await process_frame
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled = false
 root.add_child(game)
 current_scene = game
 await ticks(25)
 game.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip()
 game.get_node("PondEcosystem").set_physics_process(false)
 var fishing: FishingController = game.get_node("FishingController")
 fishing.set_physics_process(false)
 var player: AnglerPlayer = game.get_node("Player")
 var definition: RiverDefinition = game.get_node("World").definition
 var dock: Node3D = game.get_node("World/Jetty")
 expect(new_model(dock) and dock.has_node("Approach/Shape"), "map jetty reuses model with authored shore ramp")
 var edge := definition.center_at(24)+definition.half_width_at(24)
 for x in [edge+4.5,edge+2,edge,edge-4,edge-8]:
  var hit := floor_below(game,Vector3(x,.6,24))
  expect(not hit.is_empty() and hit.position.y>.4, "continuous floor at jetty x="+str(x))
 game.set_process(false)
 player.facing_follows_camera = false
 player.global_position = Vector3(edge+6.5,definition.ground_height(Vector2(edge+6.5,24))+.08,24)
 player.velocity = Vector3.ZERO
 await ticks(15)
 Input.action_press("move_left")
 for i in 450:
  await physics_frame
  if player.global_position.x < edge-7.5:break
 Input.action_release("move_left")
 await ticks(10)
 expect(player.global_position.x < edge-7.5 and player.is_on_floor() and not player.swimming, "player walks from bank over ramp to end of new jetty")
 expect(player.can_fish(), "fishing is available on new jetty")
 fishing.aim_yaw = PI/2
 expect(fishing.cast(), "actual cast from new jetty reaches river water")
 fishing.cancel()
 var camera: Camera3D = game.get_node("CameraRig/Camera3D")
 camera.get_parent().set_process(false)
 camera.get_parent().set_physics_process(false)
 camera.global_position = Vector3(edge-17,8,36)
 camera.look_at(Vector3(edge-3,.5,24))
 await capture("new_jetty_map")
 Input.action_press("move_right")
 for i in 450:
  await physics_frame
  if player.global_position.x > edge+5.5:break
 Input.action_release("move_right")
 await ticks(10)
 expect(player.global_position.x > edge+5.5 and player.is_on_floor(), "player walks safely back onto bank")
 game.queue_free()
 await process_frame
 print("WOODEN JETTY RESULT: ",checks," checks, ",failures," failures")
 quit(int(failures>0))
