extends SceneTree
var checks:=0
var failures:=0
var output:=OS.get_environment("LAKEBOUND_QA_DIR")
var measurements: Array=[]
var traversal: Dictionary={}
var shore_report: Dictionary={}
var game: Node3D
var definition: RainforestLakeDefinition
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label)
func frames(n: int) -> void:
 for i in n:await process_frame
func ticks(n: int) -> void:
 for i in n:await physics_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func ray(point: Vector3) -> Dictionary:
 return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*8,point-Vector3.UP*30))
func measure(label: String,position: Vector3,target: Vector3,camera: Camera3D,player: Node3D) -> void:
 position.y=maxf(definition.ground_height(Vector2(position.x,position.z))+.05,definition.water_height+.15)
 player.global_position=position
 camera.global_position=position+Vector3(0,5,9)
 camera.look_at(target)
 await create_timer(2).timeout
 var times: Array[float]=[]
 var begin:=Time.get_ticks_usec()
 var previous:=begin
 while Time.get_ticks_usec()-begin<2500000:
  await process_frame
  var now:=Time.get_ticks_usec()
  times.append((now-previous)/1000.0);previous=now
 times.sort()
 var mean:=0.0
 for ms in times:mean+=ms
 mean/=maxi(times.size(),1)
 var stream: LakeWorldStreamer=game.get_node("World/WorldStreaming")
 var result:={"site":label,"mean_frame_ms":mean,"fps_from_mean":1000/maxf(.01,mean),"p95_ms":times[mini(times.size()-1,int(times.size()*.95))],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"stream":stream.stats()}
 measurements.append(result)
 print("BENCHMARK ",JSON.stringify(result))
 expect(stream.loaded.size()<=stream.maximum_cells,"bounded resident cells: "+label)
 expect(stream.requests_failed==0,"stream requests complete: "+label)
 await capture(label)
