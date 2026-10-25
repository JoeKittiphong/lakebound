extends SceneTree

var checks := 0
var failures := 0
var scene: Node3D
var profile: AnglerProfile
var controller: FishingController
var pond: PondEcosystem
var player: AnglerPlayer

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
 profile = root.get_node("AnglerSave")
 profile.save_path = "user://flow-test-%d.cfg" % Time.get_ticks_usec()
 profile.data = profile.defaults()
 root.get_node("FishCollection").recording_enabled = false
 scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.set_process(false)
 controller = scene.get_node("FishingController")
 pond = scene.get_node("PondEcosystem")
 player = scene.get_node("Player")
 controller.set_physics_process(false)
 pond.set_physics_process(false)
 for frame in 25:
  await physics_frame
 player.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var panel: Control = hud.get_node("TacklePanel")
 hud._on_tackle_pressed()
 expect(panel.visible and paused and not scene.get_node("CameraRig").enabled, "equipment panel pauses world and releases camera input")
 panel.close()
 expect(not paused, "closing equipment restores simulation")
 expect(profile.equip("minnow"), "starter lure is selectable")
 controller.refresh_equipment()
 expect(controller.cast(), "equipped lure casts into actual river")
 controller.advance(controller.tuning.cast_duration, player.global_position)
 var point := controller.cast_position
 var population := pond.fish.duplicate()
 controller.lure_input.press()
 controller.lure_input.release()
 controller.advance(0.3, player.global_position)
 expect(controller.cast_position != point and pond.bait_position == controller.cast_position and pond.fish == population, "tap moves existing bait without generating any fish")
 var fish: FishState = pond.fish[0]
 fish.position = controller.cast_position
 controller._on_fish_biting(fish)
 controller.strike()
 controller.lose("slack")
 expect(profile.quantity("minnow") == 1 and profile.data.pending.is_empty(), "ordinary unhooking never charges or removes the lure")
 controller.reset_cast()
 expect(controller.cast(), "cast after slack loss remains usable")
 controller.advance(controller.tuning.cast_duration, player.global_position)
 controller._on_fish_biting(fish)
 controller.strike()
 var deployed := controller.line_length
 controller.lose("line break", true)
 expect(profile.quantity("minnow") == 0 and not profile.data.pending.is_empty() and profile.data.line_remaining < 65.0, "actual line-break path removes lure and deployed line")
 expect(panel.visible and paused, "loss opens persistent recovery choice")
 expect(not profile.recover_with_diamonds(), "zero diamonds cannot bypass recovery")
 var recovery_id: String = profile.data.pending.id
 expect(profile.apply_verified_reward("flow-reward", recovery_id), "trusted earned event resolves actual pending loss")
 expect(is_equal_approx(profile.data.line_remaining, 65.0 - deployed), "earned reward does not restore broken line")
 panel.close()
 controller.reset_cast()
 profile.equip("worm")
 controller.refresh_equipment()
 var boss := pond.boss()
 controller.active_fish = boss
 controller.cast_position = boss.position
 controller._change_state(controller.State.RESULT)
 controller.fish_landed.emit(boss)
 expect(not controller.catch_record.is_empty() and profile.data.boss_history.size() == 1, "landed boss records actual bait, gear, map and depth")
 controller.resolve_catch(true)
 expect(profile.data.catches.size() == 1 and boss not in pond.fish, "keep transfers landed fish out of pond and into storage")
 var money: int = profile.data.coins
 profile.sell_catches()
 expect(profile.data.coins > money and profile.data.catches.is_empty(), "complete catch-store-sell loop earns coins")
 scene.free()
 expect(not paused and profile.data.ponds.has("river"), "session exit saves individual pond without leaving game paused")
 print("EXPANSION FLOW RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
