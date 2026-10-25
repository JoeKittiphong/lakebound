extends SceneTree

var checks := 0
var failures := 0
var modal_events: Array[bool] = []

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func run() -> void:
 var collection := root.get_node("FishCollection")
 collection.recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://hud-session-test.cfg"
 profile.data = profile.defaults()
 profile.incompatible = false
 var scene: Node3D = load("res://features/regions/lotus_marsh.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var camera: AnglerCameraRig = scene.get_node("CameraRig")
 var fishing: FishingController = scene.get_node("FishingController")
 fishing.set_physics_process(false)
 hud.collection_visibility_changed.connect(func(opened: bool): modal_events.append(opened))
 # Internal controls are inspected by this UI integration fixture only. Session
 # callers exercise capabilities instead of learning these scene paths.
 expect(hud.get_node("TacklePanel").map_id == "lotus_marsh" and hud.get_node("MissionPanel").map_id == "lotus_marsh", "region context reaches both economy panels")
 expect(hud.get_node("SafeArea/BaitPanel/Content/DepthRow/Depth").max_value == scene.maximum_fishing_depth, "region depth limit is configured through HUD")
 expect(hud.get_node("TacklePanel").profile == profile and hud.get_node("MissionPanel").profile == profile, "economy panels bind the same persistent profile")
 hud.update_wallet(123)
 expect("123" in hud.get_node("SafeArea/TackleButton").text, "wallet API updates the authored button")
 hud.set_boss_notice("test boss")
 hud.set_boss_notice_visible(true)
 expect(hud.get_node("SafeArea/BossToast").text == "test boss" and hud.get_node("SafeArea/BossToast").visible, "boss text and visibility use the HUD API")
 var tutorial := hud.get_node("SafeArea/FirstCatch")
 expect(hud.is_tutorial_active() == tutorial.active, "tutorial availability is queried without exposing its node")
 var rod_touch := InputEventScreenTouch.new()
 rod_touch.index = 7
 rod_touch.pressed = true
 rod_touch.position = hud.rod_joystick.get_global_rect().get_center() + Vector2(0, 40)
 root.push_input(rod_touch, true)
 var move_touch := InputEventScreenTouch.new()
 move_touch.index = 6
 move_touch.pressed = true
 move_touch.position = hud.move_joystick.get_global_rect().get_center() + Vector2(40, 0)
 root.push_input(move_touch, true)
 expect(hud.rod_joystick.touch_index == 7 and hud.move_joystick.touch_index == 6, "two actual touch presses establish separate input owners before opening a modal")
 camera.look_finger = 8
 hud.open_tackle()
 expect(paused and not camera.enabled and camera.look_finger == -1, "opening tackle pauses the session and clears camera ownership")
 expect(hud.rod_direction() == Vector2.ZERO and hud.move_joystick.direction == Vector2.ZERO and hud.rod_joystick.touch_index == -1 and hud.move_joystick.touch_index == -1, "opening a modal clears held movement and fishing gestures")
 expect(not tutorial.visible, "opening a modal hides the tutorial")
 hud.get_node("MissionPanel").open()
 expect(modal_events == [true], "a second open panel does not replace the original pause snapshot")
 hud.get_node("TacklePanel").close()
 expect(paused and hud.is_collection_open() and modal_events == [true], "closing one of two panels cannot resume the session")
 expect(hud.close_top_panel(), "Back closes the remaining modal through the HUD API")
 expect(not paused and camera.enabled and modal_events == [true, false], "closing the last panel restores the original active session once")
 rod_touch.pressed = false
 move_touch.pressed = false
 root.push_input(rod_touch, true)
 root.push_input(move_touch, true)
 expect(fishing.state == FishingController.State.READY, "releasing fingers after modal close cannot cast a stale aiming gesture")
 expect(not hud.close_top_panel(), "Back reports when no modal remains")
 paused = true
 hud.open_tackle()
 hud.close_top_panel()
 expect(paused, "closing a modal preserves an externally paused tree")
 paused = false
 modal_events.clear()
 hud.open_tackle()
 hud.open_tackle()
 expect(modal_events == [true], "reopening an already visible panel does not duplicate session events")
 hud.get_node("MissionPanel").open()
 expect(hud.close_top_panel() and hud.get_node("TacklePanel").visible and paused, "Back closes missions before tackle and keeps input paused")
 scene._on_back_pressed()
 expect(not paused and current_scene == scene, "session Back closes the last modal and restores play without navigating away")
 profile.equip("minnow")
 fishing._change_state(FishingController.State.WAITING)
 hud._process(0.01)
 var action: Button = hud.get_node("SafeArea/LureAction")
 var press := InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 press.position = action.get_global_rect().get_center()
 root.push_input(press, true)
 await process_frame
 expect(hud.is_lure_action_held(), "session queries the held lure command through its API")
 press.pressed = false
 root.push_input(press, true)
 expect(not hud.is_lure_action_held(), "releasing the lure button clears the session command")
 fishing.reset_cast()
 hud.open_tackle()
 scene.free()
 current_scene = null
 expect(not paused, "removing a session with an open economy panel restores pause state")
 await process_frame
 print("HUD SESSION RESULT: ", checks, " checks, ", failures, " failures")
 quit(1 if failures else 0)
