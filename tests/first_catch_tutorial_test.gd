extends SceneTree

var failures := 0

func expect(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
 else:
  print("PASS: ", message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var collection := root.get_node("FishCollection")
 collection.records.clear()
 collection.recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.set_process(false)
 var fishing: FishingController = scene.get_node("FishingController")
 fishing.set_physics_process(false)
 var tutorial = scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch")
 tutorial.save_path = "user://tutorial_test.cfg"
 if DisplayServer.get_name() != "headless":
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../exports/tutorial-qa/tutorial-1280.png")
  root.size = Vector2i(1600, 720)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../exports/tutorial-qa/tutorial-1600.png")
 expect(tutorial.active, "Fresh player receives tutorial")
 fishing.player.global_position = tutorial.destination
 tutorial._process(0.0)
 expect(tutorial.arrived, "Walking to waypoint advances arrival")
 fishing.state = FishingController.State.WAITING
 tutorial._process(0.0)
 expect(tutorial.get_node("Card/Content/Title").text.begins_with("3/5"), "Casting advances to waiting instruction")
 fishing.state = FishingController.State.BITE
 tutorial._process(0.0)
 expect("I" in tutorial.get_node("Card/Content/Instruction").text, "Bite explains strike input")
 fishing.state = FishingController.State.FIGHT
 fishing.tension = 1.0
 tutorial._process(0.0)
 expect("K" in tutorial.get_node("Card/Content/Instruction").text, "High tension teaches payout")
 fishing.state = FishingController.State.LOST
 tutorial._process(0.0)
 expect(not tutorial.completed and tutorial.visible, "Loss keeps tutorial active for retry")
 tutorial._on_landed(null)
 var saved := ConfigFile.new()
 expect(saved.load(tutorial.save_path) == OK and saved.get_value("tutorial", "completed", false), "Landing persists completion")
 fishing.state = FishingController.State.RESULT
 tutorial._process(0.0)
 expect(not tutorial.visible, "Tutorial does not cover catch result")
 tutorial.bind(fishing, scene.get_node("HUD/FishingHUD"))
 expect(not tutorial.active, "Returning player does not repeat tutorial")
 DirAccess.remove_absolute(tutorial.save_path)
 scene.queue_free()
 await process_frame
 quit(1 if failures else 0)
