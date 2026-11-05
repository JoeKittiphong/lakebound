extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ",message)
 if not ok: failures += 1

func frames(count := 4) -> void:
 for i in count: await physics_frame

func tap(button: Button) -> void:
 for down in [true,false]:
  var event := InputEventScreenTouch.new()
  event.index = 5; event.position = button.get_global_rect().get_center(); event.pressed = down
  root.push_input(event,true)
 await frames()

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join(label+".png"))

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var game = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(game); current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 game.pond.set_physics_process(false)
 game.fishing.set_physics_process(false)
 await frames(25)
 game.hud.get_node("SafeArea/FirstCatch")._skip()
 game.player.set_physics_process(false)
 var button: Button = game.hud.get_node("SafeArea/PerspectiveButton")
 expect(not game.camera_rig.first_person and not game.fishing_first_person,"default traversal is third person")
 await tap(button)
 expect(game.fishing_first_person and button.text == "1st" and not game.camera_rig.first_person,"touch chooses first person for the next cast without changing traversal")
 expect(game.player.character_model.get_node("Asset").visible,"character remains visible while walking with first-person preference")
 expect(game.fishing.cast(),"real controller accepts cast")
 expect(game.fishing.state == FishingController.State.CASTING and not game.camera_rig.first_person,"cast animation stays third person")
 await capture("casting-third-person")
 game.fishing.advance(game.fishing.tuning.cast_duration+.01,game.player.global_position)
 await frames()
 expect(game.fishing.state == FishingController.State.WAITING and game.camera_rig.first_person,"bait landing applies stored first-person preference")
 expect(root.get_camera_3d() == game.camera_rig.get_node("FishingCamera3D") and is_instance_valid(game.player.first_person_rod),"first-person camera and rod are active after cast")
 await capture("bait-deployed-first-person")
 await tap(button)
 expect(not game.camera_rig.first_person and not game.fishing_first_person,"touch can select third person while bait is deployed")
 await tap(button)
 expect(game.camera_rig.first_person,"touch switches back to first person while waiting")
 game.fishing.reset_cast()
 await frames()
 expect(not game.camera_rig.first_person and game.fishing_first_person and button.button_pressed,"retrieval restores third person while remembering first person")
 expect(game.player.character_model.get_node("Asset").visible and game.player.first_person_rod == null,"retrieval restores character and removes first-person equipment")
 await capture("retrieved-third-person")
 expect(game.fishing.cast(),"next real cast is accepted")
 game.fishing.advance(game.fishing.tuning.cast_duration+.01,game.player.global_position)
 await frames()
 expect(game.camera_rig.first_person,"next cast automatically reapplies remembered preference")
 for state in [FishingController.State.BITE,FishingController.State.FIGHT,FishingController.State.RESULT,FishingController.State.LOST,FishingController.State.READY]:
  game.fishing._change_state(state)
  await frames()
  expect(game.camera_rig.first_person == (state in [FishingController.State.BITE,FishingController.State.FIGHT]),"camera follows deployed state %d"%state)
  expect(game.fishing_first_person and button.button_pressed,"state change preserves chosen preference")
 await tap(button)
 expect(not game.fishing_first_person and not game.camera_rig.first_person,"third-person preference can be chosen between casts")
 game.fishing._change_state(FishingController.State.WAITING)
 await frames()
 expect(not game.camera_rig.first_person,"third-person preference stays third person after deployment")
 game.queue_free(); await frames(2)
 print("PERSPECTIVE CAST RESULT: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
