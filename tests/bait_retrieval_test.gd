extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://tests/legacy_gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.set_process(false)
 var controller: FishingController = scene.get_node("FishingController")
 var pond: PondEcosystem = scene.get_node("PondEcosystem")
 var player: AnglerPlayer = scene.get_node("Player")
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 player.set_physics_process(false)
 controller.set_physics_process(false)
 pond.set_physics_process(false)
 scene.get_node("FishingEffects").set_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 expect(not hud.has_node("SafeArea/CancelButton"), "retrieve button has been removed from the authored HUD")
 expect(controller.cast(), "cast begins normally")
 controller.advance(controller.tuning.cast_duration, player.global_position)
 expect(controller.state == controller.State.WAITING and hud.rod_joystick.enabled, "reeling is enabled as soon as bait enters the water")
 expect(hud.rod_joystick.get_node("Reel").visible and not hud.rod_joystick.get_node("Knob").visible, "waiting state immediately shows the reel instead of the aiming pad")
 var original_bait := controller.cast_position
 var original_length := controller.line_length
 var population := pond.fish.duplicate()
 controller.rod_input = Vector2(0, -1)
 controller.advance(1.0, player.global_position)
 expect(controller.line_length > original_length and controller.cast_position == original_bait, "paying out line creates slack without pushing bait away")
 controller.rod_input = Vector2(0, 1)
 controller.advance(0.5, player.global_position)
 expect(controller.cast_position == original_bait, "winding first takes up existing slack")
 for step in 12:
  controller.advance(0.1, player.global_position)
 expect(controller.cast_position.distance_to(player.global_position) < original_bait.distance_to(player.global_position), "taut retrieval moves the actual bait toward the angler")
 expect(pond.bait_position == controller.cast_position and pond.fish == population, "moving bait updates ecosystem position without respawning fish")
 var stationary := controller.cast_position
 controller.rod_input = Vector2.ZERO
 controller.advance(0.5, player.global_position)
 expect(controller.cast_position == stationary, "neutral reel leaves bait in place")
 controller.rod_input = Vector2(0, 1)
 for step in 300:
  controller.advance(0.1, player.global_position)
  if controller.state == controller.State.READY:
   break
 expect(controller.state == controller.State.READY and not pond.bait_active and controller.active_fish == null, "unhooked bait automatically packs away when reeled close to the angler")
 expect(not hud.rod_joystick.get_node("Reel").visible and hud.rod_joystick.get_node("Knob").visible, "automatic retrieval restores the aiming control")
 expect(controller.cast(), "another cast works after automatic retrieval")
 controller.advance(controller.tuning.cast_duration, player.global_position)
 # Moving the angler into reach also retrieves an unhooked bait at neutral.
 controller.cast_position = pond.constrain_to_water(player.global_position)
 pond.move_bait(controller.cast_position)
 controller.rod_input = Vector2.ZERO
 controller.advance(0.1, player.global_position)
 expect(controller.state == controller.State.READY and not pond.bait_active, "nearby unhooked bait is retrieved without requiring a button or held reel")
 controller.cast()
 controller.advance(controller.tuning.cast_duration, player.global_position)
 var fish: FishState = pond.fish[0]
 fish.position = controller.cast_position
 fish.state = &"biting"
 pond.reserved_fish = fish
 controller._on_fish_biting(fish)
 expect(controller.state == controller.State.BITE and hud.rod_joystick.get_node("Reel").visible, "bite retains the reel control")
 controller.rod_input = Vector2(0, 1)
 controller.advance(0.1, player.global_position)
 expect(controller.state == controller.State.FIGHT and controller.active_fish == fish, "pulling the reel on a bite hooks the same fish instead of packing away")
 controller.cancel()
 expect(not pond.bait_active and pond.reserved_fish == null, "cleanup releases bait and reservation")
 scene.queue_free()
 await process_frame
 print("BAIT RETRIEVAL RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