func stress_streaming(camera: Camera3D,player: Node3D) -> void:
 var stream: LakeWorldStreamer=game.get_node("World/WorldStreaming")
 var route: Array[Vector3]=[Vector3(-450,0,215),Vector3(440,0,215),Vector3(440,0,-210),Vector3(-450,0,-210),Vector3(-133,0,0),Vector3(-324,0,143)]
 var samples: Array[float]=[]
 var first_keys: Array=stream.loaded.keys()
 var evicted:=false
 for destination in route:
  player.global_position=destination
  camera.global_position=destination+Vector3(0,6,9);camera.look_at(destination)
  var deadline:=Time.get_ticks_msec()+1800
  var previous:=Time.get_ticks_usec()
  while Time.get_ticks_msec()<deadline:
   await process_frame
   var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
   expect_bound(stream)
  for key in first_keys:
   if not stream.loaded.has(key):evicted=true
 samples.sort()
 var total:=0.0
 for value in samples:total+=value
 traversal={"samples":samples.size(),"mean_ms":total/samples.size(),"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"maximum_ms":samples[-1],"stream":stream.stats(),"resource_count":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
 expect(evicted,"streaming evicts cells after cross-map travel")
 expect(stream.requests_failed==0,"no failed resource loads across full map")
 expect(stream.peak_cells<=stream.maximum_cells,"resident cells bounded during travel")
 print("TRAVERSAL ",JSON.stringify(traversal))
func expect_bound(stream: LakeWorldStreamer) -> void:
 # Aggregate the invariant once, not thousands of per-frame test messages.
 if stream.loaded.size()>stream.maximum_cells:failures+=1;push_error("Streaming resident cap exceeded")
func exercise_traversal(player: AnglerPlayer,boat: FishingBoat) -> void:
 player.facing_follows_camera=false
 player.global_position=Vector3(-320,2,141);player.velocity=Vector3.ZERO
 await ticks(35)
 var walk_start:=player.global_position
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2(0,-1)
 await ticks(180)
 game.get_node("HUD/FishingHUD").move_joystick.direction=Vector2.ZERO
 expect(walk_start.z-player.global_position.z>8 and player.is_on_floor() and not player.swimming,"clear walking approach to jetty after shoreline dressing")
 player.input_enabled=false
 var wade_point:=Vector3.INF
 for z in range(70,125,3):
  for x in range(-370,-330,3):
   var p:=Vector2(x,z);var depth:=definition.water_depth_at(p)
   if depth<.25 or depth>.5:continue
   var hit:=ray(Vector3(x,1,z))
   if not hit.is_empty() and absf(hit.position.y-definition.ground_height(p))<.12:wade_point=hit.position+Vector3.UP*.05;break
  if wade_point.is_finite():break
 expect(wade_point.is_finite(),"unobstructed shallow wading location exists")
 if wade_point.is_finite():
  player.global_position=wade_point;player.velocity=Vector3.ZERO
  await ticks(40)
  expect(player.is_on_floor() and not player.swimming and definition.is_wading(player.global_position),"actual shallow shelf supports wading on terrain collision")
 player.global_position=Vector3(-290,definition.surface_height()-.8,85);player.velocity=Vector3.ZERO
 await ticks(40)
 expect(player.swimming,"deep lake enters swimming mode")
 player.global_position=Vector3(-324,2,143);player.velocity=Vector3.ZERO
 await ticks(45)
 expect(player.is_on_floor() and not player.swimming,"returning to bank exits swimming")
 var bridges: Node3D=game.get_node("World/ArrivalAndFootbridges")
 for i in 3:
  var bridge: Node3D=bridges.get_node("PoolChannelBridge%d"%i)
  player.global_position=bridge.global_position+Vector3(0,.2,0);player.velocity=Vector3.ZERO
  await ticks(30)
  expect(player.is_on_floor() and not player.swimming,"bridge %d supports a dry player"%i)
  # Drive along the actual channel underneath its bridge at the production boat speed.
  var start:=definition.channel_starts[i].lerp(definition.channel_ends[i],.35)
  var end:=definition.channel_starts[i].lerp(definition.channel_ends[i],.65)
  boat.global_position=Vector3(start.x,definition.surface_height(),start.y)
  boat.rotation.y=atan2(-(end.x-start.x),-(end.y-start.y));boat.forward_speed=boat.speed
  boat.mode=FishingBoat.Mode.DRIVING;boat.drive_input=Vector2(0,-1)
  boat.set_physics_process(false)
  for step in 180:
   await physics_frame
   boat._physics_process(1.0/60.0)
  print("BOAT_CHANNEL ",i," start=",start," position=",boat.global_position," speed=",boat.forward_speed," input=",boat.drive_input," collisions=",boat.get_slide_collision_count())
  for collision_index in boat.get_slide_collision_count():print("BOAT_CONTACT ",boat.get_slide_collision(collision_index).get_collider().get_path())
  expect(Vector2(boat.global_position.x,boat.global_position.z).distance_to(start)>17,"boat clears channel bridge %d"%i)
  boat.mode=FishingBoat.Mode.MOORED;boat.forward_speed=0
 boat.set_physics_process(true)
 player.character_model.driving=false
 player.input_enabled=true
func run() -> void:
 root.size=Vector2i(1280,720)
 if output.is_empty():output=ProjectSettings.globalize_path("res://../exports/rainforest-lake/qa")
 DirAccess.make_dir_recursive_absolute(output)
 root.get_node("FishCollection").recording_enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave");profile.save_path=output.path_join("profile.cfg");profile.data=profile.defaults()
 var packed: PackedScene=load("res://features/regions/grand_river.tscn")
 expect(packed!=null,"first map playable scene loads")
 game=packed.instantiate();game.economy_enabled=false
 root.add_child(game);current_scene=game
 definition=game.get_node("World").definition
 game.get_node("FishingEffects").audio_enabled=false
 await ticks(90)
 var tutorial=game.get_node("HUD/FishingHUD/SafeArea/FirstCatch");tutorial.active=false;tutorial.hide()
 expect(definition is RainforestLakeDefinition,"first map uses new lake definition")
 expect(definition.water_bounds.size==Vector2(1000,500),"1000 x 500 metre footprint")
 shore_report=game.get_node("World").get_meta("shoreline_metrics",{})
 expect(float(shore_report.get("area_multiplier",0))>3.0,"shallow shelf area increased at least threefold")
 var placements: Dictionary=game.get_node("World").get_meta("placement_counts",{})
 expect(int(placements.get("rock_flat",0))+int(placements.get("rock_boulder",0))>1000,"over one thousand shoreline rocks")
 expect(int(placements.get("old_lotus",0))>1000 and int(placements.get("emergent_lotus",0))>500,"large floating and emergent lotus populations")
 expect(definition.water_depth_at(Vector2(-314,111))>=1.8,"boat launch remains deep enough")
 var floating_batches:=game.get_node("World/WorldStreaming").find_children("old_lotus_Near","MultiMeshInstance3D",true,false)
 var floating_visible:=not floating_batches.is_empty()
 for batch in floating_batches:
  for transform in batch.authored_transforms:
   var bottom: float=batch.global_position.y+transform.origin.y+batch.authored_mesh.get_aabb().position.y*transform.basis.get_scale().y
   floating_visible=floating_visible and bottom>definition.water_height
 expect(floating_visible,"floating lotus leaves stay above the water surface")
 expect(definition.lake_islands.size()==3,"three islands")
 expect(int(shore_report.get("added_water_m2",0))>30000,"over 30,000 square metres of former bank become water")
 var pool_areas: Array[float]=[]
 for pool in definition.pools:pool_areas.append(pool.z*pool.w)
 pool_areas.sort()
 expect(pool_areas[-1]/pool_areas[0]>2.5,"satellite pool sizes differ substantially")
 for point in [Vector2(-423,191),Vector2(-205,206),Vector2(447,-206)]:
  expect(definition.previous_water_distance(point)>0 and definition.water_depth_at(point)>.1,"former empty bank becomes an irregular inlet at "+str(point))
 var cliff_body: StaticBody3D=game.get_node("World/NorthernCliffWall/CliffCollision")
 expect(cliff_body.get_child_count()>150,"continuous authored cliff wall has physical rock collision")
 for index in [20,60,100]:
  var shape: CollisionShape3D=cliff_body.get_child(index)
  var query:=PhysicsRayQueryParameters3D.create(shape.global_position+Vector3.UP*60,shape.global_position-Vector3.UP*60)
  var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
  expect(not hit.is_empty() and hit.position.y>definition.water_height+8,"solid elevated cliff section "+str(index))
 expect(definition.pools.size()==3,"three satellite pools")
 for i in definition.lake_islands.size():
  var island: Vector4=definition.lake_islands[i]
  expect(definition.ground_height(Vector2(island.x,island.y))>definition.water_height,"dry island "+str(i))
 for i in definition.pools.size():
  var pool: Vector4=definition.pools[i]
  expect(definition.can_swim_at(Vector3(pool.x,0,pool.y)),"pool water "+str(i))
  var connected:=true
  for j in 25:
   var p:=definition.channel_starts[i].lerp(definition.channel_ends[i],j/24.0)
   connected=connected and definition.water_depth_at(p)>.4
  expect(connected,"continuous boat-depth connection "+str(i))
 var player: AnglerPlayer=game.get_node("Player")
 expect(player.is_on_floor() and not player.swimming,"arrival player grounded and dry")
 expect(player.can_fish(),"fishing available from land")
 await capture("playable_hud")
 for z in [131.,125.,118.,111.]:
  var hit:=ray(Vector3(-320,1,z))
  expect(not hit.is_empty() and hit.position.y>.5,"continuous jetty floor at "+str(z))
 var controller: FishingController=game.get_node("FishingController")
 player.global_position=Vector3(-320,1.05,116);player.velocity=Vector3.ZERO
 await ticks(25)
 controller.aim_yaw=0
 expect(controller.cast(),"actual cast from new jetty into lake")
 controller.cancel()
 var boat: FishingBoat=game.get_node("FishingBoat")
 player.global_position=Vector3(-318,.95,113)
 expect(boat.board(player),"board fishing boat from jetty")
 expect(player.boat_driving(),"boat driving mode")
 boat.forward_speed=0;boat.mode=FishingBoat.Mode.MOORED;boat.passenger=null;player.boat=null;player.collision_layer=1;player.collision_mask=1
 await exercise_traversal(player,boat)
 if OS.get_environment("LAKEBOUND_TRAVERSAL_ONLY")=="1":
  game.queue_free();await frames(3);quit(1 if failures else 0);return
 var ecosystem: PondEcosystem=game.get_node("PondEcosystem")
 expect(ecosystem.fish.size()==ecosystem.population_limit,"configured expanded population exists before casting")
 var saved:=ecosystem.snapshot()
 expect(saved[0].get("habitat_revision")=="rainforest_lake_v1","layout revision stored with fish")
 expect(ecosystem.restore(saved),"new lake population round-trips")
 var identities: Array=[]
 for f in ecosystem.fish:identities.append(f.persistent_key)
 for entry in saved:entry.erase("habitat_revision")
 expect(ecosystem.restore(saved),"legacy river population migrates without reset")
 for i in ecosystem.fish.size():expect(ecosystem.fish[i].persistent_key==identities[i],"fish identity retained %d"%i)
 var material: BaseMaterial3D=load("res://world/rainforest_lake/vegetation_material.tres")
 expect(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,"foliage uses alpha scissor")
 expect(material.alpha_antialiasing_mode==0,"no alpha blend or hash overdraw mode")
 var far_root: Node3D=game.get_node("World/DistantForestLOD")
 var batches:=far_root.find_children("*","MultiMeshInstance3D",true,false)
 expect(batches.size()>100,"forest batches authored in stopped editor scene")
 var sample: MultiMeshInstance3D=batches[0]
 expect(not sample.authored_transforms.is_empty() and sample.authored_transforms[0]!=Transform3D.IDENTITY,"CPU-authored instance placement survives serialization")
 if DisplayServer.get_name()!="headless":expect(sample.multimesh.get_instance_transform(0)==sample.authored_transforms[0],"GPU placement equals saved editor data")
 for type in ["tree_a","tree_b"]:
  var tri: Array[int]=[]
  for suffix in ["","_mid","_far"]:
   var mesh: ArrayMesh=load("res://world/rainforest_lake/meshes/"+type+suffix+".res")
   tri.append(mesh.get_faces().size()/3)
  expect(tri[0]>tri[1] and tri[1]>tri[2],"authored decreasing LOD geometry: "+type+str(tri))
 game.get_node("CameraRig").set_process(false)
 player.set_physics_process(false)
 var camera:=Camera3D.new();camera.far=700;camera.fov=65;game.add_child(camera);camera.current=true
 game.get_node("HUD").visible=false
 # Free-run benchmarks: cap removed only in this QA process; runtime mobile target remains 30.
 Engine.max_fps=0
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 await measure("arrival",Vector3(-324,2,143),Vector3(-290,0,70),camera,player)
 await measure("island",Vector3(-133,3,0),Vector3(-70,0,40),camera,player)
 await measure("northwest_pool",Vector3(-450,3,-146),Vector3(-411,0,-177),camera,player)
 await measure("northeast_pool",Vector3(448,3,-125),Vector3(403,0,-160),camera,player)
 await measure("marsh_pool",Vector3(460,3,215),Vector3(410,0,176),camera,player)
 # Close inspection of the planted bank, after its authored detail cells have loaded.
 camera.global_position=Vector3(451,3.1,208);camera.look_at(Vector3(425,-.18,185))
 await frames(20);await capture("shore_detail")
 await measure("north_ridge",Vector3(150,5,-160),Vector3(150,14,-210),camera,player)
 await stress_streaming(camera,player)
 # Whole layout capture uses terrain and far forest, not a fake concept background.
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=1040;camera.far=1500;camera.global_position=Vector3(0,850,0);camera.rotation_degrees=Vector3(-90,0,0)
 game.get_node("World/RainforestAtmosphere").environment.fog_enabled=false
 game.get_node("World/RainforestAtmosphere").environment.background_mode=Environment.BG_COLOR
 game.get_node("World/RainforestAtmosphere").environment.background_color=Color(.04,.065,.065)
 for batch in batches:batch.visibility_range_begin=0;batch.visibility_range_end=0
 await frames(20);await capture("lake_overview")
 var result:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"measurements":measurements,"traversal":traversal,"shoreline":shore_report,"mobile_device_tested":false}
 var file:=FileAccess.open(output.path_join("test-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
 print("RAINFOREST_LAKE_RESULT ",checks," checks, ",failures," failures")
 game.queue_free();await frames(3);quit(1 if failures else 0)
