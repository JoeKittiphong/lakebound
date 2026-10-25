extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(960, 720)
 var scene: Node3D = load("res://actors/player/character_preview.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var player: AnglerPlayer = scene.get_node("Player")
 player.set_physics_process(false)
 var model: AnglerModel = player.character_model
 for i in 5:
  await process_frame
 for action in ["Idle_A", "Walk", "Fishing_Cast", "Fishing_Catch", "Fishing_Reel", "Greeting", "Jump_2", "Sprint", "Swim_Fwd", "Swim_Idle"]:
  model.animation_player.play(action)
  model.animation_player.seek(model.animation_player.get_animation(action).length * 0.35, true)
  model.animation_player.pause()
  model.rod_mesh.visible = action in ["Fishing_Cast", "Fishing_Reel", "Fishing_Reel", "Fishing_Catch", "Fishing_Catch"]
  for i in 4:
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR") + "/preview_" + action + ".png")
 print("CHARACTER PREVIEW RESULT: 10 actions rendered")
 scene.queue_free()
 await process_frame
 quit()
