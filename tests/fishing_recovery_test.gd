extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 # A maximum-size fresh fish, strongest surge, weak line, stretched line and
 # end of spool must all still permit an intentional red → yellow recovery.
 for species in FishCatalog.SPECIES:
  for at_end in [false, true]:
   var fish := FishState.new()
   fish.species = species
   fish.weight = species.max_weight
   fish.id = 19
   fish.stamina = 1.0
   fish.position = Vector3(0, 1, -20 if at_end else -15)
   var fight := FightSimulation.new()
   fight.begin(fish)
   fight._surge_remaining = 1.05
   fight._surge_strength = 2.7
   fight.line_strength = 3.0
   fight.line_length = 20.0 if at_end else 12.0
   fight.tension = 1.0
   var tuning := FishingTuning.new()
   tuning.spool_capacity = 20.0 if at_end else 65.0
   var recovered := false
   var red_seconds := 0.0
   for tick in 75:
    fight.advance(1.0 / 60.0, Vector3.ZERO, fish, Vector2(0, -1), tuning)
    if fight.tension >= fight.red_start:
     red_seconds += 1.0 / 60.0
    elif fight.tension >= fight.yellow_start:
     recovered = true
     break
   expect(recovered and red_seconds < tuning.break_grace, "%s full payout recovers through yellow before break, end=%s" % [species.id, at_end])
 # Feedback-guided control must bring fish in, not merely pass through yellow.
 for species in FishCatalog.SPECIES:
  var fish := FishState.new()
  fish.species = species
  fish.weight = species.max_weight
  fish.id = 29
  fish.position = Vector3(0, 1, -18)
  var fight := FightSimulation.new()
  fight.line_length = 18.3
  fight.update_zones(fish)
  fight.tension = (fight.yellow_start + fight.red_start) * 0.5
  var red_time := 0.0
  var slack_time := 0.0
  var landed := false
  for tick in 7200:
   var command := 0.45 if fight.tension < lerpf(fight.yellow_start, fight.red_start, 0.55) else -0.65
   fight.advance(1.0 / 60.0, Vector3.ZERO, fish, Vector2(0, command), FishingTuning.new())
   red_time = red_time + 1.0 / 60.0 if fight.tension >= fight.red_start else maxf(0, red_time - 2.0 / 60.0)
   slack_time = slack_time + 1.0 / 60.0 if fight.tension < 0.12 else maxf(0, slack_time - 2.0 / 60.0)
   if red_time >= 1.4 or slack_time >= 2.5:
    break
   if fish.stamina < 0.4 and Vector2(fish.position.x, fish.position.z).length() <= 2.0:
    landed = true
    break
  expect(landed, "%s can be retrieved with visible tension feedback" % species.id)

 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 for frame in 30:
  await physics_frame
 scene.set_process(false)
 var controller: FishingController = scene.get_node("FishingController")
 controller.set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 hud.set_process(false)
 var profile := AnglerProfile.new()
 profile.data = profile.defaults()
 controller.profile = profile
 controller.refresh_equipment()
 profile.data.stock.worm = 0
 expect(not controller.cast() and "เหยื่อหมด" in controller.feedback, "empty bait blocks casting with a specific reason")
 hud._process(0.01)
 expect("เหยื่อหมด" in hud.get_node("SafeArea/CastReason").text, "empty bait reason remains visible on HUD")
 profile.data.stock.worm = 20
 profile.data.line_remaining = 0
 expect(not controller.cast() and "เอ็นหมด" in controller.feedback, "empty line has its own reason")
 profile.data.line_remaining = 65
 profile.data.pending = {"id": "test", "lure": "minnow", "cost": 1}
 expect(not controller.cast() and "รอกู้คืน" in controller.feedback, "pending lure recovery is distinguished from empty bait")
 profile.data.pending = {}
 for fraction in [0.0, 0.85, 1.0]:
  profile.data.catches = [] if fraction == 0.0 else [{"weight": profile.equipped("box").capacity * fraction}]
  hud._process(0.01)
  var info := hud.get_node("SafeArea/FishBox/Row/Info")
  expect(info.get_node("Count").text.contains("0 ตัว" if fraction == 0 else "1 ตัว"), "box count reflects retained fish at %.0f%%" % (fraction * 100))
  expect(is_equal_approx(info.get_node("Fill").value, fraction * 100), "box weight fill reflects %.0f%%" % (fraction * 100))
  if fraction >= 0.8:
   expect(("เต็มแล้ว" if fraction == 1.0 else "ใกล้เต็ม") in info.get_node("State").text, "box warns near/full %.0f%%" % (fraction * 100))
 profile.data.catches = []
 hud._process(0.01)
 expect(hud.get_node("SafeArea/FishBox/Row/Info/Fill").value == 0, "selling/removing stored fish clears the capacity indicator")
 controller.profile = null
 controller.haptics_enabled = false
 # Exercise the controller at the spool boundary too, where it previously
 # overwrote the recovered value with red after every simulation step.
 var edge_fish := FishState.new()
 edge_fish.species = load("res://data/fish/tilapia.tres")
 edge_fish.weight = 2
 edge_fish.id = 88
 edge_fish.position = controller.ecosystem.constrain_to_water(controller.get_aim_position())
 controller.active_fish = edge_fish
 controller.fight.begin(edge_fish)
 controller.fight.line_strength = 80
 var edge_distance := Vector2(edge_fish.position.x - controller.player.global_position.x, edge_fish.position.z - controller.player.global_position.z).length()
 controller.tuning.spool_capacity = edge_distance
 controller.line_length = edge_distance
 controller.tension = 1
 controller.overload_time = 0
 controller.slack_time = 0
 controller.profile = profile
 controller._change_state(FishingController.State.FIGHT)
 var edge_recovered := false
 for tick in 70:
  controller.rod_input = Vector2(0, -1)
  controller._fight_step(1.0 / 60.0, controller.player.global_position)
  if controller.tension >= controller.yellow_start and controller.tension < controller.red_start:
   edge_recovered = true
   break
 expect(edge_recovered and controller.state == FishingController.State.FIGHT, "controller with profile recovers yellow at spool limit instead of forcing red")
 controller.profile = null
 controller.reset_cast()
 controller.tuning.spool_capacity = 65
 for rating in [80.0, 0.4]:
  var fish := FishState.new()
  fish.species = load("res://data/fish/tilapia.tres")
  fish.id = 733
  fish.weight = 2.0
  fish.stamina = 1.0
  fish.position = controller.ecosystem.constrain_to_water(controller.get_aim_position())
  controller.active_fish = fish
  controller.fight.begin(fish)
  controller.fight.line_strength = rating
  controller.line_length = Vector2(fish.position.x - controller.player.global_position.x, fish.position.z - controller.player.global_position.z).length() + 0.3
  controller.tension = 1.0
  controller.overload_time = 0
  controller.slack_time = 0
  controller._change_state(FishingController.State.FIGHT)
  var red_frames := 0
  for tick in 600:
   controller.rod_input = Vector2(0, 1)
   controller._fight_step(1.0 / 60.0, controller.player.global_position)
   if controller.tension >= controller.red_start:
    red_frames += 1
   if controller.state != FishingController.State.FIGHT:
    break
  if rating == 80.0:
   expect(controller.state != FishingController.State.LOST and controller.overload_time == 0 and red_frames > 90, "80 kgf line survives a 2 kg fish even when cranking in red beyond break grace")
  else:
   expect(controller.state == FishingController.State.LOST and "สเปคเอ็น" in controller.feedback, "same fish breaks an overloaded 0.4 kgf line with a rating-specific explanation")
  controller.reset_cast()
 profile.free()
 scene.queue_free()
 await process_frame
 await process_frame
 print("FISHING RECOVERY RESULT: ", checks, " checks, ", failures, " failures")
 quit(1 if failures else 0)
