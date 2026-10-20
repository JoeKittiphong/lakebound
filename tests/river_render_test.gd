extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 root.size = Vector2i(1600, 1000)
 var scene = load("res://world/river/river_overview.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 for frame in 25:
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/qa-river/river-overview.png")
 print("RIVER OVERVIEW RENDERED")
 scene.queue_free()
 for frame in 3:
  await process_frame
 var game = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.get_node("FishCollection").recording_enabled = false
 root.add_child(game)
 current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 for frame in 30:
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://exports/qa-river/river-gameplay.png")
 var camera: Node3D = game.get_node("CameraRig")
 camera.enabled = false
 camera.set_process(false)
 game.set_process(false)
 var player: Node3D = game.get_node("Player")
 player.set_physics_process(false)
 var definition: RiverDefinition = game.get_node("World").definition
 for shot in ["bridge", "ford"]:
  var z := -116.0 if shot == "bridge" else 108.0
  player.position = Vector3(definition.center_at(z), 1.56 if shot == "bridge" else -0.52, z)
  camera.position = player.position
  camera.rotation = Vector3(deg_to_rad(-4), PI if shot == "bridge" else 0.0, 0)
  for frame in 15:
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-river/river-" + shot + ".png")
 print("RENDER COST: triangles=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
 game.queue_free()
 for frame in 3:
  await process_frame
 quit()


