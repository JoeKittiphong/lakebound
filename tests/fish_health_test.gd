extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
func fish(weight: float = 1.0) -> FishState:
 var value := FishState.new()
 value.species=load("res://data/fish/tilapia.tres")
 value.id=17
 value.weight=weight
 value.position=Vector3(0,1,-15)
 return value
func frames(count: int = 3) -> void:
 for i in count: await process_frame
func run() -> void:
 var tuning := FishingTuning.new()
 var previous := 0.0
 for weight in [0.1,1.0,10.0,30.0,100.0]:
  var sim := FightSimulation.new()
  sim.begin(fish(weight),tuning)
  expect(sim.maximum_health > previous, "health increases with fish mass")
  previous=sim.maximum_health
 for zone in ["slack","green","yellow","red"]:
  var sim := FightSimulation.new()
  sim.begin(fish(),tuning)
  sim.update_zones(sim._fish)
  var start := sim.health
  sim.tension = 0.05 if zone=="slack" else (sim.yellow_start-0.01 if zone=="green" else (sim.red_start+0.05 if zone=="red" else sim.yellow_start))
  sim.apply_health_pressure(1.0,tuning)
  var expected: float=0.0 if zone in ["slack","green"] else (tuning.red_health_damage if zone=="red" else tuning.yellow_health_damage)
  expect(is_equal_approx(start-sim.health,expected), "health damage matches pressure zone: "+zone)
 var durations: Array[float]=[]
 for fps in [30,60,120]:
  var sim := FightSimulation.new()
  sim.begin(fish(),tuning)
  sim.tension=0.8
  for i in fps*3: sim.apply_health_pressure(1.0/fps,tuning)
  durations.append(sim.health)
 expect(absf(durations[0]-durations[2])<0.0001, "damage is frame-rate independent")
 var exhausted := FightSimulation.new()
 var tired := fish(20)
 exhausted.begin(tired,tuning)
 exhausted.tension=0.8
 exhausted.apply_health_pressure(1000,tuning)
 expect(exhausted.exhausted and exhausted.health==0, "health clamps at zero")
 exhausted.line_length=15
 exhausted.advance(0.5,Vector3.ZERO,tired,Vector2.ZERO,tuning)
 expect(exhausted.yellow_start==0 and exhausted.red_start==1 and not exhausted.surge_active and exhausted.line_load_kgf==0, "depleted fish enters a safe all-yellow phase")
 var position := tired.position
 exhausted.advance(1,Vector3.ZERO,tired,Vector2.ZERO,tuning)
 expect(Vector2(position.x,position.z).distance_to(Vector2(tired.position.x,tired.position.z))<0.0001, "exhausted fish waits for actual retrieve input")
 exhausted.advance(0.2,Vector3.ZERO,tired,Vector2.DOWN,tuning)
 expect(Vector2(tired.position.x,tired.position.z).length()<Vector2(position.x,position.z).length(), "reeling retrieves exhausted fish")
 root.get_node("FishCollection").recording_enabled=false
 var scene=load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled=false
 root.add_child(scene)
 current_scene=scene
 await frames(8)
 scene.set_process(false)
 scene.player.set_physics_process(false)
 scene.fishing.set_physics_process(false)
 scene.pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled=false
 scene.hud.get_node("SafeArea/FirstCatch").active=false
 scene.hud.get_node("SafeArea/FirstCatch").hide()
 var controller: FishingController=scene.fishing
 controller.active_fish=fish(2)
 controller.active_fish.position=scene.pond.constrain_to_water(scene.player.global_position+Vector3(12,0,0))
 controller.active_fish.position.y=1
 controller.fight.begin(controller.active_fish,tuning)
 controller.line_length=12
 controller._change_state(FishingController.State.FIGHT)
 await frames()
 var bar: Control=scene.hud.get_node("SafeArea/FishHealth")
 for resolution in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1024,768)]:
  root.size=resolution
  await frames()
  var safe: Control=scene.hud.get_node("SafeArea")
  previous=0
  for weight in [0.1,1.0,10.0,30.0,100.0]:
   controller.active_fish.weight=weight
   scene.hud._process(0)
   expect(bar.visible and safe.get_global_rect().encloses(bar.get_global_rect()), "health stays inside safe area")
   expect(absf(bar.get_global_rect().get_center().x-root.get_visible_rect().get_center().x)<0.1, "health stays at screen centre")
   expect(bar.size.x>=previous, "bar width grows monotonically")
   previous=bar.size.x
   if weight>=30: expect(absf(bar.size.x-safe.size.x)<0.1,"large fish spans full safe width")
  expect(not scene.hud.get_node("SafeArea/Status").visible, "health replaces waiting/formula announcement during fight")
 var safe_area: Control=scene.hud.get_node("SafeArea")
 safe_area.offset_left=110
 safe_area.offset_right=-32
 await frames()
 for weight in [0.1,5.0,100.0]:
  bar.update_health(weight,50,100)
  expect(absf(bar.get_global_rect().get_center().x-root.get_visible_rect().get_center().x)<0.1,"unequal phone insets preserve screen centre")
  expect(safe_area.get_global_rect().encloses(bar.get_global_rect()),"centred bar avoids phone cutout")
 safe_area.offset_left=32
 safe_area.offset_right=-32
 controller.fight.health=0
 controller.active_fish.stamina=0
 controller.fight.update_zones(controller.active_fish)
 scene.hud._process(0)
 expect(scene.hud.meter.exhausted, "actual meter draws all yellow after depletion")
 expect(bar.get_node("Track").value==0,"depleted health bar is visually empty")
 # Weak line must still fail before exhaustion; holding red is never a free win.
 controller.active_fish=fish(30)
 controller.active_fish.position=scene.pond.constrain_to_water(scene.player.global_position+Vector3(12,0,0))
 controller.fight.begin(controller.active_fish,tuning)
 controller.fight.line_strength=0.01
 controller.rod_input=Vector2.DOWN
 controller.overload_time=controller.tuning.break_grace-0.01
 controller._fight_step(0.03,scene.player.global_position)
 expect(controller.state==FishingController.State.LOST,"overloaded line still breaks while dealing damage")
 # Exercise actual landing conditions at the closest water boundary.
 controller.active_fish=fish(1)
 controller.active_fish.position=scene.pond.constrain_to_water(scene.player.global_position)
 controller.active_fish.position.y=0.08
 controller.fight.begin(controller.active_fish,tuning)
 controller.fight.line_strength=10000
 controller.line_length=2
 controller.overload_time=0
 controller.slack_time=0
 controller._change_state(FishingController.State.FIGHT)
 controller.rod_input=Vector2.ZERO
 controller._fight_step(0.01,scene.player.global_position)
 expect(controller.state==FishingController.State.FIGHT,"fish cannot be landed with health remaining")
 controller.fight.health=0
 controller.active_fish.stamina=0
 controller.rod_input=Vector2.ZERO
 controller._fight_step(0.5,scene.player.global_position)
 expect(controller.state==FishingController.State.FIGHT,"empty health alone does not auto-catch")
 controller.active_fish.position=scene.pond.constrain_to_water(scene.player.global_position)
 controller.rod_input=Vector2.DOWN
 controller._fight_step(0.01,scene.player.global_position)
 expect(controller.state==FishingController.State.RESULT,"exhausted fish can be reeled into landing reach")
 controller.reset_cast()
 await frames()
 expect(not bar.visible and not scene.hud.meter.exhausted,"reset clears both health and yellow-phase HUD")
 scene.queue_free()
 await process_frame
 print("FISH HEALTH: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)
