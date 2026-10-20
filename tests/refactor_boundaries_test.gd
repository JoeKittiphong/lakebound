extends SceneTree

var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 if output.is_empty():
  output = "res://exports/qa/screenshots"
 DirAccess.make_dir_recursive_absolute(output)
 test_simulation()
 test_store()
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 var controller: FishingController = scene.get_node("FishingController")
 var player: AnglerPlayer = scene.get_node("Player")
 var camera: AnglerCameraRig = scene.get_node("CameraRig")
 var pond: Pond = scene.get_node("World")
 var ecosystem: PondEcosystem = scene.get_node("PondEcosystem")
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 scene.get_node("FishingEffects").audio_enabled = false
 player.move_speed = 7.25
 controller._change_state(controller.State.FIGHT)
 # No simulation step: this fixture has no hooked fish.
 controller.set_physics_process(false)
 await process_frame
 expect(is_equal_approx(player.move_speed, 7.25) and player.fighting, "session changes movement mode without overwriting Inspector speed")
 controller.reset_cast()
 expect(not player.fighting, "leaving fight restores walking mode")
 expect(pond.definition == ecosystem.definition, "world and simulation use the same pond definition")
 expect(pond.has_node("RiverWater") and pond.has_node("Jetty"), "pond contains authored visual and collision nodes before Play")
 expect(camera.has_node("Camera3D") and scene.get_node("FishingEffects").has_node("Bobber"), "camera and effects retain their editable children")
 var spare := FishingController.new()
 spare.tuning = controller.tuning
 controller.tuning = controller.tuning.duplicate()
 controller.tuning.reel_speed = 5.0
 expect(not is_equal_approx(spare.tuning.reel_speed, controller.tuning.reel_speed), "changing one controller tuning does not mutate shared defaults")
 spare.free()
 controller.tuning = controller.tuning.duplicate()
 controller.tuning.cast_duration = 1.2
 expect(controller.cast(), "cast starts with resource tuning")
 controller.advance(0.6, player.global_position)
 expect(controller.state == controller.State.CASTING and is_equal_approx(controller.cast_progress(), 0.5), "custom cast duration drives both state and presentation progress")
 controller.advance(0.6, player.global_position)
 expect(controller.state == controller.State.WAITING and ecosystem.bait_active, "bait enters water at the configured duration")
 controller.cancel()
 var panel: Control = hud.get_node("CollectionPanel")
 paused = true
 panel.open()
 panel.close()
 expect(paused, "closing a collection opened during an existing pause preserves that pause")
 paused = false
 camera.look_finger = 8
 panel.open()
 expect(paused and not camera.enabled and camera.look_finger == -1, "collection delegates pause and input ownership to the session")
 panel.close()
 expect(not paused and camera.enabled, "closing the modal restores active session input")
 panel.open()
 scene.free()
 expect(not paused, "removing a session with an open modal restores its previous pause state")
 await process_frame
 print("BOUNDARIES RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)

func test_simulation() -> void:
 var definition: FishSpecies = load("res://data/fish/tilapia.tres")
 var first := FishState.new()
 first.species = definition
 first.id = 5
 first.position = Vector3(2, 1, -15)
 first.weight = 1.2
 var second := FishState.new()
 second.species = definition
 second.id = first.id
 second.position = first.position
 second.weight = first.weight
 var a := FightSimulation.new()
 var b := FightSimulation.new()
 a.line_length = 14
 b.line_length = 14
 var tuning := FishingTuning.new()
 for index in 120:
  a.advance(1.0 / 60.0, Vector3.ZERO, first, Vector2(0.2, 0.5), tuning)
  b.advance(1.0 / 60.0, Vector3.ZERO, second, Vector2(0.2, 0.5), tuning)
 expect(first.position.is_equal_approx(second.position) and is_equal_approx(a.tension, b.tension), "numerical fight simulation is deterministic without any scene nodes")
 expect(first.stamina < 1.0 and is_finite(a.tension) and is_finite(a.line_length), "pure simulation advances fatigue and finite line state")
 expect(is_equal_approx(definition.min_weight, first.species.min_weight) and first.species == second.species, "fish share immutable species definitions while runtime records remain separate")

func test_store() -> void:
 var path := output + "/store-regression.cfg"
 var config := ConfigFile.new()
 config.set_value("meta", "version", 1)
 config.set_value("fish", "tilapia", {"count": 2, "total": 3.0, "best": 2.0, "smallest": 1.0, "last": 2.0})
 config.set_value("fish", "invalid", {"count": -1})
 expect(config.save(path) == OK, "legacy v1 fixture is written to isolated QA output")
 var loaded := CollectionStore.load_records(path)
 expect(loaded.error == OK and loaded.records.size() == 1 and loaded.records.tilapia.count == 2, "store accepts the legacy schema and rejects malformed entries")
 config.set_value("meta", "version", 99)
 config.save(path)
 var before := FileAccess.get_file_as_bytes(path)
 var service: Node = load("res://features/collection/fish_collection.gd").new()
 service.save_path = path
 service.load_records()
 expect(service.incompatible_save and not service.save_records(), "future save versions block replacement writes")
 expect(before == FileAccess.get_file_as_bytes(path), "incompatible save bytes survive a blocked save unchanged")
 service.free()
 var bad := CollectionStore.save_records(output + "/missing-store-folder/save.cfg", {})
 expect(bad != OK, "store reports an unavailable destination to its caller")
 DirAccess.remove_absolute(path)


