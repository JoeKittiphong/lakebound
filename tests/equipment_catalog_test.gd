extends SceneTree

var failures := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: " + message)

func frames(count: int = 4) -> void:
 for frame in count:
  await process_frame

func capture(name: String) -> void:
 if output.is_empty() or DisplayServer.get_name() == "headless":
  return
 await frames(6)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = output.path_join("equipment-profile.cfg") if not output.is_empty() else "res://../exports/qa-equipment/equipment-profile.cfg"
 profile.data = profile.defaults()
 profile.incompatible = false
 root.get_node("FishCollection").recording_enabled = false
 expect(ProfileStore.valid(profile.data), "old default save remains compatible")
 expect(TackleCatalog.ITEMS.size() == 81, "80 existing equipment entries plus one purchasable boat")
 var ids := {}
 var rects := {}
 var counts := {}
 for item in TackleCatalog.ITEMS:
  expect(not ids.has(item.id), "unique item: " + String(item.id))
  ids[item.id] = true
  counts[item.kind] = int(counts.get(item.kind, 0)) + 1
  if item.kind == "boat":
   expect(item.model_scene != null and item.boat_spec != null,"boat uses its authored 3D preview and hull specification")
   continue
  var icon: AtlasTexture = item.shop_icon as AtlasTexture
  expect(icon != null and icon.atlas.resource_path.ends_with("equipment.png"), "generated shared atlas icon: " + String(item.id))
  if icon == null:
   continue
  expect(item.rod_spec != null or not rects.has(icon.region) or String(item.id) in ["spinning_reel", "spinning_rod", "casting_rod", "pole_rod", "jigging_rod", "spincast_rod", "tenkara_rod", "boat_rod", "feeder_rod", "ice_rod", "round_reel", "lever_drag_reel", "inline_ice_reel", "fly_line"], "unique or intentionally shared family atlas cell: " + String(item.id))
  rects[icon.region] = true
  expect(Rect2(Vector2.ZERO, icon.atlas.get_size()).encloses(icon.region), "atlas cell stays inside imported texture: " + String(item.id))
  var image := icon.atlas.get_image().get_region(Rect2i(icon.region))
  var padding := roundi(icon.region.size.x / 16.0)
  expect(image.get_used_rect().has_area() and image.get_used_rect().position.x >= padding and image.get_used_rect().position.y >= padding and image.get_used_rect().end.x <= int(icon.region.size.x)-padding and image.get_used_rect().end.y <= int(icon.region.size.y)-padding, "complete padded sprite: " + String(item.id))
 expect(counts == {"rod":29,"reel":12,"bait":12,"lure":13,"line":8,"box":6,"boat":1}, "all equipment families and rod variants are represented")
 # Export repacks scenes; non-editable child overrides can disappear there.
 var shop_source: Control = load("res://features/economy/tackle_panel.tscn").instantiate()
 var repacked := PackedScene.new()
 expect(repacked.pack(shop_source) == OK, "shop scene can be repacked for export")
 var shop_copy: Control = repacked.instantiate()
 expect(shop_copy.has_node("Shop/Floating/Wallet"), "wallet survives export-style scene repacking")
 shop_copy.free()
 shop_source.free()
 var money: int = profile.data.coins
 expect(profile.grant_trial_equipment() and profile.data.coins == money, "trial grant provides equipment without spending or minting currency")
 var before: Dictionary = profile.data.stock.duplicate()
 expect(profile.grant_trial_equipment() and profile.data.stock == before, "trial grant is idempotent")
 for item in TackleCatalog.ITEMS:
  # Selection now requires a valid terminal loadout. Fixtures pick owned gear,
  if item.kind == "boat":
   expect(profile.quantity(str(item.id)) == 0,"boats must be bought rather than granted by trials")
   continue
  # then exercise the same inventory action rather than bypassing the validator.
  if item.kind in ["bait", "lure"]:
   choose_fixture(profile, item)
  if item.kind == "line":
   profile.equip("fly_rod" if item.line_spec.material == "fly" else "light_rod")
  if item.kind == "reel":
   for candidate in TackleCatalog.ITEMS:
    if candidate.kind == "rod" and EquipmentFit.compatible(candidate,item):
     profile.equip(str(candidate.id))
     break
  expect(profile.equip(String(item.id)), "owned equipment can be equipped: " + String(item.id))
 expect(ProfileStore.valid(profile.data), "all experimental equipment choices form a valid save")
 var saved := ProfileStore.load_profile(profile.save_path)
 expect(not saved.incompatible and saved.data.equipped == profile.data.equipped and saved.data.stock == profile.data.stock, "new inventory and loadout survive save reload")
 profile.data.pending = {"id":"trial-pending", "lure":"frog", "cost":TackleCatalog.item("frog").recovery_cost}
 before = profile.data.duplicate(true)
 expect(not profile.grant_trial_equipment() and profile.data == before, "trial grant cannot clear or bypass a pending lure recovery")
 profile.data.pending = {}
 profile.equip("small_box")
 profile.data.catches = [{"weight":15.0}]
 expect(not profile.equip("micro_box") and profile.equipped("box").id == &"small_box", "a smaller bucket cannot discard already stored fish")
 profile.data.catches = []
 profile.equip("light_rod")
 profile.equip("basic_reel")
 profile.equip("minnow")
 profile.equip("nylon")
 test_patterns()

 root.size = Vector2i(1280, 720)
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 scene.get_node("HUD/FishingHUD/SafeArea/FirstCatch").save_path = profile.save_path + ".tutorial"
 root.add_child(scene)
 current_scene = scene
 await frames(10)
 var controller: FishingController = scene.get_node("FishingController")
 var pond: PondEcosystem = scene.get_node("PondEcosystem")
 var player: AnglerPlayer = scene.get_node("Player")
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var panel: Control = hud.get_node("TacklePanel")
 expect(not hud.rod_joystick.has_node("Reel"), "no duplicate HUD reel")
 controller.set_physics_process(false)
 pond.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 hud.open_tackle()
 expect(panel.get_node("Shop/%Wallet").text.contains("เหรียญ"), "shop coin readout survives scene instancing")
 expect(panel.get_node("Shop/%Wallet").text.contains("เพชร"), "shop gem readout survives scene instancing")
 expect(TackleCatalog.ITEMS.all(func(item:Resource):return item.model_scene!=null), "all 80 products have actual 3D models")
 panel.get_node("Shop")._more(20)
 expect(profile.quantity("electric_reel") > 0 and profile.data.spares.heavy_braid >= 3, "shop trial button supplies every family")
 for resolution in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(1024,768)]:
  root.size=resolution
  for category in [2,3,1,4,5]:
   panel.open_category(category)
   await frames()
   var shelf: ShopShelfBrowser = panel.get_node("Shop/%Shelf")
   expect(shelf.items.size() >= 1 and root.get_visible_rect().encloses(shelf.get_global_rect()), "shop fits mobile viewport: %s category %d" % [resolution,category])
   if resolution == Vector2i(1280,720) or (resolution == Vector2i(2400,1080) and category==3):
    await capture("shop_%dx%d_category%d" % [resolution.x,resolution.y,category])
 panel.close()
 root.size=Vector2i(1280,720)
 await frames()
 controller.cast_position = pond.constrain_to_water(player.global_position + Vector3(10,1,0))
 controller.line_length=15
 controller._change_state(controller.State.WAITING)
 for item in TackleCatalog.ITEMS:
  if item.kind != "reel": continue
  for candidate in TackleCatalog.ITEMS:
   if candidate.kind == "rod" and EquipmentFit.compatible(candidate,item):
    profile.equip(str(candidate.id))
    break
  expect(profile.equip(String(item.id)), "select reel through inventory: " + String(item.id))
  controller.refresh_equipment()
  await frames()
  var reel := player.character_model.rod_mesh.held_reel as DetailedReelVisual
  expect(reel != null and reel.scene_file_path == item.model_scene.resource_path and reel.part("SpoolPivot") != null, "selected reel is mounted on the actual rod: " + String(item.id))
  var start: float = reel.turns
  reel.advance(0.1, 1, 0)
  expect(reel.turns > start, "mounted reel animates: " + String(item.id))
  expect(is_equal_approx(controller.tuning.reel_speed,item.reel_speed) and is_equal_approx(controller.fight.reel_drag_power,item.drag_power), "equipped reel changes real retrieve and drag: " + String(item.id))
  await capture("equipped_"+String(item.id))
 profile.equip("fly_rod")
 controller.refresh_equipment()
 expect(is_equal_approx(controller.fight.rod_responsiveness,profile.equipped("rod").responsiveness), "rod type changes actual steering response")
 profile.equip("light_rod")
 profile.equip("copolymer")
 controller.refresh_equipment()
 expect(is_equal_approx(controller.fight.line_shock_absorption,1.15), "line type changes actual shock absorption")
 profile.equip("crankbait")
 controller._change_state(controller.State.WAITING)
 controller.rod_input=Vector2.ZERO
 controller.advance(0.01,player.global_position)
 controller.cast_position.y=0.5
 controller.rod_input=Vector2.DOWN
 controller.advance(0.3,player.global_position)
 expect(controller.cast_position.y>0.5, "crankbait dives toward its authored running depth")
 controller.rod_input=Vector2.ZERO
 profile.equip("spinning_reel")
 controller.refresh_equipment()
 await capture("gameplay_spinning_reel")
 scene.queue_free()
 await process_frame
 print("EQUIPMENT CATALOG RESULT: %d checks, %d failures" % [checks,failures])
 quit(0 if failures==0 else 1)

