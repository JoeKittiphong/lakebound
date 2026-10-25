extends SceneTree

func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.size = Vector2i(1280, 720)
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 var controller: FishingController = scene.get_node("FishingController")
 var rig: AnglerCameraRig = scene.get_node("CameraRig")
 var player: AnglerPlayer = scene.get_node("Player")
 controller.set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 for i in 10:
  await process_frame
 rig.rotate_view(Vector2(0, -100000))
 for i in 4:
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR") + "/camera_pitch_limit.png")
 rig.rotation.x = 0
 var fish := FishState.new()
 fish.species = load("res://data/fish/giant_catfish.tres")
 fish.weight = 25
 fish.id = 991
 fish.position = player.global_position + Vector3(12, 1, 0)
 controller.active_fish = fish
 controller.line_length = 15
 controller._change_state(controller.State.FIGHT)
 controller.tension = (controller.yellow_start + controller.red_start) * 0.5
 for size in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1024, 768)]:
  root.size = size
  for i in 5:
   await process_frame
  var meter: Control = scene.get_node("HUD/FishingHUD").meter
  var yellow_pixels: float = (meter.size.y - 6.0) * (controller.red_start - controller.yellow_start)
  print("YELLOW BAND: ", size, " yellow px=",yellow_pixels)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR") + "/yellow_mobile_%dx%d.png" % [size.x, size.y])
 print("MOBILE FISHING VISUAL RESULT: camera and three HUD sizes captured")
 scene.queue_free()
 await process_frame
 quit()
