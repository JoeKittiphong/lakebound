extends SceneTree

var checks := 0
var failures := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func frames(count: int = 6) -> void:
 for i in count:
  await process_frame
 await RenderingServer.frame_post_draw

func capture(name: String) -> void:
 await frames()
 root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func inside(control: Control) -> bool:
 var rect := control.get_global_rect()
 return root.get_visible_rect().encloses(rect)

func run() -> void:
 if output.is_empty(): output = "res://exports/qa-ui-refresh/screenshots"
 DirAccess.make_dir_recursive_absolute(output)
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://ui-refresh-%d.cfg" % Time.get_ticks_usec()
 profile.data = profile.defaults()
 profile.data.coins = 5000
 root.get_node("FishCollection").recording_enabled = false
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 var fishing: FishingController = scene.get_node("FishingController")
 var pond: PondEcosystem = scene.get_node("PondEcosystem")
 fishing.set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 var shop: Control = hud.get_node("TacklePanel")
 var storage: Control = hud.get_node("FishStoragePanel")
 for i in 20: await physics_frame
 # A real owned catch is removed from its source ecosystem before storage.
 for i in 3:
  var fish: FishState = pond.fish[0]
  var record := CatchSettlement.make_record(fish, profile, "river", "ui-catch-%d" % i, "worm", 1.5, false, false)
  var population := pond.snapshot()
  record.fish_snapshot = population.pop_front()
  expect(profile.keep_catch(record, "river", population), "seed actual catch %d" % i)
  pond.keep(fish)
 var original_population := pond.fish.size()
 for dimensions in [Vector2i(1280,720), Vector2i(1600,720), Vector2i(1024,768)]:
  root.size = dimensions
  await frames()
  expect(hud.move_joystick.position == Vector2(20, hud.get_node("SafeArea").size.y - 212), "movement joystick retains original anchors")
  await capture("hud-%dx%d" % [dimensions.x, dimensions.y])
  shop.open_category(0)
  await frames()
  expect(inside(shop.get_node("Card/Content")), "shop fits %s" % dimensions)
  var rows: GridContainer = shop.get_node("Card/Content/Tabs/Tackle/Scroll/Rows")
  expect(rows.get_child_count() == TackleCatalog.ITEMS.size(), "catalog renders every item")
  for row in rows.get_children():
   expect(row.get_node("Content/Icon").texture != null, "product illustration " + row.item_id)
  if dimensions == Vector2i(1280,720):
   var buy: Button = rows.get_child(0).get_node("Content/Actions/Buy")
   var coins_before_swipe: int = profile.data.coins
   var point := buy.get_global_rect().get_center()
   var touch := InputEventScreenTouch.new()
   touch.index = 4
   touch.position = point
   touch.pressed = true
   root.push_input(touch, true)
   var drag := InputEventScreenDrag.new()
   drag.index = 4
   drag.position = point - Vector2(0, 120)
   drag.relative = Vector2(0, -120)
   root.push_input(drag, true)
   touch.pressed = false
   touch.position = drag.position
   root.push_input(touch, true)
   expect(profile.data.coins == coins_before_swipe and shop.get_node("Card/Content/Tabs/Tackle/Scroll").scroll_vertical > 0, "swiping over a purchase button scrolls without buying")
   shop.get_node("Card/Content/Tabs/Tackle/Scroll").stop_scrolling()
   shop.get_node("Card/Content/Tabs/Tackle/Scroll").scroll_vertical = 0
  await capture("shop-%dx%d" % [dimensions.x, dimensions.y])
  shop.open_category(2)
  await frames()
  var rod_count := 0
  for row in rows.get_children():
   if row.visible: rod_count += 1
  expect(rod_count == 3, "rod filter includes added balanced rod")
  await capture("rods-%dx%d" % [dimensions.x, dimensions.y])
  expect(shop.get_node("Card/Content/Tabs").get_tab_count() == 2, "duplicate fish storage and boss tabs removed from shop")
  shop.close()
  hud.open_map()
  var map_panel: FishingMapPanel = hud.get_node("MapPanel")
  expect(not map_panel.view.boss.is_empty() and is_equal_approx(float(map_panel.boss_info.weight), pond.boss().weight), "map displays actual current boss")
  expect(map_panel.view.boss.position == Vector2(pond.boss().position.x, pond.boss().position.z), "crown uses the real boss location")
  map_panel.view._pick(map_panel.view.project(map_panel.view.boss.position))
  expect(map_panel.selected.get("kind") == "boss" and "จ้าวบ่อ" in map_panel.get_node("%DetailTitle").text, "crown marker opens boss details on map")
  await capture("map-boss-%dx%d" % [dimensions.x, dimensions.y])
  if dimensions == Vector2i(1280,720):
   for region_index in RegionCatalog.MAPS.size():
    var region: Dictionary = RegionCatalog.MAPS[region_index]
    if region.id == "river":
     continue
    map_panel._region_selected(region_index)
    expect(map_panel.view.boss.is_empty(), "unvisited map does not invent a boss or location")
    profile.data.ponds[region.id] = pond.snapshot()
    map_panel._refresh()
    expect(not map_panel.view.boss.is_empty() and not map_panel.boss_info.live, "other maps show explicitly saved boss data")
    profile.data.ponds.erase(region.id)
    break
  map_panel.close()
  hud.get_node("SafeArea/TopBar/Actions/FishBox/Open").pressed.emit()
  expect(paused and storage.visible and not shop.visible, "fish-box icon opens storage and pauses gameplay")
  await create_timer(1.0, true).timeout
  await frames()
  expect(inside(storage.get_node("Card/Content")), "fish box fits %s" % dimensions)
  expect(inside(storage.detail.get_node("Release")), "fish actions fit %s" % dimensions)
  expect(storage.grid.get_child_count() == 8, "eight authored inventory cells live inside the 3D box")
  expect(storage.grid is Node3D, "inventory contains real 3D fish holders")
  var lid: Node3D = storage.viewport.get_node("Stage/Box/Lid")
  expect(is_equal_approx(lid.rotation.x, -1.8325957), "Blender lid animation reaches original open angle")
  var cell: StoredFishDisplay = storage.grid.get_child(1)
  expect(cell.model != null and cell.mesh_bounds().size.length() > 0, "stored catch uses its actual species mesh")
  var on_floor: Vector3 = cell.to_global(cell.mesh_bounds().get_center())
  var pixel: Vector2 = storage.camera.unproject_position(on_floor)
  var screen: Vector2 = storage.preview.global_position + pixel * storage.preview.size / Vector2(storage.viewport.size)
  var press := InputEventScreenTouch.new()
  press.index = 5
  press.pressed = true
  press.position = screen
  root.push_input(press, true)
  press.pressed = false
  root.push_input(press, true)
  await frames()
  expect(storage.selected_index == 1, "real screen touch selects fish INSIDE the 3D compartment")
  await capture("fish-box-%dx%d" % [dimensions.x, dimensions.y])
  if dimensions == Vector2i(1280,720):
   var original := profile.data.duplicate(true)
   profile.data.catches = []
   for index in 10:
    var paged_record: Dictionary = original.catches[0].duplicate(true)
    paged_record.catch_id = "paged-record-%d" % index
    profile.data.catches.append(paged_record)
   profile.changed.emit()
   storage._change_page(1)
   await frames()
   expect(storage.page == 1 and storage.selected_index == 8 and storage.grid.get_child(1).record_index == 9, "pagination exposes catches beyond the first eight")
   expect(storage.grid.get_child(2).disabled, "unused slots on the last page are disabled")
   await capture("fish-box-page-2")
   profile.data = original
   profile.changed.emit()
  storage._dispose(false)
  await frames()
  expect(inside(storage.detail.get_node("Confirm/No")), "release confirmation fits %s" % dimensions)
  storage._set_confirmation(false)
  storage.close()
  expect(paused, "close animation keeps gameplay paused")
  await create_timer(1.0, true).timeout
  expect(not paused and not storage.visible, "closing lid resumes gameplay")
 # Exercise transactions via the real UI buttons, including stale selection.
 hud.open_fish_storage()
 await create_timer(1.0, true).timeout
 var first_record: Dictionary = profile.data.catches[0].duplicate(true)
 var before_coins: int = profile.data.coins
 storage._select(0)
 storage.detail.get_node("Sell").pressed.emit()
 expect(profile.data.coins == before_coins + maxi(1, int(round(float(first_record.weight) * 35))), "sell selected fish credits exact amount")
 expect(profile.data.catches.size() == 2, "sale removes only selected fish")
 expect(not profile.dispose_stored_catch(0, first_record, true), "stale selection cannot sell a different fish")
 storage._select(0)
 storage.detail.get_node("Release").pressed.emit()
 expect(profile.data.catches.size() == 2, "release requires explicit confirmation")
 storage.detail.get_node("Confirm/Yes").pressed.emit()
 expect(profile.data.catches.size() == 1 and pond.fish.size() == original_population + 1, "confirmed release restores the actual source population")
 expect(profile.data.coins == before_coins + maxi(1, int(round(float(first_record.weight) * 35))), "release grants no sale coins")
 var reload_profile := AnglerProfile.new()
 reload_profile.save_path = profile.save_path
 root.add_child(reload_profile)
 expect(reload_profile.data.catches.size() == 1 and reload_profile.data.ponds.river.size() == pond.fish.size(), "inventory and returned population survive reload")
 reload_profile.queue_free()
 storage._select(0)
 var before := profile.data.duplicate(true)
 var valid_path := profile.save_path
 profile.save_path = "user://directory-that-does-not-exist/profile.cfg"
 storage._dispose(true)
 expect(profile.data == before, "failed sale save rolls back inventory and coins")
 profile.save_path = valid_path
 storage._dispose(true)
 expect(profile.data.catches.is_empty(), "last fish can be sold")
 await capture("fish-box-empty")
 # Cross-map release updates only the source map's saved population.
 var foreign := first_record.duplicate(true)
 foreign.map = "lotus_marsh"
 foreign.catch_id = "foreign-storage-test"
 expect(profile.keep_catch(foreign, "lotus_marsh", []), "store a catch from another map")
 var live_count := pond.fish.size()
 storage._select(0)
 storage._confirm_release()
 expect(profile.data.catches.is_empty() and profile.data.ponds.lotus_marsh.size() == 1 and pond.fish.size() == live_count, "foreign release restores source save without changing current pond")
 # Older catches remain usable even without the new simulation snapshot.
 var legacy_fish: FishState = pond.fish[0]
 var legacy := CatchSettlement.make_record(legacy_fish, profile, "river", "legacy-storage-test", "worm", 1.5, false, false)
 var remaining := pond.snapshot()
 remaining.pop_front()
 expect(profile.keep_catch(legacy, "river", remaining), "legacy catch without fish snapshot is accepted")
 pond.keep(legacy_fish)
 storage._select(0)
 storage._confirm_release()
 expect(profile.data.catches.is_empty() and pond.fish.size() == live_count, "legacy release recreates source fish with a unique identity")
 storage.close()
 await create_timer(1.0, true).timeout
 # Fight-specific info changes without modifying the fishing control scene.
 fishing.active_fish = pond.fish[0]
 fishing.fight.begin(fishing.active_fish)
 fishing._change_state(FishingController.State.FIGHT)
 hud._process(0.01)
 await frames()
 expect(not hud.get_node("SafeArea/BaitDock").visible and hud.meter.visible, "battle swaps bait controls for tension")
 expect(hud.meter.get_global_rect().end.x < hud.rod_joystick.get_global_rect().position.x, "linear tension meter sits left of unchanged rod joystick")
 await capture("hud-fight")
 scene.free()
 paused = false
 print("UI REFRESH RESULT: ", checks, " checks, ", failures, " failures")
 quit(1 if failures else 0)
