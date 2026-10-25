extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
 checks+=1;print("PASS: " if ok else "FAIL: ",label)
 if not ok:failures+=1
func ticks(n: int) -> void:
 for i in n:await physics_frame
func run() -> void:
 root.get_node("FishCollection").recording_enabled=false
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.save_path="res://exports/qa-fish-models/region_fishing_profile.cfg";profile.data=profile.defaults();profile.incompatible=false;profile.save_error=""
 profile.data.stock.heavy_rod=1;profile.data.stock.fast_reel=1;profile.data.stock.braid=1;profile.data.stock.large_box=1
 profile.data.equipped.rod="heavy_rod";profile.data.equipped.reel="fast_reel";profile.data.equipped.line="braid";profile.data.equipped.box="large_box";profile.data.line_remaining=80.0
 for entry in RegionCatalog.MAPS:
  var game: Node3D=load(entry.scene).instantiate();game.economy_enabled=true;root.add_child(game);current_scene=game;game.get_node("FishingEffects").audio_enabled=false
  await ticks(30);game.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip();await ticks(3)
  game.set_process(false)
  var world: Pond=game.get_node("World");var player: AnglerPlayer=game.get_node("Player");var pond: PondEcosystem=game.get_node("PondEcosystem");var fishing: FishingController=game.get_node("FishingController")
  pond.set_physics_process(false);fishing.set_physics_process(false)
  var dock: Node3D=world.get_node("Jetty")
  player.global_position=dock.to_global(Vector3(0,.10,8.2));player.velocity=Vector3.ZERO;await ticks(20);player.set_physics_process(false)
  expect(player.is_on_floor() and player.can_fish(),"dock provides fishing stance "+entry.id)
  var chosen: FishState
  var best:=INF
  for fish: FishState in pond.fish:
   var distance:=Vector2(fish.position.x-player.global_position.x,fish.position.z-player.global_position.z).length()
   var available:=world.definition.water_depth_at(Vector2(fish.position.x,fish.position.z))
   if fish.weight<12 and fish.species.preferred_depth.x<available-.14 and distance>4.0 and distance<55 and distance<best:
    chosen=fish;best=distance
  expect(chosen!=null,"reachable pre-existing fish "+entry.id)
  if chosen!=null:
   var bait: StringName=&"worm" if "worm" in chosen.species.bait_preferences else &"dough" if "dough" in chosen.species.bait_preferences else &"minnow"
   expect(profile.equip(String(bait)),"equip matching bait "+entry.id)
   fishing.refresh_equipment()
   var offset:=chosen.position-player.global_position
   fishing.aim_yaw=0;fishing.aim_offset=Vector3(offset.x,0,offset.z)
   fishing.selected_depth=clampf(chosen.position.y,chosen.species.preferred_depth.x,chosen.species.preferred_depth.y)
   expect(fishing.cast(),"cast to inhabited water "+entry.id)
   for tick in 1500:
    pond.step(.15);fishing.advance(.15,player.global_position)
    if fishing.state==FishingController.State.BITE:break
   expect(fishing.state==FishingController.State.BITE,"natural resident bite "+entry.id+" species="+String(chosen.species.id)+" state="+str(fishing.state))
   if fishing.state==FishingController.State.BITE:
    expect(fishing.strike(),"strike fish "+entry.id)
    for frame in 18000:
     fishing.rod_input=Vector2(-fishing.lateral_direction,1.0 if fishing.tension<lerpf(fishing.yellow_start,fishing.red_start,.60) else -.72).limit_length(1)
     fishing.advance(1.0/60,player.global_position)
     if fishing.state!=FishingController.State.FIGHT:break
    expect(fishing.state==FishingController.State.RESULT,"fight and land resident "+entry.id+" state="+str(fishing.state))
    if fishing.state==FishingController.State.RESULT:
     expect(fishing.catch_record.map==entry.id,"catch event identifies map "+entry.id)
     var landed_id: int=fishing.active_fish.id
     fishing.resolve_catch(true)
     expect(fishing.state==FishingController.State.READY,"keep catch and resume "+entry.id)
     var persisted: Array=profile.data.ponds[entry.id]
     var retained:=false
     for fish in persisted:
      if fish.id==landed_id:retained=true
     expect(not retained,"kept fish removed only from correct saved population "+entry.id)
  game.queue_free();await process_frame;await process_frame
 print("REGION FISHING RESULT: ",checks," checks, ",failures," failures")
 quit(int(failures>0))
