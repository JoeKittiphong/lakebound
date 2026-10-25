extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(960, 720)
 var scene: Node3D = load("res://actors/player/character_preview.tscn").instantiate()
 root.add_child(scene)
 var player: AnglerPlayer = scene.get_node("Player")
 player.set_physics_process(false)
 var model := player.character_model
 await process_frame
 var count := 0
 for action in ["Idle_A", "Fishing_Cast", "Fishing_Catch", "Fishing_Reel", "Greeting", "Walk", "Sprint", "Jump_2", "Swim_Fwd", "Swim_Idle", "Driving", "Sitting_Idle"]:
  model.animation_player.play(action, 0)
  model.animation_player.advance(0)
  model.animation_player.seek(model.animation_player.get_animation(action).length * 0.35, true)
  model.animation_player.pause()
  model.rod_mesh.visible = action.begins_with("Fishing_")
  for i in 4:
   await process_frame
  if action == "Fishing_Reel":
   var hand := model.skeleton.global_transform * model.skeleton.get_bone_global_pose(model.skeleton.find_bone("hand_r"))
   var direction := (hand.basis.inverse() * Vector3(0, 0.7, -0.7)).normalized()
   var euler := Quaternion(Vector3.UP, direction).get_euler()
   print("GRIP DEGREES: ", Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)))
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("model_" + action + ".png"))
  count += 1
 print("FISHERMAN VISUAL RESULT: ", count, " poses rendered")
 scene.queue_free()
 await process_frame
 quit()
