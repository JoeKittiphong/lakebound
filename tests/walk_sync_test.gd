extends SceneTree

var failures := 0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1
func ticks(count: int) -> void:
 for i in count:
  await physics_frame
func run() -> void:
 var scene: Node3D = load("res://actors/player/character_preview.tscn").instantiate()
 root.add_child(scene)
 var player: AnglerPlayer = scene.get_node("Player")
 player.facing_follows_camera = true
 var model: AnglerModel = player.character_model
 player.set_physics_process(false)
 var clip := model.animation_player.get_animation("Walk")
 model.animation_player.play("Walk", 0)
 model.animation_player.seek(clip.length * 0.05, true)
 var foot := model.skeleton.find_bone("foot_l")
 var first := model.skeleton.global_transform * model.skeleton.get_bone_global_pose(foot).origin
 model.animation_player.seek(clip.length * 0.50, true)
 var last := model.skeleton.global_transform * model.skeleton.get_bone_global_pose(foot).origin
 var foot_travel := absf(last.z - first.z)
 var ground_travel := 1.05 * 0.45
 print("STANCE: foot travel=", foot_travel, " ground travel=", ground_travel)
 expect(foot_travel > 0.15 and foot_travel < 1.5, "imported Walk has a nonzero, bounded foot swing")
 player.set_physics_process(true)
 for test in [[3.8, false, 1.0], [3.8, false, 0.4], [1.3, false, 1.0], [3.8, true, 1.0]]:
  player.global_position = Vector3.ZERO
  player.velocity = Vector3.ZERO
  player.move_speed = test[0]
  player.fighting = test[1]
  player.set_fishing_animation_state(FishingController.State.FIGHT if player.fighting else FishingController.State.READY, 0, 0.6)
  Input.action_press("move_forward", test[2])
  await ticks(20)
  var expected := player.actual_ground_speed * clip.length / model.walk_cycle_distance
  expect(is_equal_approx(model.walk_playback_rate, expected), "gait rate follows measured travel at speed %.2f, fight=%s, input=%.1f" % [player.actual_ground_speed, player.fighting, test[2]])
  if player.fighting:
   expect(is_equal_approx(model.locomotion_tree.get("parameters/LegSpeed/scale"), expected), "fishing leg layer uses the same distance-matched speed")
  else:
   expect(is_equal_approx(model.animation_player.speed_scale, expected), "regular walking uses the distance-matched playback rate")
  Input.action_release("move_forward")
  await ticks(3)
 player.fighting = false
 player.set_fishing_animation_state(FishingController.State.READY, 0, 0)
 player.global_position = Vector3.ZERO
 player.move_speed = 2.0
 var wall := StaticBody3D.new()
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(4, 3, 0.2)
 collision.shape = shape
 wall.add_child(collision)
 scene.add_child(wall)
 wall.position = Vector3(0, 1, -1)
 Input.action_press("move_forward")
 await ticks(70)
 expect(player.actual_ground_speed < 0.04 and model.current_action == &"Idle_A", "blocked movement stops the walk instead of marching against a wall")
 Input.action_release("move_forward")
 wall.queue_free()
 await ticks(3)
 player.global_position = Vector3.ZERO
 Input.action_press("move_back")
 await ticks(10)
 expect(model.current_action == &"Walk" and model._direction > 0, "backward stick turns the character and uses forward gait")
 Input.action_release("move_back")
 scene.queue_free()
 await process_frame
 print("WALK SYNC RESULT: ", failures, " failures")
 quit(failures)
