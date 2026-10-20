extends SceneTree

var errors := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 if not ok:
  errors += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 if output.is_empty():
  output = "res://exports/qa-rod/screenshots"
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(1280, 720)
 var scene: Node3D = load("res://tests/legacy_gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.set_process(false)
 for path in ["Player", "FishingController", "PondEcosystem"]:
  scene.get_node(path).set_physics_process(false)
 scene.get_node("FishingEffects").set_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 var controller: FishingController = scene.get_node("FishingController")
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var previous_length := 0.0
 var previous_red := 1.0
 for sample in [["betta", 0.02], ["tilapia", 2.0], ["giant_catfish", 10.0], ["giant_catfish", 25.0]]:
  var fish := FishState.new()
  fish.species = load("res://data/fish/%s.tres" % sample[0])
  fish.weight = sample[1]
  controller.active_fish = fish
  controller._change_state(controller.State.FIGHT)
  controller.tension = 0.82
  for tick in 4:
   await process_frame
  var meter: Control = hud.meter
  expect(meter.size.y >= previous_length, "rod length grows with fish weight: " + str(fish.weight))
  expect(meter.red_start < previous_red, "red danger zone grows with species/size pressure: " + str(fish.weight))
  if fish.weight <= 2.0:
   expect(is_equal_approx(meter.size.y, 132.0), "small fish keep the original 132px bar")
  previous_length = meter.size.y
  previous_red = meter.red_start
  for resolution in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1024, 768)]:
   root.size = resolution
   for tick in 4:
    await process_frame
   var bar := meter.get_global_rect()
   var reel := hud.rod_joystick.get_global_rect()
   var guide := hud.rod_joystick.reel_guide_position()
   expect(absf(bar.end.y - (guide.y - 24.0)) < 1.0 and absf(bar.get_center().x - guide.x) < 1.0, "layout B stays on the projected reel axis at " + str(resolution))
   expect(root.get_visible_rect().encloses(bar) and not bar.intersects(hud.get_node("SafeArea/LineInfo").get_global_rect()), "rod stays inside viewport and clear of distance info")
  root.size = Vector2i(1280, 720)
  for tick in 4:
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output + "/rod-%s-%.2fkg.png" % [sample[0], fish.weight])
 # Same fish, same input: species pressure really affects the simulation.
 var easy := FishState.new()
 easy.species = load("res://data/fish/giant_catfish.tres").duplicate()
 easy.species.tension_pressure = 0.0
 easy.weight = 25.0
 easy.id = 1
 easy.position = Vector3(0, 2, -15)
 var hard := FishState.new()
 hard.species = load("res://data/fish/giant_catfish.tres")
 hard.weight = easy.weight
 hard.id = easy.id
 hard.position = easy.position
 var a := FightSimulation.new()
 var b := FightSimulation.new()
 a.line_length = 16.0
 b.line_length = 16.0
 a.advance(0.1, Vector3.ZERO, easy, Vector2.ZERO, controller.tuning)
 b.advance(0.1, Vector3.ZERO, hard, Vector2.ZERO, controller.tuning)
 expect(b.tension > a.tension, "higher species pressure increases actual tension, not just red coloring")
 scene.queue_free()
 await process_frame
 print("ROD TENSION RESULT: ", errors, " failures")
 quit(errors)
