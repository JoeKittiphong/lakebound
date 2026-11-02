extends SceneTree
const Rhythm = preload("res://features/fishing/lure_rhythm.gd")
const DIRECTIONS = {"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP,"down":Vector2.DOWN,"pause":Vector2.ZERO}
var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
 else: print("PASS: " + message)
func frames(count: int=5) -> void:
 for frame in count: await process_frame
func touch(down: bool, point: Vector2) -> void:
 var event:=InputEventScreenTouch.new()
 event.index=1
 event.pressed=down
 event.position=point
 root.push_input(event,true)
func drag(point: Vector2) -> void:
 var event:=InputEventScreenDrag.new()
 event.index=1
 event.position=point
 root.push_input(event,true)
func capture(name: String) -> void:
 if output.is_empty() or DisplayServer.get_name()=="headless": return
 await frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
 for recipe in Rhythm.RECIPES:
  for delay in [0.001,0.25,30.0]:
   var rhythm:=Rhythm.new()
   rhythm.reset(recipe)
   for direction in rhythm.steps:
    rhythm.advance(delay,Vector2.ZERO,recipe)
    var result:Dictionary=rhythm.advance(delay,DIRECTIONS[direction],recipe)
    expect(result.accepted and not result.mistake,"%s accepts %s after %s seconds" % [recipe,direction,delay])
   expect(rhythm.progress()==1.0,"complete recipe fills meter")
 var rhythm:=Rhythm.new()
 rhythm.reset("frog")
 rhythm.advance(0.01,Vector2.LEFT,"frog")
 rhythm.advance(120.0,Vector2.LEFT,"frog")
 expect(rhythm.step==1,"holding stick cannot spam progress and has no timeout")
 rhythm.advance(0.01,Vector2.UP,"frog")
 expect(rhythm.progress()==0.0,"wrong direction clears meter and restarts formula")
 expect(Rhythm.RECIPES.frog.size()==3 and Rhythm.RECIPES.pencil.size()==6 and Rhythm.RECIPES.metal_jig.size()==7,"lures have 3, 6 and 7 direction recipes")
 var pond:=PondEcosystem.new()
 pond.species=[load("res://data/fish/snakehead.tres")]
 pond.population_limit=3
 root.add_child(pond)
 pond.set_physics_process(false)
 var point:Vector3=pond.fish[0].position
 point.y=0.4
 for fish in pond.fish:
  fish.position=point+Vector3(2,0,0)
  fish.caution=0
  fish.hunger=1
 pond.set_bait(point,&"lure",true)
 for tick in 30: pond.step(0.15)
 expect(pond.reserved_fish==null and pond.lure_followers>0,"fish visibly pursue but cannot bite with empty meter")
 expect("ตาม" in pond.lure_status(),"status reports real pursuing fish")
 pond.register_lure_action(1.0)
 for tick in 6: pond.step(0.15)
 expect(pond.reserved_fish!=null,"full meter guarantees bite without random failure")
 pond.set_bait(point,&"lure",true)
 pond.register_lure_action(0.5)
 expect(pond.lure_strike_chance>0 and pond.lure_strike_chance<1,"partial meter offers an early bite chance")
 var early_bites:=0
 for trial in 30:
  pond.set_bait(point,&"lure",true)
  for fish in pond.fish: fish.position=point
  pond.register_lure_action(0.5)
  for tick in 6: pond.step(0.15)
  if pond.reserved_fish!=null: early_bites+=1
 expect(early_bites>0 and early_bites<30,"partial meters sometimes bite before full")
 pond.set_bait(point,&"lure",true)
 pond.register_lure_action(1.0)
 for fish in pond.fish: fish.position=point+Vector3(4,0,0)
 pond.step(0.15)
 expect(pond.lure_interest==1.0,"progress survives while fish swim toward lure")
 pond.invalidate_lure_action()
 expect(pond.lure_interest==0.0,"wrong direction clears fish authorization")
 pond.set_bait(Vector3(999,0,999),&"lure",true)
 pond.step(0.15)
 expect("ยังไม่มีปลา" in pond.lure_status(),"no fish nearby has an explicit reason")
 pond.set_bait(point,&"dough",true)
 for fish in pond.fish: fish.position=point
 pond.step(0.15)
 expect("เปลี่ยนเหยื่อ" in pond.lure_status(),"incompatible bait suggests a different lure")
 pond.set_bait(Vector3(point.x,20,point.z),&"lure",true)
 for fish in pond.fish: fish.position=pond.bait_position
 pond.step(0.15)
 expect("ความลึก" in pond.lure_status(),"wrong depth explains why fish ignore lure")
 pond.queue_free()
 await frames()
 await test_player_loop()
 print("LURE PROGRESS: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)

func test_player_loop() -> void:
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults()
 profile.save_path=output.path_join("rhythm-profile.cfg") if not output.is_empty() else "res://../exports/qa-lure-rhythm/rhythm-profile.cfg"
 profile.incompatible=false
 profile.data.equipped.bait="frog"
 profile.data.stock.frog=2
 root.get_node("FishCollection").recording_enabled=false
 root.size=Vector2i(1280,720)
 var scene:Node3D=load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch").save_path=profile.save_path+".tutorial"
 root.add_child(scene)
 current_scene=scene
 await frames(10)
 scene.set_process(false)
 var controller:FishingController=scene.get_node("FishingController")
 var pond:PondEcosystem=scene.get_node("PondEcosystem")
 var hud:FishingHUD=scene.get_node("HUD/FishingHUD")
 var player:AnglerPlayer=scene.get_node("Player")
 controller.set_physics_process(false)
 pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 var point:=pond.constrain_to_water(player.global_position+Vector3(12,0.12,0))
 point.y=0.12
 controller.cast_position=point
 controller.line_length=20
 var predator:FishState
 for fish in pond.fish:
  fish.position=pond.constrain_to_water(point+Vector3(50,2,50))
  if fish.species.id==&"snakehead" and predator==null: predator=fish
 expect(predator!=null,"playable river has an existing predator for lure pursuit")
 if predator==null:
  scene.queue_free()
  await frames()
  return
 predator.position=point+Vector3(0.6,0,0)
 predator.caution=0
 predator.hunger=1
 pond.set_bait(point,&"lure",true)
 controller._change_state(controller.State.WAITING)
 controller.advance(0.02,player.global_position)
 pond.step(0.15)
 await frames()
 var tutorial:Control=hud.get_node("SafeArea/FirstCatch")
 tutorial._process(0)
 expect(not tutorial.get_node("Card").visible and hud.get_node("SafeArea/Status/Content/LureRhythm").is_visible_in_tree(),"new-player tutorial yields the announcement to sequence arrows")
 tutorial.active=false
 tutorial.hide()
 for resolution in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1024,768)]:
  root.size=resolution
  await frames()
  var status:Control=hud.get_node("SafeArea/Status")
  var safe:Control=hud.get_node("SafeArea")
  expect(safe.get_global_rect().encloses(status.get_global_rect()),"rhythm announcement fits safe region at %s" % resolution)
  expect(not status.get_global_rect().intersects(hud.rod_joystick.get_global_rect()),"sequence arrows do not cover the player's thumb at %s" % resolution)
  controller.lure_rhythm.reset("frog")
 var center := hud.rod_joystick.get_global_rect().get_center()
 for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.LEFT]:
  touch(true,center+direction*hud.rod_joystick.radius)
  controller.rod_input=hud.rod_direction()
  controller.advance(0.02,player.global_position)
  touch(false,center)
  controller.rod_input=Vector2.ZERO
  controller.advance(0.02,player.global_position)
 expect(controller.lure_rhythm.progress()==1.0 and pond.lure_interest==1.0,"native mobile joystick fills controller and fish interest together")
 await capture("progress_full")
 # Fish can leave after completion; a stale follower count must not bank a full meter.
 for fish in pond.fish: fish.position=controller.cast_position+Vector3(100,0,100)
 pond.lure_followers=1
 controller.rod_input=Vector2.ZERO
 controller.advance(0.02,player.global_position)
 expect(controller.lure_rhythm.progress()==0.0 and pond.lure_interest==0.0,"full meter resets when no actual fish remains in range")
 expect("ยังไม่มีปลา" in pond.lure_status(),"status also ignores stale follower counts")
 expect("ยังไม่มีปลา" in controller.lure_rhythm.feedback,"empty spot displays a visible retry warning")
 await capture("progress_no_fish_retry")
 for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.LEFT]:
  controller.rod_input=direction
  controller.advance(0.02,player.global_position)
  controller.rod_input=Vector2.ZERO
  controller.advance(0.02,player.global_position)
 expect(controller.lure_rhythm.progress()==0.0,"completing another formula at an empty spot resets again")
 predator.position=controller.cast_position+Vector3(0.15,0,0)
 for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.LEFT]:
  controller.rod_input=direction
  controller.advance(0.02,player.global_position)
  controller.rod_input=Vector2.ZERO
  controller.advance(0.02,player.global_position)
 expect(controller.lure_rhythm.progress()==1.0,"player can immediately play a fresh formula when fish return")
 predator.position=controller.cast_position+Vector3(0.15,0,0)
 for tick in 6: pond.step(0.15)
 expect(controller.state==controller.State.BITE,"full meter guarantees a real fish bite")
 scene.queue_free()
 await frames()