func choose_fixture(profile: AnglerProfile, bait: TackleItem) -> void:
 for rod in TackleCatalog.ITEMS:
  if rod.kind != "rod": continue
  for reel in TackleCatalog.ITEMS:
   if reel.kind != "reel" or (rod.mount_layout != "fixed" and not EquipmentFit.compatible(rod, reel)): continue
   for rig in bait.terminal_rigs:
    if RigCompatibility.evaluate(rod, reel, TackleCatalog.item("nylon"), bait, rig).allowed:
     profile.data.equipped.rod = str(rod.id)
     profile.data.equipped.reel = str(reel.id)
     profile.data.equipped.line = "nylon"
     profile.data.terminal_rig = str(rig.id)
     return

func test_patterns() -> void:
 var gestures = load("res://features/fishing/lure_gestures.gd").new()
 gestures.advance(0.1,Vector2.UP,"jerk_fall")
 gestures.advance(0.1,Vector2.ZERO,"jerk_fall")
 gestures.advance(0.3,Vector2.UP,"jerk_fall")
 var event: Dictionary = gestures.advance(0.5,Vector2.ZERO,"jerk_fall")
 expect(event.pattern=="Jerk & Fall", "metal jigs reward lift-lift-fall rhythm")
 gestures.reset()
 gestures.advance(0.1,Vector2.UP,"twitch_pause")
 gestures.advance(0.4,Vector2.LEFT,"twitch_pause")
 event=gestures.advance(0.3,Vector2.ZERO,"twitch_pause")
 expect(event.pattern=="Twitch & Pause", "poppers reward twitch and pause")
 gestures.reset()
 event=gestures.advance(1.7,Vector2.DOWN,"steady")
 expect(event.pattern=="Steady Retrieve", "spoons and spinners reward continuous retrieval")
