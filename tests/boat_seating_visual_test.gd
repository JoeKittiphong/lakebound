extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.size = Vector2i(1280, 720)
 var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 var boat: FishingBoat = scene.get_node("FishingBoat")
 var player: AnglerPlayer = scene.get_node("Player")
 for i in 10:
  await physics_frame
 player.global_position = boat.global_position + Vector3(0, 1, 1)
 assert(boat.board(player))
 var camera := Camera3D.new()
 scene.add_child(camera)
 camera.current = true
 camera.global_position = boat.to_global(Vector3(5.5, 3.1, 0.8))
 camera.look_at(boat.to_global(Vector3(0, 1.0, 0)))
 for moving in [false, true]:
  boat.forward_speed = 1.0 if moving else 0.0
  boat.set_physics_process(false)
  player.character_model.driving_speed = boat.forward_speed
  for i in 25:
   await physics_frame
  assert(player.global_position.distance_to(boat.driver_anchor.global_position) < 0.05)
  assert(player.character_model.current_action == (&"Driving" if moving else &"Sitting_Idle"))
  await RenderingServer.frame_post_draw
  var label := "moving" if moving else "idle"
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("boat_seating_" + label + ".png"))
 print("BOAT SEATING RESULT: forward seating offset and both seated actions")
 scene.queue_free()
 await process_frame
 quit(0)
