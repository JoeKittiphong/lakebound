extends SceneTree

var Gameplay: PackedScene
const F = preload("res://features/fishing/fishing_controller.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run_tests")

func expect(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func session(seed_value: int = 4207) -> Node:
 var scene := Gameplay.instantiate()
 root.add_child(scene)
 scene.set_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 # Keep the original bait/depth regression deterministic; the full catalog is
 # exercised separately by fish_models_test.gd.
 var legacy_species: Array[Resource] = [load("res://data/fish/tilapia.tres"), load("res://data/fish/snakehead.tres"), load("res://data/fish/catfish.tres")]
 scene.get_node("PondEcosystem").species = legacy_species
 scene.get_node("PondEcosystem").reset_population(seed_value)
 scene.get_node("FishingController").set_physics_process(false)
 scene.get_node("FishingController").haptics_enabled = false
 scene.get_node("Player").set_physics_process(false)
 scene.get_node("HUD/FishingHUD").set_process(false)
 scene.get_node("FishingEffects").set_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 return scene

func wait_for_bite(scene: Node, bait: StringName, depth: float) -> bool:
 var fishing := scene.get_node("FishingController")
 var pond := scene.get_node("PondEcosystem")
 fishing.selected_bait = bait
 fishing.selected_depth = depth
 fishing.cast()
 for tick in 600:
  pond.step(0.15)
  fishing.advance(0.15, scene.get_node("Player").position)
  if fishing.state == F.State.BITE:
   return true
 return false

func fight_with_feedback(scene: Node, delta: float = 1.0 / 60.0) -> bool:
 var fishing := scene.get_node("FishingController")
 var angler: Vector3 = scene.get_node("Player").position
 for tick in 7200:
  # Uses only visible tension and the direction inferred from the line.
  var vertical := 1.0 if fishing.tension < lerpf(fishing.yellow_start, fishing.red_start, 0.60) else -0.72
  fishing.rod_input = Vector2(-fishing.lateral_direction, vertical).limit_length(1.0)
  fishing.advance(delta, angler)
  if fishing.state == F.State.RESULT:
   print("LANDED: ", fishing.active_fish.species.id, " time ", snappedf(fishing.fight_time, 0.1), "s")
   return true
  if fishing.state == F.State.LOST:
   print("LOST: ", fishing.feedback)
   return false
 print("TIMEOUT: distance ", fishing.fish_distance, " length ", fishing.line_length, " tension ", fishing.tension, " stamina ", fishing.active_fish.stamina)
 return false

func run_tests() -> void:
 root.get_node("FishCollection").recording_enabled = false
 Gameplay = load("res://tests/legacy_gameplay.tscn")
 var scene := session()
 var pond := scene.get_node("PondEcosystem")
 expect(pond.fish.size() == 30, "population exists before casting")
 for point in [Vector3(0, 1, -5), Vector3(1, 1, 0), Vector3(-1, 1, -8), Vector3(200, 1, -200), Vector3(10, 1, 20)]:
  var bounded: Vector3 = pond.constrain_to_water(point)
  expect(bounded.x >= -85 and bounded.x <= 85 and bounded.z >= -95 and bounded.z <= 1.2 and (absf(bounded.x) >= 2.649 or bounded.z <= -9.19), "fish remains in water outside bank/dock: " + str(point))

 expect(pond.get_child_count() == 0, "background fish are data records, not thirty scene nodes")
 pond.set_bait(Vector3(200, 1.5, 200), &"worm")
 for tick in 120:
  pond.step(0.15)
 expect(pond.reserved_fish == null, "fish cannot detect bait outside its actual spatial radius")
 pond.set_bait(Vector3(0, 5.5, -17), &"lure")
 for tick in 180:
  pond.step(0.15)
 expect(pond.reserved_fish == null, "wrong depth and incompatible bait do not create a scripted bite")
 scene.free()

 var cases := [[&"dough", 1.5, &"tilapia"], [&"lure", 1.5, &"snakehead"], [&"worm", 4.5, &"catfish"]]
 for index in cases.size():
  scene = session(4207 + index)
  pond = scene.get_node("PondEcosystem")
  var fishing := scene.get_node("FishingController")
  var bite := wait_for_bite(scene, cases[index][0], cases[index][1])
  expect(bite, "natural approach/inspection produces a bite: " + String(cases[index][2]))
  if not bite:
   scene.free()
   continue
  expect(fishing.active_fish.species.id == cases[index][2], "bait/depth select the expected species")
  var record: RefCounted = fishing.active_fish
  var id: int = record.id
  expect(fishing.strike(), "strike transitions to a real fight")
  var landed := fight_with_feedback(scene)
  expect(landed, "feedback-based reeling can land " + String(record.species.id))
  if landed:
   expect(fishing.fish_distance < 7.1 and fishing.active_fish.position.z <= -9.19, "catch is within rod reach at wet pier edge, not on the deck")
   expect(record.stamina < 0.4, "catch requires fatigue, no fish HP bar")
   if index == 0:
    fishing.resolve_catch(false)
    expect(pond.fish.has(record) and record.id == id and pond.fish.size() == 30, "release returns the same fish identity without changing population")
    expect(record.caution > 0.9, "released fish is temporarily wary")
   else:
    fishing.resolve_catch(true)
    expect(not pond.fish.has(record) and pond.fish.size() == 29, "keeping the fish removes that individual from the pond")
    pond.restock_clock = 0.0
    pond.step(1.0)
    expect(pond.fish.size() == 29, "restocking is not immediate")
    pond.step(pond.restock_interval)
    expect(pond.fish.size() == 30 and not pond.fish.has(record), "timed population replacement creates a new individual")
  scene.free()

 scene = session()
 var fishing := scene.get_node("FishingController")
 expect(wait_for_bite(scene, &"dough", 1.5), "bite-window test setup")
 fishing.advance(6.0, scene.get_node("Player").position)
 expect(fishing.state == F.State.LOST and fishing.active_fish == null, "missing the strike loses the fish cleanly")
 scene.free()

 for release_line in [false, true]:
  scene = session()
  fishing = scene.get_node("FishingController")
  wait_for_bite(scene, &"lure", 1.5)
  fishing.strike()
  fishing.drag_strength = 1.0
  for tick in 3600:
   fishing.rod_input = Vector2(0, -1 if release_line else 1)
   fishing.advance(1.0 / 60.0, scene.get_node("Player").position)
   if fishing.state == F.State.LOST:
    break
  expect(fishing.state == F.State.LOST, "continuous " + ("release causes hook escape" if release_line else "forced reeling causes line failure"))
  expect(fishing.active_fish == null, "failed fight releases the reserved fish")
  scene.free()

 scene = session()
 fishing = scene.get_node("FishingController")
 fishing.cast()
 fishing.cancel()
 pond = scene.get_node("PondEcosystem")
 for tick in 100:
  pond.step(0.15)
 expect(fishing.state == F.State.READY and pond.reserved_fish == null and not pond.bait_active, "cancel removes bait and prevents delayed ghost bites")
 scene.free()
 # Vary population seed and frame rate; do not tune only to one fixed fish.
 for seed_value in [7, 19, 441]:
  for index in cases.size():
   scene = session(seed_value)
   fishing = scene.get_node("FishingController")
   var did_bite := wait_for_bite(scene, cases[index][0], cases[index][1])
   expect(did_bite, "species approach under population seed %d, case %d" % [seed_value, index])
   if did_bite:
    fishing.strike()
    expect(fight_with_feedback(scene, 1.0 / (30.0 if seed_value == 7 else 120.0)), "landing remains possible at varied frame rates/seed")
   scene.free()
 await process_frame
 await process_frame
 print("RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
