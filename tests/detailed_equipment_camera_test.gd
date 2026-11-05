extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func frames(count: int = 3) -> void:
 for i in count:
  await physics_frame
  await process_frame
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = "res://../output/game-equipment-test-profile.cfg"
 var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.economy_enabled = false
 root.add_child(scene)
 current_scene = scene
 await frames()
 scene.set_process(false)
 var player: AnglerPlayer = scene.player
 player.set_physics_process(false)
 scene.fishing.set_physics_process(false)
 scene.pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 var unique_rods := {}
 var unique_reels := {}
 for item in TackleCatalog.ITEMS:
  if item.kind == "rod":
   player.equip_rod(item)
   var rod = player.character_model.rod_mesh
   expect(rod is DetailedFishingRod, "new rod model: " + str(item.id))
   unique_rods[rod.rod_id] = true
   rod.set_load(0, 0)
   var before: Vector3 = rod.tip.global_position
   rod.set_load(0.8, 0.3)
   expect(rod.tip.global_position.is_finite(), "finite tip")
   expect(rod.tip.global_position.distance_to(before) > 0.01, "real skeleton bends")
   expect(rod.guide_points.size() == rod.config["guides"].size(), "every guide has an anchor")
  elif item.kind == "reel":
   var reel = item.model_scene.instantiate()
   scene.add_child(reel)
   expect(reel is DetailedReelVisual, "new reel: " + str(item.id))
   if reel is DetailedReelVisual:
    unique_reels[reel.reel_id] = true
    for style in ["mono", "fluoro", "braid", "fly"]:
     reel.set_line_style(style)
     reel.advance(0.1, 1, 0.4, 0.6)
     expect(reel.fill.mesh.get_faces().size() == 192, "64-triangle fill")
     expect(reel.fill.global_transform.is_finite(), "fill follows spool")
   reel.queue_free()
 expect(unique_rods.size() == 26, "twelve base models and fourteen rod variants selectable")
 expect(unique_reels.size() == 8, "all eight reel families selectable")
 player.equip_rod(TackleCatalog.item("spinning_rod"))
 player.character_model.equip_reel(TackleCatalog.item("spinning_reel"))
 player.character_model.equip_line(TackleCatalog.item("braid"))
 expect(not scene.fishing_first_person,"third person is the default fishing perspective")
 scene.fishing.state = FishingController.State.WAITING
 scene._on_fishing_state_changed()
 expect(not scene.camera_rig.first_person,"default waiting view shows the character")
 scene.hud.get_node("SafeArea/PerspectiveButton").button_pressed = true
 expect(scene.camera_rig.first_person,"HUD button switches to first person")
 scene.fishing.profile = profile
 for state in [FishingController.State.READY, FishingController.State.CASTING, FishingController.State.WAITING, FishingController.State.BITE, FishingController.State.FIGHT, FishingController.State.RESULT, FishingController.State.LOST, FishingController.State.READY]:
  scene.fishing.state = state
  scene._on_fishing_state_changed()
  scene.hud._apply_fishing_visibility(state)
  await frames()
  var active: bool = state in [FishingController.State.WAITING, FishingController.State.BITE, FishingController.State.FIGHT]
  expect(scene.hud.get_node("SafeArea/PerspectiveButton").visible,"perspective preference stays available in every fishing state")
  expect(scene.fishing_first_person and scene.hud.get_node("SafeArea/PerspectiveButton").button_pressed,"first-person preference survives retrieval and the next cast")
  expect(scene.hud.get_node("SafeArea/RankingButton").visible == (state in [FishingController.State.READY,FishingController.State.LOST]),"ranking returns after fishing")
  expect(scene.camera_rig.first_person == active, "selected camera applies only while bait is deployed, state " + str(state))
  expect(player.character_model.get_node("Asset").visible != active, "character visibility restored")
  expect(root.get_camera_3d() == scene.camera_rig.get_node("FishingCamera3D" if active else "Camera3D"), "correct camera is current")
  if active:
   expect(player.first_person_rod is DetailedFishingRod, "camera holds selected new equipment")
   expect(player.first_person_rod.line_style == "braid", "selected line follows first-person reel")
   expect(not player.character_model.rod_mesh.visible, "no duplicate world rod")
   expect(scene.get_node("FishingEffects").rod_tip.global_position.distance_to(player.first_person_rod.tip.global_position) < 0.001, "world line follows visible rod tip")
   scene.hud.get_node("SafeArea/PerspectiveButton").button_pressed = false
   await frames()
   expect(not scene.camera_rig.first_person and player.character_model.get_node("Asset").visible,"switching during fishing restores character")
   expect(player.first_person_rod == null,"third person releases first-person equipment")
   scene.hud.get_node("SafeArea/PerspectiveButton").button_pressed = true
 scene.hud.get_node("SafeArea/PerspectiveButton").button_pressed = false
 scene.fishing.state = FishingController.State.WAITING
 scene._on_fishing_state_changed()
 var view = scene.camera_rig.get_node("FishingCamera3D/EquipmentView")
 view.set_process(false)
 var world_rod: DetailedFishingRod = player.character_model.rod_mesh
 for side in [-1.0,1.0]:
  scene.fishing.rod_input = Vector2(side,0)
  for step in 60: view._process(1.0/60.0)
  expect(world_rod.external_pull_enabled,"third person bends toward the actual line pull")
  expect(view.visual_stick.x*side>0.99,"third person uses the same left/right response")
  expect(world_rod.global_position.distance_to(player.character_model.rod_grip.global_position)<0.001,"hand grip remains fixed while rod sweeps")
  expect(world_rod.transform.is_finite(),"third person action transform is finite")
  var before: float = view.visual_stick.x
  scene.fishing.rod_input=Vector2.ZERO
  view._process(1.0/60.0)
  expect(absf(view.visual_stick.x)>0.5 and absf(view.visual_stick.x)<absf(before),"release eases toward centre without snapping")
 expect(not player.character_model.left_hand_ik.override_tip_basis,"support hand avoids forced wrist twist")
 scene.fishing.state=FishingController.State.READY
 view._process(1.0/60.0)
 expect(not player.character_model.shared_rod_action and world_rod.transform.is_equal_approx(player.character_model._rod_rest),"retrieval restores authored grip transform")
 scene.queue_free()
 await process_frame
 print("NEW EQUIPMENT / CAMERA: %d checks, %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
