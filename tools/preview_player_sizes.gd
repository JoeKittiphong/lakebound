extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(1280, 720)
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 scene.get_node("FishingController").set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 for i in 25:
  await physics_frame
 scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip()
 var player: AnglerPlayer = scene.get_node("Player")
 player.set_physics_process(false)
 scene.set_process(false)
 var animation := player.character_model.animation_player
 animation.play("Idle_A", 0)
 animation.advance(0)
 animation.seek(0.5, true)
 animation.pause()
 # Compare against the pre-enlargement baseline even after the chosen size is applied.
 var original := Vector3.ONE * 1.18
 for percent in [100, 125, 140]:
  player.visual.scale = original * (float(percent) / 100.0)
  for i in 8:
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("player_size_%d.png" % percent))
 print("PLAYER SIZE PREVIEW RESULT: 3 sizes rendered; gameplay scene unchanged")
 scene.queue_free()
 await process_frame
 quit()
