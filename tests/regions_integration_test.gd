extends SceneTree
var checks:=0
var failures:=0
var profile: AnglerProfile
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1;print("PASS: " if ok else "FAIL: ",label)
 if not ok:failures+=1
func ticks(n: int) -> void:
 for i in n:await physics_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("regions_"+name+".png"))
func run() -> void:
 root.size=Vector2i(1280,720)
 root.get_node("FishCollection").recording_enabled=false
 profile=root.get_node("AnglerSave");profile.save_path="res://exports/qa-fish-models/regions_test_profile.cfg";profile.data=profile.defaults();profile.incompatible=false;profile.save_error=""
 var all_species:={}
 for entry in RegionCatalog.MAPS:
  var game: Node3D=load(entry.scene).instantiate();game.economy_enabled=true;root.add_child(game);current_scene=game
  game.get_node("FishingEffects").audio_enabled=false
  await ticks(35)
  game.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip();await ticks(3)
  var world: Pond=game.get_node("World");var player: AnglerPlayer=game.get_node("Player");var pond: PondEcosystem=game.get_node("PondEcosystem");var fishing: FishingController=game.get_node("FishingController");var boat: FishingBoat=game.get_node("FishingBoat")
  expect(game.map_id==entry.id and fishing.map_id==entry.id,"unique map save identity "+entry.id)
  expect(player.is_on_floor() and not player.swimming,"spawn rests on real terrain "+entry.id)
  expect(pond.species.size()==entry.fish_count,"regional species roster "+entry.id)
  expect(pond.fish.size()==pond.population_limit,"population existed before casting "+entry.id)
  var roster:={}
  for species in pond.species:
   roster[species.id]=true;all_species[species.id]=true
   expect(species.model_scene!=null and species.collection_icon!=null,"model and icon for "+String(species.id))
  for fish in pond.fish:expect(roster.has(fish.species.id),"resident fish "+entry.id)
  var panel: Control=game.get_node("HUD/FishingHUD/MissionPanel")
  expect(panel.definitions.size()==entry.mission_count,"local mission roster "+entry.id)
  for mission in panel.definitions:expect(mission.map_id==entry.id and (mission.species_id.is_empty() or roster.has(StringName(mission.species_id))),"mission has attainable local species "+mission.id)
  expect(game.get_node("HUD/FishingHUD/SafeArea/BaitPanel/Content/DepthRow/Depth").max_value==game.maximum_fishing_depth,"depth control supports region water column "+entry.id)
  expect(game.get_node("HUD/FishingHUD/TacklePanel").map_id==entry.id,"recovery uses region population "+entry.id)
  # Walk on authored terrain away from the dock/ramp, rather than testing only deck collision.
  var start_spawn: Vector3=world.get_node("GameplayMarkers/Spawn").global_position
  if entry.id!="river":
   var land:=start_spawn+Vector3(0,0,7)
   land.y=world.definition.ground_height(Vector2(land.x,land.z))+.12
   player.global_position=land;player.velocity=Vector3.ZERO;await ticks(30)
   expect(player.is_on_floor() and not player.swimming,"solid land away from dock "+entry.id)
   var walk_start:=player.global_position
   player.facing_follows_camera=false
   game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2(0,1)
   await ticks(35)
   game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2.ZERO
   expect(player.global_position.distance_to(walk_start)>1.0 and player.is_on_floor(),"walk along real bank "+entry.id)
   player.global_position=start_spawn;player.velocity=Vector3.ZERO;await ticks(20)
  player.facing_follows_camera=false;player.request_jump();await ticks(10)
  expect(not player.is_on_floor() and player.global_position.y>world.definition.surface_height()+.5,"jump works "+entry.id)
  await ticks(65)
  expect(fishing.cast(),"valid shore cast "+entry.id);fishing.cancel()
  # Surface buoyancy and boat mode are exercised against each authored world.
  var rng:=RandomNumberGenerator.new();rng.seed=420
  var deep:=Vector3.ZERO
  for attempt in 200:
   deep=world.definition.spawn_position(rng,Vector2(1,2),-1)
   if world.definition.water_depth_at(Vector2(deep.x,deep.z))>2:break
  player.global_position=Vector3(deep.x,world.definition.surface_height()-player.swim_float_depth,deep.z);player.velocity=Vector3.ZERO;await ticks(25)
  expect(player.swimming,"swimming works "+entry.id)
  expect(absf(player.global_position.y-(world.definition.surface_height()-player.swim_float_depth))<.5,"stable water level "+entry.id)
  player.global_position=boat.global_position+Vector3(-3,0,0);player.velocity=Vector3.ZERO;await ticks(2)
  expect(boat.board(player),"board boat "+entry.id)
  boat.forward_speed=0;boat.drive_input=Vector2(0,-1);player.input_enabled=false
  var boat_start:=boat.global_position
  for i in 50:
   boat.drive_input=Vector2(0,-1);await physics_frame
  expect(boat.global_position.distance_to(boat_start)>.2,"boat travels "+entry.id)
  boat.start_fishing();await ticks(3)
  expect(boat.mode==FishingBoat.Mode.FISHING and player.can_fish(),"stand and fish on boat "+entry.id)
  # Per-map mission matching and reward idempotency, without fake live catches.
  var mission: MissionDefinition=panel.definitions[0]
  var state:=MissionProgress.defaults();state.started=true
  for i in 3:
   var record:={"map":entry.id,"species":String(pond.species[0].id),"weight":1.0,"depth":1.0,"catch_id":entry.id+str(i),"fish_key":entry.id+":"+str(i),"bait_id":"worm","bait_kind":"bait"}
   MissionProgress.apply_catch(state,record)
  expect(MissionProgress.completed(state,mission),"local mission progresses "+entry.id)
  for other in MissionCatalog.REGION_ITEMS:
   if other.map_id!=entry.id:expect(not MissionProgress.completed(state,other),"other region mission unaffected "+other.id)
  for local_mission in panel.definitions:
   var exercise:=MissionProgress.defaults();exercise.started=true
   for event_index in 25:
    var species: FishSpecies=pond.species[event_index%pond.species.size()]
    if not local_mission.species_id.is_empty():
     for option in pond.species:
      if String(option.id)==local_mission.species_id:species=option;break
    var depth: float=maxf(local_mission.depth_range.x,species.preferred_depth.x)
    var event:={"map":entry.id,"species":String(species.id),"weight":species.max_weight,"depth":depth,"catch_id":local_mission.id+str(event_index),"fish_key":local_mission.id+":"+str(event_index),"boss":local_mission.boss_only,"bait_id":local_mission.bait_id if not local_mission.bait_id.is_empty() else "minnow" if local_mission.bait_kind=="lure" else "worm","bait_kind":"lure" if local_mission.bait_kind=="lure" else "bait"}
    if local_mission.metric=="baits":event.bait_id=["worm","dough"][event_index%2]
    MissionProgress.apply_catch(exercise,event)
   expect(MissionProgress.completed(exercise,local_mission),"full mission criteria can complete "+local_mission.id)
  var old_state: Dictionary=profile.data.missions;profile.data.missions=state
  var coins: int=profile.data.coins
  expect(profile.claim_mission(mission.id),"claim earned mission reward "+entry.id)
  expect(profile.data.coins==coins+mission.reward_coins and not profile.claim_mission(mission.id),"reward paid only once "+entry.id)
  profile.data.missions=old_state
  var snap:=pond.snapshot();expect(pond.restore(snap),"population restores by local roster "+entry.id)
  expect(profile.store_pond(entry.id,snap),"population save is namespaced "+entry.id)
  var camera: Camera3D=game.get_node("CameraRig/Camera3D");game.get_node("CameraRig").set_process(false);game.get_node("CameraRig").set_physics_process(false)
  var spawn: Vector3=world.get_node("GameplayMarkers/Spawn").global_position
  camera.global_position=spawn+Vector3(14,13,20);camera.look_at(spawn+Vector3(10,0,-8));game.get_node("HUD").hide()
  for frame in 4:await process_frame
  await capture(entry.id)
  game.queue_free();await process_frame;await process_frame
 expect(all_species.size()==105,"100 encyclopedia entries plus five retained legacy species are playable")
 expect(profile.data.ponds.size()==6,"six independent saved populations")
 var menu: Control=load("res://features/menu/main_menu.tscn").instantiate();root.add_child(menu);current_scene=menu;await ticks(3)
 menu.get_node("SafeArea/PlayCard/Content/ChooseRegion").pressed.emit();await ticks(3)
 expect(menu.get_node("RegionSelector").visible,"main menu opens map selector")
 expect(menu.get_node("RegionSelector/Panel/Content/Scroll/Cards").get_child_count()==6,"six selectable maps")
 await capture("menu_selector")
 root.size=Vector2i(720,400)
 for frame in 6:await process_frame
 var scroll: ScrollContainer=menu.get_node("RegionSelector/Panel/Content/Scroll")
 var before_selection: String=menu.selected_region
 var position: Vector2=scroll.get_global_rect().position+Vector2(scroll.size.x*.5,100)
 var touch:=InputEventScreenTouch.new();touch.index=51;touch.pressed=true;touch.position=position;root.push_input(touch,true);await process_frame
 var drag:=InputEventScreenDrag.new();drag.index=51;drag.position=position-Vector2(0,190);drag.relative=Vector2(0,-190);root.push_input(drag,true);await process_frame
 touch=InputEventScreenTouch.new();touch.index=51;touch.pressed=false;touch.position=position-Vector2(0,190);root.push_input(touch,true);await process_frame
 expect(scroll.scroll_vertical>0,"mobile map list scrolls from a swipe over a button")
 expect(menu.selected_region==before_selection,"swiping a map card does not select it")
 scroll.scroll_vertical=100000
 for frame in 3:await process_frame
 expect(scroll.get_global_rect().intersects(scroll.get_node("Cards/coral_coast").get_global_rect()),"last map reachable on narrow mobile layout")
 await capture("menu_mobile")
 root.size=Vector2i(1280,720)
 for frame in 4:await process_frame
 for entry in RegionCatalog.MAPS:
  menu.get_node("RegionSelector/Panel/Content/Scroll/Cards/"+entry.id).pressed.emit()
  expect(menu.selected_region==entry.id and menu.get_node("SafeArea/PlayCard/Content/Location").text==entry.name,"select map card "+entry.id)
 # The real play button must load the selected gameplay scene, then Back must return.
 menu.get_node("SafeArea/PlayCard/Content/PlayButton").pressed.emit()
 for frame in 30:await process_frame
 expect(current_scene!=null and current_scene.scene_file_path==RegionCatalog.MAPS[5].scene,"play button enters selected ocean map")
 if current_scene!=null and current_scene.has_method("_on_back_pressed"):
  current_scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip();current_scene._on_back_pressed()
  for frame in 10:await process_frame
  expect(current_scene.scene_file_path=="res://features/menu/main_menu.tscn","back returns to main menu")
  expect(current_scene.selected_region=="coral_coast","selected map remembered on return")
 print("REGIONS RESULT: ",checks," checks, ",failures," failures")
 quit(int(failures>0))
