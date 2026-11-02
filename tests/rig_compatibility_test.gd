extends SceneTree
var checks := 0
var failures := 0
const OUT := "res://../output/rig-compatibility-v01/"
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + message)
func item(id: String) -> TackleItem: return TackleCatalog.item(id)
func evaluate(rod: String, bait: String, rig: String = "", reel: String = "basic_reel", line: String = "nylon") -> Dictionary:
 var terminal := item(bait).terminal_rigs[0]
 for entry in item(bait).terminal_rigs:
  if str(entry.id) == rig: terminal = entry
 return RigCompatibility.evaluate(item(rod), item(reel), item(line), item(bait), terminal)
func frames() -> void:
 for i in 8: await process_frame
func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = OUT + "profile.cfg"
 profile.data = profile.defaults()
 profile.incompatible = false
 expect(profile.rig_result().allowed, "starter equipment is ready without purchases")
 expect(is_equal_approx(profile.rig_result().payload_g, 3.2), "starter includes bait, hook, float, shot and fittings")
 expect(evaluate("brook_562ul", "spinner").allowed, "mini spinner has a genuine UL use")
 expect(not evaluate("brook_562ul", "minnow").allowed, "10g minnow blocked on 5g UL")
 expect(evaluate("brook_702m", "minnow").allowed, "same lure fits spinning rod")
 expect(evaluate("cover_662m", "minnow", "", "baitcasting_reel").allowed, "same lure fits matched casting set")
 expect(not evaluate("cover_662m", "minnow").allowed, "wrong reel mount is rejected")
 expect(evaluate("cover_652l", "soft_plastic", "", "fast_reel").allowed, "BFS supported by explicit reel spec")
 expect(not evaluate("cover_652l", "rubber_worm", "", "baitcasting_reel").allowed, "light rod alone does not make ordinary baitcaster BFS")
 expect(evaluate("cover_652l", "rubber_worm", "", "fast_reel").allowed, "4g plastic works on BFS")
 expect(evaluate("cover_732h", "dough", "feeder", "baitcasting_reel").allowed, "35g full feeder works on suitable casting tackle")
 expect(not evaluate("brook_702m", "dough", "feeder").allowed, "loaded feeder cannot use light rod")
 expect(is_equal_approx(evaluate("cover_732h", "dough", "feeder", "baitcasting_reel").payload_g, 35.0), "feeder includes actual 20g bait fill")
 expect(evaluate("pole_rod", "worm", "pole").allowed, "pole float does not require reel fit")
 expect(not evaluate("pole_rod", "minnow").allowed, "pole cannot retrieve plug")
 expect(not evaluate("brook_702m", "metal_jig").allowed, "vertical jig is not a castable plug")
 expect(evaluate("current_b602", "metal_jig", "jig", "conventional_reel", "braid").allowed, "100g jig uses jig rating")
 expect(evaluate("boat_rod", "cut_fish", "boat", "spinning_reel").allowed, "boat rod accepts heavy drop rig")
 expect(evaluate("surf_rod", "dough", "feeder_large", "spinning_reel").allowed, "surf has a suitably weighted feeder")
 var surface := evaluate("brook_702m", "popper", "", "basic_reel", "clear_line")
 expect(surface.allowed and not surface.notes.is_empty(), "fluorocarbon topwater is advice, not false prohibition")
 var coated := evaluate("brook_702m", "popper", "", "basic_reel", "coated_line")
 expect(coated.allowed and item("coated_line").line_spec.material == "coated_mono", "coated mono mechanics differ from visual style")
 expect(not evaluate("brook_702m", "minnow", "", "basic_reel", "fly_line").allowed, "fly line not ordinary mainline")
 expect(not evaluate("fly_rod", "insect", "fly", "fly_reel", "fly_line").allowed, "unimplemented fly mode is clearly gated")
 var boundary_rod: TackleItem = item("brook_702m").duplicate()
 boundary_rod.rod_spec = boundary_rod.rod_spec.duplicate()
 var boundary_bait: TackleItem = item("minnow").duplicate()
 for weight in [5.0, 21.0, 4.99, 21.01]:
  boundary_bait.payload_g = weight
  var result := RigCompatibility.evaluate(boundary_rod, item("basic_reel"), item("nylon"), boundary_bait, boundary_bait.terminal_rigs[0])
  expect(result.allowed == (weight >= 5.0 and weight <= 21.0), "inclusive exact bounds %.2f" % weight)
 boundary_rod.rod_spec.cast_max_g = -1
 expect(not RigCompatibility.evaluate(boundary_rod, item("basic_reel"), item("nylon"), item("minnow"), item("minnow").terminal_rigs[0]).allowed, "missing range never means unlimited")
 boundary_rod.rod_spec.cast_max_g = NAN
 expect(not RigCompatibility.evaluate(boundary_rod, item("basic_reel"), item("nylon"), item("minnow"), item("minnow").terminal_rigs[0]).allowed, "nonfinite weight range fails closed")
 var bait_use := {}
 var rod_use := {}
 for rod in TackleCatalog.ITEMS:
  if rod.kind != "rod": continue
  expect(rod.rod_spec != null and not rod.rod_spec.techniques.is_empty(), "authored rod spec " + str(rod.id))
  for reel in TackleCatalog.ITEMS:
   if reel.kind != "reel" or (rod.mount_layout != "fixed" and not EquipmentFit.compatible(rod, reel)): continue
   for bait in TackleCatalog.ITEMS:
    if bait.kind not in ["bait", "lure"]: continue
    for rig in bait.terminal_rigs:
     var result := RigCompatibility.evaluate(rod, reel, item("fine_line"), bait, rig)
     if result.allowed:
      bait_use[str(bait.id)] = true
      rod_use[str(rod.id)] = true
 for entry in TackleCatalog.ITEMS:
  if entry.kind in ["bait", "lure"]: expect(bait_use.has(str(entry.id)), "every bait has accessible loadout " + str(entry.id))
  if entry.kind == "rod" and entry.rod_spec.family not in ["fly", "tenkara", "ice"]: expect(rod_use.has(str(entry.id)), "active rod has usable terminal rig " + str(entry.id))
  if entry.kind == "line": expect(entry.line_spec != null and is_equal_approx(entry.line_spec.break_kgf, entry.strength), "line uses consistent existing kgf " + str(entry.id))
 var old := profile.defaults()
 old.erase("terminal_rig")
 ProfileStore.save_profile(OUT + "legacy.cfg", old)
 var migrated := ProfileStore.load_profile(OUT + "legacy.cfg")
 expect(not migrated.incompatible, "legacy schema gains optional rig without rejection")
 profile.data = migrated.data
 var prior := profile.data.duplicate(true)
 profile.repair_terminal_rig()
 expect(profile.rig_result().allowed and profile.data.stock == prior.stock and profile.data.coins == prior.coins, "migration consumes no bait or currency")
 profile.data = profile.defaults()
 profile.grant_trial_equipment()
 profile.equip("brook_562ul")
 prior = profile.data.duplicate(true)
 expect(not profile.equip("minnow") and profile.data == prior, "rejected lure leaves all inventory unchanged")
 expect(profile.equip("worm") and profile.select_rig("float"), "starter float is valid on UL")
 prior = profile.data.duplicate(true)
 expect(not profile.select_rig("boat") and profile.data == prior, "invalid terminal selection is atomic")
 profile.data.equipped.bait = "dough"; profile.data.terminal_rig = "feeder"
 prior = profile.data.duplicate(true)
 expect(not profile.prepare_cast() and profile.data == prior, "invalid rig blocked before consuming natural bait")
 profile.data = profile.defaults(); profile.grant_trial_equipment()
 expect(profile.equip("dough") and profile.select_rig("bottom"), "natural bait offers multiple actual presets")
 var count := profile.quantity("dough")
 expect(profile.prepare_cast() and profile.quantity("dough") == count - 1, "valid cast consumes exactly one bait")
 var saved := ProfileStore.load_profile(profile.save_path)
 expect(not saved.incompatible and saved.data.terminal_rig == "bottom", "preset persists by stable ID")
 profile.data = profile.defaults(); profile.grant_trial_equipment()
 var line_before := int(profile.data.spares.fly_line)
 expect(not profile.equip("fly_line") and int(profile.data.spares.fly_line) == line_before, "wrong line rejected before spending spool")
 var controller := FishingController.new()
 var pond := PondEcosystem.new()
 controller.ecosystem = pond
 controller.profile = profile
 controller.refresh_equipment()
 expect(is_equal_approx(controller.tuning.spool_capacity, minf(profile.data.line_remaining, profile.line_capacity())), "simulation uses real diameter capacity")
 expect(is_equal_approx(controller.fight.line_strength, item("nylon").line_spec.break_kgf), "simulation reads mechanical line strength")
 var actor := Node3D.new();root.add_child(actor);controller.player = actor
 profile.data.equipped.rod = "brook_562ul";profile.data.equipped.bait = "minnow";profile.data.terminal_rig = "plug"
 prior = profile.data.duplicate(true)
 expect(controller.cast_block_reason() == profile.current_fit_error() and not controller.cast(), "controller and inventory share exact cast rejection")
 expect(profile.data == prior, "blocked controller cast cannot consume bait or alter save")
 profile.data = profile.defaults()
 controller.ecosystem = null
 profile.data.equipped.rod = "pole_rod";profile.data.terminal_rig = "pole"
 var target := controller.get_aim_position()
 expect(Vector2(target.x, target.z).length() <= item("pole_rod").rod_spec.length_m * .85 + .001, "pole presentation is limited by rod reach")
 profile.data.equipped.rod = "current_b602";profile.data.equipped.reel = "conventional_reel";profile.data.equipped.bait = "metal_jig";profile.data.terminal_rig = "jig"
 target = controller.get_aim_position()
 expect(Vector2(target.x, target.z).length() <= 1.501 and controller.is_drop_method(), "vertical jig cannot become long cast")
 controller.ecosystem = pond;controller.refresh_equipment()
 controller.cast_position = pond.constrain_to_water(Vector3(0,1.0,-8))
 var jig_xz := Vector2(controller.cast_position.x, controller.cast_position.z)
 controller._move_lure(2.0, -.2)
 expect(Vector2(controller.cast_position.x, controller.cast_position.z).is_equal_approx(jig_xz), "jig gestures never pull vertical lure horizontally")
 controller.cast_position = pond.constrain_to_water(Vector3(0,1.0,-8));controller.line_length = 1.5
 controller.state = FishingController.State.WAITING;controller.rod_input = Vector2.ZERO
 var drop_depth := controller.cast_position.y
 controller._retrieve_step(.1, Vector3(controller.cast_position.x,0,controller.cast_position.z))
 expect(controller.state == FishingController.State.WAITING and is_equal_approx(controller.cast_position.y, drop_depth), "vertical bait does not auto-retrieve due to short horizontal distance")
 controller.rod_input = Vector2.DOWN
 controller._retrieve_step(.1, Vector3(controller.cast_position.x,0,controller.cast_position.z))
 expect(controller.cast_position.y < drop_depth, "vertical retrieve lifts depth rather than sliding bait ashore")
 controller.state = FishingController.State.READY;controller.player = null;actor.free()
 profile.data = profile.defaults();profile.grant_trial_equipment();profile.save_error = "";controller.refresh_equipment()
 var shop: Control = load("res://features/economy/tackle_panel.tscn").instantiate()
 var gateway := CommerceGateway.new()
 root.add_child(shop);shop.bind(profile, controller, pond, gateway);shop.open_category(1)
 for resolution in [Vector2i(1280,720), Vector2i(1024,768), Vector2i(2400,1080)]:
  root.size = resolution
  await frames()
  shop.get_node("Shop/%Gear").pressed.emit()
  shop.get_node("Shop/%LoadoutSettings").pressed.emit()
  await frames()
  var picker: OptionButton = shop.get_node("Shop/%Rig")
  expect(picker.item_count == item("worm").terminal_rigs.size(), "authored preset picker has actual options")
  expect(root.get_visible_rect().encloses(picker.get_global_rect()), "preset selector fits " + str(resolution))
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT + "shop_%dx%d.png" % [resolution.x, resolution.y])
 root.size = Vector2i(1280,720)
 profile.equip("brook_562ul");shop.refresh()
 if DisplayServer.get_name() != "headless":
  await frames();await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT + "shop_ul_locked.png")
 var inspector: Control = shop.get_node("Shop/%EquipmentInspector")
 for i in TackleCatalog.ITEMS.size():
  var entry: TackleItem = TackleCatalog.ITEMS[i]
  if entry.kind not in ["bait", "lure"]: continue
  inspector.open_item(entry)
  expect(inspector.get_node("%Equip").disabled == (not profile.candidate_rig_result(entry).allowed or profile.quantity(str(entry.id)) <= 0 or entry.id == profile.equipped("bait").id), "shop uses same evaluator " + str(entry.id))
 inspector.close()
 profile.equip("cover_732h");profile.equip("baitcasting_reel");profile.equip("dough")
 expect(profile.select_rig("feeder"), "loaded feeder can be selected in suitable loadout")
 shop.refresh()
 if DisplayServer.get_name() != "headless":
  await frames();await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT + "shop_feeder_35g.png")
 shop.queue_free();controller.free();pond.free();gateway.free()
 await process_frame
 var file := FileAccess.open(OUT + "verification.json", FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"bait_paths":bait_use,"rod_paths":rod_use}, "  "))
 print("RIG COMPATIBILITY: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
