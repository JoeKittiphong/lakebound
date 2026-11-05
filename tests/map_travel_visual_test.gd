extends SceneTree
const Travel = preload("res://features/gameplay/map_travel_state.gd")
var failures := 0
var checks := 0
var game: Node3D
var profile: AnglerProfile

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1

func ticks(count := 5) -> void:
 for i in count: await physics_frame

func open_map(region := "river") -> void:
 var scene_path := "res://features/gameplay/gameplay.tscn"
 if region != "river":
  for entry in RegionCatalog.MAPS:
   if entry.id == region: scene_path = entry.scene
 game = load(scene_path).instantiate()
 game.economy_enabled = true
 root.add_child(game); current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 game.fishing.set_physics_process(false)
 game.pond.set_physics_process(false)
 await ticks(15)
 game.hud.get_node("SafeArea/FirstCatch")._skip()

func close_map() -> void:
 game.queue_free()
 await ticks(3)
 current_scene = null

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join(label+".png"))

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 profile = root.get_node("AnglerSave")
 profile.save_path = "user://map-travel-profile.cfg"
 profile.data = profile.defaults()
 # Old profiles acquire empty checkpoints without losing progression.
 var old := profile.defaults()
 old.erase("travel"); old.coins = 1234
 expect(ProfileStore.save_profile("user://pre-travel.cfg",old) == OK,"write old profile fixture")
 var loaded := ProfileStore.load_profile("user://pre-travel.cfg")
 expect(not loaded.incompatible and loaded.data.travel.is_empty() and loaded.data.coins == 1234,"old saves migrate without resetting progression")
 await open_map()
 var player: AnglerPlayer = game.player
 var boat: FishingBoat = game.vessel
 var definition := player.pond.definition as RiverDefinition
 player.set_physics_process(false)
 var dry := Vector2(definition.center_at(42)-definition.half_width_at(42)-12,42)
 var stand := Vector3(dry.x,definition.ground_height(dry)+.1,dry.y)
 player.position = stand
 player.visual.rotation.y = 1.1
 game.camera_rig.rotation = Vector3(.1,.8,0)
 boat.position = Vector3(definition.center_at(0),definition.surface_height(),0)
 boat.rotation.y = .6
 var parked := boat.position
 await close_map()
 loaded = ProfileStore.load_profile(profile.save_path)
 expect(not loaded.incompatible and loaded.data.travel.has("river"),"leaving the map writes a valid checkpoint to disk")
 expect(loaded.data.travel.river.player.is_equal_approx(stand) and loaded.data.travel.river.boat.is_empty(),"player position persists without a deployed hull")
 profile.load_profile()
 await open_map()
 player = game.player; boat = game.vessel
 expect(Vector2(player.position.x,player.position.z).distance_to(dry)<.05,"re-entering restores the last shore position")
 expect(not boat.deployed and not boat.visible,"returning to map never restores a parked boat")
 expect(is_equal_approx(player.visual.rotation.y,1.1) and is_equal_approx(game.camera_rig.rotation.y,.8),"player heading and view direction restore")
 expect(not player.run_requested and boat.forward_speed == 0,"restore never resumes movement or boat momentum")
 boat.set_deployed(true); boat.position = parked
 player.position = boat.position + Vector3.RIGHT * 3.5
 player.position.y = definition.surface_height() - player.swim_float_depth
 await ticks()
 expect(player.swimming and boat.can_board(player),"swimming player can reach the parked boat")
 game._on_boat_action()
 expect(boat.passenger == player and player.boat == boat,"actual HUD action boards from water")
 boat.position += Vector3(0,0,-12)
 boat.rotation.y = 1.0
 boat._sync_passenger()
 var aboard_at := boat.position
 await close_map()
 profile.load_profile()
 await open_map()
 player = game.player; boat = game.vessel
 expect(player.boat == null and player.swimming,"re-entry after aboard exit returns a swimming player")
 expect(not boat.deployed and not boat.visible,"aboard checkpoint cannot auto-deploy a boat")
 boat.set_deployed(true); boat.position = aboard_at
 player.position = boat.position + Vector3.RIGHT * 3.5
 player.position.y = definition.surface_height() - player.swim_float_depth
 game._on_boat_action()
 await capture("restored-aboard")
 # Use the authored button signal through the gameplay handler.
 expect(boat.find_shore_exit() == Vector3.INF,"deep-water fixture has no nearby shore")
 await ticks(22)
 expect(not game.hud.get_node("SafeArea/BoatActions/Exit").disabled,"exit action is available in open water")
 game.hud.get_node("SafeArea/BoatActions/Exit").pressed.emit()
 await ticks(8)
 expect(player.boat == null and boat.passenger == null and player.swimming,"HUD exit disembarks into swimming")
 expect(player.collision_mask != 0 and not player.character_model.driving,"water exit restores collision and swimming animation state")
 expect(boat.mode == FishingBoat.Mode.MOORED and boat.forward_speed == 0,"empty boat stops immediately")
 var swim_point := player.position
 await capture("swimming-beside-boat")
 await close_map()
 profile.load_profile()
 await open_map()
 player = game.player; boat = game.vessel
 expect(player.swimming and player.boat == null,"water checkpoint restores swimming rather than seating")
 expect(Vector2(player.position.x,player.position.z).distance_to(Vector2(swim_point.x,swim_point.z))<.05,"swimming position survives re-entry")
 boat.set_deployed(true); boat.position = aboard_at
 game._on_boat_action()
 expect(player.boat == boat,"swimmer can reboard after reloading map")
 # Temporary obstructions must prevent an unsafe water exit.
 var blocker := StaticBody3D.new()
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new(); box.size = Vector3(20,5,20)
 collision.shape = box; blocker.add_child(collision); game.add_child(blocker)
 blocker.position = boat.position
 await ticks()
 expect(not boat.find_water_exit().is_finite() and not boat.disembark(),"blocked water exits never spawn player inside geometry")
 blocker.queue_free(); await ticks()
 expect(boat.disembark(),"exit recovers after obstacle removal")
 await ticks()
 var checkpoint := Travel.capture(player,boat,game.camera_rig)
 var broken := checkpoint.duplicate(true); broken.player = Vector3(INF,0,0)
 var data := profile.defaults(); data.coins = 777; data.travel = {"river":broken}
 ProfileStore.save_profile("user://bad-travel.cfg",data)
 loaded = ProfileStore.load_profile("user://bad-travel.cfg")
 expect(not loaded.incompatible and loaded.data.coins == 777 and loaded.data.travel.is_empty(),"corrupt optional position is discarded without losing inventory or progression")
 var invalid_geometry := checkpoint.duplicate(true); invalid_geometry.player = Vector3(9999,1,9999)
 var before := player.position
 expect(not Travel.restore(invalid_geometry,player,boat,game.camera_rig) and player.position == before,"out-of-map checkpoint retains the safe authored position")
 var underground := checkpoint.duplicate(true); underground.player.y = -500
 expect(not Travel.restore(underground,player,boat,game.camera_rig) and player.position == before,"below-terrain checkpoint cannot restore under the map")
 profile.data.travel["river"] = checkpoint
 var restored_cloud := CloudRestore.assemble(profile.data,[],false)
 expect(not restored_cloud.is_empty() and restored_cloud.travel == profile.data.travel,"cloud refresh preserves local map checkpoints")
 var real_path := profile.save_path
 profile.save_path = "user://missing-folder/map.cfg"
 var previous: Dictionary = profile.data.travel.duplicate(true)
 var changed := checkpoint.duplicate(true); changed.yaw = .42
 expect(not profile.store_map_state("river",game.pond.snapshot(),changed) and profile.data.travel == previous,"failed save rolls back checkpoint atomically")
 game._on_back_pressed()
 expect(current_scene == game and not profile.save_error.is_empty(),"failed checkpoint prevents leaving the map before retry")
 profile.save_path = real_path
 await close_map()
 await open_map("lotus_marsh")
 expect(game.player.boat == null and not profile.data.travel.has("lotus_marsh"),"first visit to another map uses its own spawn")
 game.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
 loaded = ProfileStore.load_profile(profile.save_path)
 expect(loaded.data.travel.has("lotus_marsh"),"application pause checkpoints the current map")
 game.menu_path = "res://tests/fixtures/map_exit.tscn"
 game._on_back_pressed()
 await ticks(4)
 expect(current_scene != game and current_scene.name == "MapExitFixture","Back saves the checkpoint before changing scenes")
 current_scene.queue_free(); await ticks(2)
 expect(profile.data.travel.has("river") and profile.data.travel.has("lotus_marsh") and not profile.data.travel.lotus_marsh.player.is_equal_approx(profile.data.travel.river.player),"each map retains an independent checkpoint")
 # Exercise the same water/boat rules against all authored map geometries.
 for entry in RegionCatalog.MAPS:
  profile.data.travel.erase(entry.id)
  await open_map(entry.id)
  player = game.player; boat = game.vessel
  boat.set_deployed(true)
  var world_definition: PondDefinition = player.pond.definition
  var rng := RandomNumberGenerator.new(); rng.seed = 42
  var deep_ready := false
  for attempt in 200:
   var candidate := world_definition.spawn_position(rng,Vector2(1,2),-1)
   if world_definition.water_depth_at(Vector2(candidate.x,candidate.z)) <= 2: continue
   boat.position = Vector3(candidate.x,world_definition.surface_height(),candidate.z)
   player.position = boat.position + Vector3.UP * .3
   if player.boat == null and not boat.board(player): continue
   boat._sync_passenger()
   if not boat.find_shore_exit().is_finite() and boat.find_water_exit().is_finite():
    deep_ready = true; break
  expect(deep_ready,"safe open-water fixture exists in " + entry.id)
  if deep_ready:
   expect(boat.disembark(),"water disembark works in " + entry.id)
   await ticks(4)
   expect(player.swimming and boat.board(player),"swim and reboard work in " + entry.id)
   var aboard_state := Travel.capture(player,boat,game.camera_rig)
   boat.disembark(); await ticks(3)
   expect(Travel.restore(aboard_state,player,boat,game.camera_rig) and player.boat == null and not boat.deployed,"checkpoint restores swimmer without a hull in " + entry.id)
  await close_map()
 print("MAP TRAVEL RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
