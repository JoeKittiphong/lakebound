extends SceneTree
var errors := 0
var checks := 0
var scene: Node3D
var definition: RiverDefinition
var player: AnglerPlayer
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  errors += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)
func floor_at(point: Vector2) -> Dictionary:
 var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 30, point.y), Vector3(point.x, -30, point.y), 1)
 query.hit_back_faces = false
 return root.world_3d.direct_space_state.intersect_ray(query)
func frames(n: int = 3) -> void:
 for i in n:
  await physics_frame
func press_direction(direction: Vector2) -> void:
 for action in ["move_left", "move_right", "move_forward", "move_back"]:
  Input.action_release(action)
 if direction.x > 0: Input.action_press("move_right", direction.x)
 elif direction.x < 0: Input.action_press("move_left", -direction.x)
 if direction.y > 0: Input.action_press("move_back", direction.y)
 elif direction.y < 0: Input.action_press("move_forward", -direction.y)
func walk_to(point: Vector2, max_frames: int = 900) -> bool:
 for step in max_frames:
  var here := Vector2(player.position.x, player.position.z)
  if here.distance_to(point) < 0.75:
   press_direction(Vector2.ZERO)
   return true
  press_direction((point - here).normalized())
  await physics_frame
 press_direction(Vector2.ZERO)
 push_error("Walk stuck at ", player.position, " target ", point)
 return false
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 var pond: PondEcosystem = scene.get_node("PondEcosystem")
 var fishing: FishingController = scene.get_node("FishingController")
 definition = scene.get_node("World").definition
 player = scene.get_node("Player")
 pond.set_physics_process(false)
 fishing.set_physics_process(false)
 await frames(20)
 expect(definition is RiverDefinition and pond.definition == definition, "gameplay loads the authored river and shares its geometry rules")
 expect(is_equal_approx(player.scale.y, 1.0) and is_equal_approx(player.move_speed, 3.8), "human scale and normal walking speed remain unchanged")
 expect(definition.water_depth_at(Vector2(definition.center_at(0), 0)) > 11, "main pool is more than eleven meters deep")
 expect(scene.get_node("World/TerrainTiles").get_child_count() == 225, "225 editable terrain tiles are serialized before Play")
 expect(scene.get_node("World/Bridge").get_child_count() > 10 and scene.get_node("World/Jetty").has_node("Visual") and scene.get_node("World/Jetty").has_node("Approach/Shape"), "bridge, approach ramps, supports and jetty are authored")
 expect(pond.fish.size() == 112, "seven persistent schools exist before casting")
 var water: MeshInstance3D = scene.get_node("World/RiverWater")
 expect(water.mesh.surface_get_material(0).shader.resource_path == "res://world/water.gdshader", "existing Godot water shader is reused")
 var valid_fish := true
 for fish in pond.fish:
  var d := definition.water_depth_at(Vector2(fish.position.x, fish.position.z))
  valid_fish = valid_fish and d > 0 and fish.position.y <= d
 expect(valid_fish, "all initial fish are in water above the physical riverbed")
 # Both dry bank trails must have real floor and obey the walking constraint.
 var valid_paths := true
 var largest_error := 0.0
 for side in [-1, 1]:
  for z in range(-116, 109, 4):
   var x: float = definition.center_at(z) + side * (definition.half_width_at(z) + 6.5)
   var ground := floor_at(Vector2(x, z))
   if ground.is_empty():
    valid_paths = false
   else:
    largest_error = maxf(largest_error, absf(ground.position.y - definition.ground_height(Vector2(x, z))))
   var p := Vector3(x, 2, z)
   valid_paths = valid_paths and definition.constrain_walking(p).distance_to(p) < 0.01
 expect(valid_paths and largest_error < 0.8, "both full bank paths have colliders matching their terrain (max error %.3fm)" % largest_error)
 var ford_ok := true
 for i in 41:
  var x := definition.center_at(108) - definition.half_width_at(108) + float(i) / 40 * definition.half_width_at(108) * 2
  var hit := floor_at(Vector2(x, 108))
  if hit.is_empty() or -0.18 - hit.position.y > 0.61:
   ford_ok = false
 expect(ford_ok, "physical ford floor is continuous and never deeper than the wading limit")
 var center := definition.center_at(-116)
 var bridge_hit := floor_at(Vector2(center + 0.3, -116))

 expect(not bridge_hit.is_empty() and absf(bridge_hit.position.y - 1.55) < 0.03, "bridge deck collider is at the visible deck height")
 # Large open water must not become an invisible walking surface.
 var forbidden := Vector3(definition.center_at(0), -0.4, 0)
 expect(definition.constrain_walking(forbidden).distance_to(forbidden) > 50, "deep center cannot be walked across")
 # Cast on each bank and the bridge. Land rejects valid-looking non-water targets.
 for data in [[-1, 42], [1, 24], [-1, -65]]:
  var z: float = data[1]
  var side: float = data[0]
  var x: float = definition.center_at(z) + side * (definition.half_width_at(z) + 2)
  player.position = Vector3(x, definition.ground_height(Vector2(x, z)) + 0.1, z)
  fishing.aim_yaw = -PI / 2 if side < 0 else PI / 2
  expect(fishing.cast(), "cast from bank " + str(data))
  fishing.cancel()
 player.position = Vector3(center, 1.56, -116)
 fishing.aim_yaw = PI
 expect(fishing.cast(), "cast from bridge into the deep pool")
 fishing.cancel()
 # Actual capsule traversal: an entire shore loop, bridge and shallow crossing.
 scene.set_process(false)
 scene.get_node("CameraRig").enabled = false
 player.facing_follows_camera = false
 player.move_speed = 3.8 # Traverse at the production walking speed.
 var start_z := 42.0
 var start_x := definition.center_at(start_z) - definition.half_width_at(start_z) - 6.5
 player.position = Vector3(start_x, definition.ground_height(Vector2(start_x, start_z)) + 0.12, start_z)
 await frames(4)
 var walked := true
 for z in range(42, -117, -6):
  var target := Vector2(definition.center_at(z) - definition.half_width_at(z) - 6.5, z)
  if not await walk_to(target, 900):
   walked = false
   break
 expect(walked, "capsule walks the full western bank trail")
 var left := center - definition.bridge_half_length()
 var right := center + definition.bridge_half_length()
 var crossed := await walk_to(Vector2(left - 10, -110), 1800)
 crossed = await walk_to(Vector2(left - 10, -116), 1800) and crossed
 crossed = await walk_to(Vector2(center, -116), 3600) and crossed
 crossed = await walk_to(Vector2(right + 10, -116), 3600) and crossed
 expect(crossed and player.position.y > 0.4, "capsule crosses the bridge via its approach ramp without falling")
 walked = await walk_to(Vector2(right + 10, -108), 1800)
 for z in range(-108, 109, 6):
  if not await walk_to(Vector2(definition.center_at(z) + definition.half_width_at(z) + 6.5, z), 1800):
   walked = false
   break
 expect(walked, "capsule walks the full eastern bank trail")
 var ford_center := definition.center_at(108)
 crossed = await walk_to(Vector2(ford_center, 108), 6000)
 expect(crossed and definition.is_wading(player.position) and player.position.y > -0.8 and player.position.y < -0.2, "capsule physically wades on the shallow bed, not on an invisible bridge")
 crossed = await walk_to(Vector2(ford_center - definition.half_width_at(108) - 6.5, 108), 6000)
 expect(crossed, "capsule exits the ford onto the opposite bank")
 walked = true
 for z in range(102, 41, -6):
  if not await walk_to(Vector2(definition.center_at(z) - definition.half_width_at(z) - 6.5, z), 900):
   walked = false
   break
 expect(walked, "complete bank-bridge-ford walking loop returns to the starting side")
 press_direction(Vector2.ZERO)
 player.set_physics_process(false)
 # Natural bite and complete fight on the actual river, without scripted fish spawning.
 var z := 42.0
 var x := definition.center_at(z) - definition.half_width_at(z) - 2.5
 player.position = Vector3(x, definition.ground_height(Vector2(x, z)), z)
 fishing.aim_yaw = -PI / 2
 fishing.aim_offset = Vector3(0,0,-14)
 fishing.selected_bait = &"dough"
 fishing.selected_depth = 1.5
 pond.reset_population(4207)
 expect(fishing.cast(), "river fishing session starts with a valid shore cast")
 for tick in 900:
  pond.step(0.15)
  fishing.advance(0.15, player.position)
  if fishing.state == fishing.State.BITE:
   break
 expect(fishing.state == fishing.State.BITE, "pre-existing river fish naturally approach and bite")
 if fishing.state == fishing.State.BITE:
  fishing.strike()
  for tick in 9000:
   fishing.rod_input = Vector2(-fishing.lateral_direction, 1.0 if fishing.tension < lerpf(fishing.yellow_start, fishing.red_start, 0.60) else -0.72).limit_length(1)
   fishing.advance(1.0/60.0, player.position)
   if fishing.state != fishing.State.FIGHT:
    break
  expect(fishing.state == fishing.State.RESULT, "river fish can be fought and landed at the shore")
  fishing.resolve_catch(false)
  expect(fishing.state == fishing.State.READY, "release returns to normal river gameplay")
 scene.queue_free()
 await frames(3)
 print("RIVER RESULT: ", checks, " checks, ", errors, " failures")
 quit(errors)










