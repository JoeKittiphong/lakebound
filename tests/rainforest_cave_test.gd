extends SceneTree
var checks:=0
var failures:=0
var output:=OS.get_environment("LAKEBOUND_QA_DIR")
var game: Node3D
var camera: Camera3D
var profile: AnglerProfile
func _initialize() -> void:call_deferred("run")
func expect(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1
 print("PASS: " if value else "FAIL: ",label)
func ticks(count: int) -> void:
 for i in count:await physics_frame
func capture(label: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
 root.size=Vector2i(1280,720)
 if output.is_empty():output=ProjectSettings.globalize_path("res://../exports/rainforest-lake/cave-qa")
 DirAccess.make_dir_recursive_absolute(output)
 root.get_node("FishCollection").recording_enabled=false
 profile=root.get_node("AnglerSave");profile.save_path=output.path_join("cave-profile.cfg");profile.data=profile.defaults()
 for item in ["heavy_rod","fast_reel","braid","large_box"]:profile.data.stock[item]=1
 profile.data.equipped.rod="heavy_rod";profile.data.equipped.reel="fast_reel";profile.data.equipped.line="braid";profile.data.equipped.box="large_box";profile.data.line_remaining=80.0
 game=load("res://features/regions/grand_river.tscn").instantiate();game.economy_enabled=true
 root.add_child(game);current_scene=game;game.get_node("FishingEffects").audio_enabled=false
 await ticks(90)
 game.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip()
 var definition: RainforestLakeDefinition=game.get_node("World").definition
 var player: AnglerPlayer=game.get_node("Player")
 var boat: FishingBoat=game.get_node("FishingBoat")
 boat.set_deployed(true) # Raw transport fixture; normal play deploys purchased equipment.
 var ecosystem: PondEcosystem=game.get_node("PondEcosystem")
 var fishing: FishingController=game.get_node("FishingController")
 var cave: Node3D=game.get_node("World/CliffFishingCave")
 expect(cave.get_node("VaultedStoneRoof").mesh.get_faces().size()/3>500,"saved vaulted cave roof has actual geometry")
 expect(cave.get_node("CaveWallCollision").get_child_count()>30,"authored cave walls have collision")
 var ids: Array=[]
 for fish in ecosystem.fish:ids.append([fish.persistent_key,fish.weight])
 var legacy:=ecosystem.snapshot()
 for record in legacy:record.erase("cave_habitat_seeded")
 expect(ecosystem.restore(legacy),"existing lake save gains cave habitat without reset")
 var retained:=ecosystem.fish.size()==ids.size();var residents:=0
 for i in ecosystem.fish.size():
  retained=retained and ecosystem.fish[i].persistent_key==ids[i][0] and ecosystem.fish[i].weight==ids[i][1]
  if definition.in_cave_area(Vector2(ecosystem.fish[i].position.x,ecosystem.fish[i].position.z)):residents+=1
 expect(retained,"all fish identities and weights survive cave migration")
 expect(residents>=14,"at least fourteen real resident fish inhabit the cave")
 expect(ecosystem.snapshot()[0].get("cave_habitat_seeded",false),"cave migration is persisted and not repeated")
 var depleted:=legacy.slice(0,56)
 expect(ecosystem.restore(depleted),"partly fished legacy lake can migrate")
 var depleted_residents:=0
 for fish in ecosystem.fish:
  if definition.in_cave_area(Vector2(fish.position.x,fish.position.z)):depleted_residents+=1
 expect(ecosystem.fish.size()==56 and depleted_residents>=7,"depleted saves gain cave residents without adding or resetting fish")
 expect(ecosystem.restore(legacy),"restore full QA population after depleted-save coverage")
 var space:=game.get_world_3d().direct_space_state
 for x in [20.,40.,60.]:
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,3,-215),Vector3(x,40,-215)))
  expect(not hit.is_empty() and hit.position.y>10 and hit.position.y<23,"physical ceiling above fishing/boat headroom at "+str(x))
 for x in [32.,40.,48.]:
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,2,-145),Vector3(x,2,-215)))
  expect(hit.is_empty(),"clear boat entrance lane at "+str(x))
 var navigation_clear:=true
 for z in range(-145,-231,-2):navigation_clear=navigation_clear and definition.water_depth_at(Vector2(40,z))>1.5
 expect(navigation_clear,"continuous deep water connects lake and cave chamber")
 game.get_node("CameraRig").set_process(false)
 camera=Camera3D.new();camera.far=350;camera.fov=68;game.add_child(camera);camera.current=true
 camera.global_position=Vector3(8,8,-136);camera.look_at(Vector3(40,8,-191))
 game.get_node("HUD").hide()
 boat.global_position=Vector3(40,definition.water_height,-145);boat.rotation.y=0
 player.global_position=boat.global_position+Vector3(3,.2,0);player.velocity=Vector3.ZERO
 expect(boat.board(player),"board boat for cave approach")
 await capture("cave_entrance")
 player.facing_follows_camera=false
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2(0,-1)
 await ticks(540)
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2.ZERO
 print("CAVE_ENTRY_POSITION ",boat.global_position)
 expect(boat.global_position.z< -195 and boat.global_position.z> -237,"actual boat drives through mouth into cavern")
 expect(boat.can_stand_to_fish(),"standing fishing clearance aboard boat inside cave")
 boat.global_position=Vector3(19,definition.water_height,-215);boat.forward_speed=0;boat.velocity=Vector3.ZERO
 await ticks(8)
 var exit:=boat.find_shore_exit()
 print("CAVE_WEST_EXIT ",exit)
 expect(exit.is_finite() and definition.water_depth_at(Vector2(exit.x,exit.z))<=.01,"west mooring finds a dry landing")
 expect(boat.disembark(),"actual disembark onto cave bank")
 await ticks(45)
 expect(player.is_on_floor() and not player.swimming and player.can_fish(),"west cave bank supports grounded fishing stance")
 var bank_position:=player.global_position
 var rig: AnglerCameraRig=game.get_node("CameraRig")
 player.global_position=Vector3(12,definition.ground_height(Vector2(12,-233))+.08,-233);player.velocity=Vector3.ZERO
 await ticks(25)
 rig.global_position=player.global_position;rig.rotation.y=PI;rig.set_process(true)
 camera.current=false;rig.get_node("Camera3D").current=true
 await ticks(20)
 var actual_camera: Camera3D=rig.get_node("Camera3D")
 var probe:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.20;probe.shape=sphere;probe.transform=Transform3D(Basis.IDENTITY,actual_camera.global_position);probe.exclude=[player.get_rid(),boat.get_rid()]
 expect(space.intersect_shape(probe,1).is_empty() and actual_camera.global_position.distance_to(rig.global_position)<Vector3(0,4.1,7.2).length()-.1,"real gameplay camera avoids cave rear wall when looking out")
 await capture("cave_game_camera")
 rig.set_process(false);rig.rotation.y=0;camera.current=true
 player.global_position=bank_position;player.velocity=Vector3.ZERO
 await ticks(25)
 var start:=player.global_position
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2(0,1)
 await ticks(60)
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2.ZERO
 expect(player.global_position.z-start.z>2 and player.is_on_floor() and not player.swimming,"walk along dry cave fishing bank")
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2(0,-1)
 await ticks(60)
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2.ZERO
 await ticks(8)
 camera.global_position=Vector3(13,5,-232);camera.look_at(Vector3(42,4,-184))
 await capture("cave_fishing_ledge")
 game.set_process(false);player.set_physics_process(false);ecosystem.set_physics_process(false);fishing.set_physics_process(false)
 var chosen: FishState;var best:=INF
 for fish: FishState in ecosystem.fish:
  var distance:=Vector2(fish.position.x-player.global_position.x,fish.position.z-player.global_position.z).length()
  if definition.in_cave_area(Vector2(fish.position.x,fish.position.z)) and fish.weight<12 and fish.species.preferred_depth.x<definition.water_depth_at(Vector2(fish.position.x,fish.position.z))-.14 and distance>4 and distance<50 and distance<best:chosen=fish;best=distance
 expect(chosen!=null,"reachable natural cave fish for bank fishing")
 if chosen!=null:
  var bait: StringName=&"worm" if "worm" in chosen.species.bait_preferences else &"dough" if "dough" in chosen.species.bait_preferences else &"minnow"
  profile.equip(String(bait));fishing.refresh_equipment()
  var offset:=chosen.position-player.global_position
  fishing.aim_yaw=0;fishing.aim_offset=Vector3(offset.x,0,offset.z);fishing.selected_depth=clampf(chosen.position.y,chosen.species.preferred_depth.x,chosen.species.preferred_depth.y)
  expect(fishing.cast(),"actual cast from cave bank into resident habitat")
  for step in 1500:
   ecosystem.step(.15);fishing.advance(.15,player.global_position)
   if fishing.state==FishingController.State.BITE:break
  expect(fishing.state==FishingController.State.BITE,"natural bite inside cave")
  if fishing.state==FishingController.State.BITE:
   expect(fishing.strike(),"strike cave fish")
   for step in 18000:
    fishing.rod_input=Vector2(-fishing.lateral_direction,1 if fishing.tension<lerpf(fishing.yellow_start,fishing.red_start,.60) else -.72).limit_length(1)
    fishing.advance(1.0/60,player.global_position)
    if fishing.state!=FishingController.State.FIGHT:break
   expect(fishing.state==FishingController.State.RESULT,"fight and land fish on cave bank")
   if fishing.state==FishingController.State.RESULT:
    fishing.resolve_catch(true)
    expect(fishing.state==FishingController.State.READY,"keep cave catch and persist population")
 fishing.cancel();game.set_process(true);player.set_physics_process(true);ecosystem.set_physics_process(true);fishing.set_physics_process(true)
 await ticks(8)
 expect(boat.can_board(player),"returning to boat from same dry bank is within reach")
 expect(boat.board(player),"reboard from cave fishing bank")
 boat.global_position=Vector3(61,definition.water_height,-215);boat.forward_speed=0;boat.velocity=Vector3.ZERO
 await ticks(8)
 expect(boat.disembark(),"east cave bank also permits disembarking")
 await ticks(45)
 expect(player.is_on_floor() and player.can_fish() and not player.swimming,"east cave bank supports dry fishing")
 expect(boat.board(player),"reboard from east cave bank")
 boat.global_position=Vector3(40,definition.water_height,-213);boat.rotation.y=PI;boat.forward_speed=0
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2(0,-1)
 await ticks(600)
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2.ZERO
 expect(boat.global_position.z> -155,"actual boat exits cave back into lake")
 rig.global_position=player.global_position;rig.set_process(true)
 await ticks(12)
 expect(rig.get_node("Camera3D").position.distance_to(Vector3(0,4.1,7.2))<.05,"game camera restores normal distance outside cave")
 rig.set_process(false);camera.current=true
 camera.global_position=Vector3(40,6,-224);camera.look_at(Vector3(40,4,-168))
 Engine.max_fps=0
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var samples: Array[float]=[];var previous:=Time.get_ticks_usec();var until:=previous+2000000
 while Time.get_ticks_usec()<until:
  await process_frame
  var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
 samples.sort();var total:=0.0
 for value in samples:total+=value
 var report:={"checks":checks,"failures":failures,"device":RenderingServer.get_video_adapter_name(),"mean_ms":total/samples.size(),"p95_ms":samples[int(samples.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"mobile_tested":false}
 await capture("cave_interior")
 FileAccess.open(output.path_join("cave-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CAVE_RESULT ",JSON.stringify(report))
 game.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
