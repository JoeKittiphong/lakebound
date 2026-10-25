extends SceneTree

var failures := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func ticks(count: int) -> void:
 for i in count:
  await physics_frame

func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/character_" + name + ".png")

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 root.size = Vector2i(1280, 720)
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 var controller: FishingController = scene.get_node("FishingController")
 controller.set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 var player: AnglerPlayer = scene.get_node("Player")
 var model: AnglerModel = player.character_model
 await ticks(15)
 expect(model.animation_player != null and model.skeleton.get_bone_count() >= 22, "imported skeleton and animation player exist")
 for name in ["Idle_A", "Walk", "Fishing_Cast", "Fishing_Reel", "Fishing_Reel", "Fishing_Catch", "Fishing_Catch", "Greeting", "Idle_A"]:
  expect(model.animation_player.has_animation(name), "required action imported: " + name)
 var body := model.skeleton.get_child(0) as MeshInstance3D
 expect(body != null and body.skin != null, "character is skinned to the imported rig")
 if body != null:
  var count := 0
  for i in body.mesh.get_surface_count():
   count += body.mesh.surface_get_array_index_len(i) / 3
  expect(count == 4873, "game imports the new 4873-triangle rigged fisherman")
  var material := body.get_active_material(0) as StandardMaterial3D
  expect(material != null and material.albedo_texture != null and material.albedo_texture.get_width() > 0, "Mesh2Motion color atlas is bound in the game")
 expect(model.current_action == &"Idle_A", "ready state plays idle")
 await capture("ready")
 var start := player.global_position
 Input.action_press("move_forward")
 await ticks(25)
 expect(model.current_action == &"Walk" and player.global_position.distance_to(start) > 0.5, "movement input moves the player and plays the accepted walk")
 await capture("walk")
 Input.action_release("move_forward")
 player.global_position = start
 player.velocity = Vector3.ZERO
 await ticks(5)
 expect(model.current_action == &"Idle_A", "releasing movement returns to idle")
 expect(controller.cast(), "actual fishing controller accepts cast toward water")
 await ticks(24)
 expect(model.current_action == &"Fishing_Cast", "cast signal starts the character's cast action")
 expect(is_equal_approx(model.animation_player.speed_scale * controller.tuning.cast_duration, model.animation_player.get_animation("Fishing_Cast").length), "character cast duration matches bait flight duration")
 await capture("cast")
 controller.cancel()
 await ticks(3)
 expect(model.current_action == &"Idle_A", "cancelling a cast immediately clears the cast animation lock")
 controller.cast()
 await ticks(4)
 controller.advance(controller.tuning.cast_duration + 0.01, player.global_position)
 await ticks(5)
 expect(model.current_action == &"Fishing_Reel", "waiting with no reel input holds the rod quietly")
 expect(model.rod_mesh.visible, "animated fishing rod is visible while fishing")
 Input.action_press("reel_in")
 await ticks(5)
 expect(model.current_action == &"Fishing_Reel", "real reel input switches to the reeling action")
 await capture("reel")
 Input.action_release("reel_in")
 var fish: FishState = scene.get_node("PondEcosystem").fish[0]
 controller.active_fish = fish
 controller._change_state(controller.State.BITE)
 await ticks(3)
 expect(controller.strike(), "hook input enters an actual fight")
 await ticks(3)
 expect(model.current_action == &"Fishing_Catch", "bite-to-fight transition plays hook-set action")
 controller.tension = 0.6
 await ticks(25)
 expect(model.current_action == &"Fishing_Catch", "fight under load plays the pull action")
 await capture("pull")
 Input.action_press("move_back")
 await ticks(8)
 expect(model.current_action == &"Fishing_Catch" and model.locomotion_active, "moving while fighting keeps rod animation and adds the accepted leg walk")
 expect(model.locomotion_tree.get("parameters/Mix/blend_amount") == 1.0, "fishing locomotion layer enables filtered leg animation")
 var shin := model.skeleton.find_bone("calf_l")
 var before := model.skeleton.get_bone_pose_rotation(shin)
 var shin_motion := 0.0
 for step in 120:
  await physics_frame
  shin_motion = maxf(shin_motion, before.angle_to(model.skeleton.get_bone_pose_rotation(shin)))
 expect(shin_motion > 0.05, "accepted walk actually deforms the shin during a fight")
 Input.action_release("move_back")
 await ticks(3)
 expect(not model.locomotion_active, "stopping during a fight stops the locomotion layer")
 var marker: Node3D = scene.get_node("FishingEffects").rod_tip
 expect(marker.global_position.distance_to(model.rod_tip_position()) < 0.2, "fishing line starts at the animated rod tip")
 controller._change_state(controller.State.RESULT)
 await ticks(4)
 expect(model.current_action == &"Greeting" and not model.rod_mesh.visible, "landing a fish plays celebration without a loose rod")
 await capture("celebrate")
 controller._change_state(controller.State.LOST)
 await ticks(4)
 expect(model.current_action == &"Idle_A", "lost-fish state has an explicit action")
 controller.reset_cast()
 await ticks(5)
 expect(model.current_action == &"Idle_A", "reset after fishing restores locomotion idle")
 print("CHARACTER INTEGRATION RESULT: ", failures, " failures")
 scene.queue_free()
 await process_frame
 quit(failures)
