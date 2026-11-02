extends SceneTree
var checks := 0
var failures := 0
var output := "res://exports/collection-book-ui-qa"
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ",message)
 if not ok: failures += 1
func frames(count := 6) -> void:
 for frame in count: await process_frame
func capture(name: String) -> void:
 await frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+'.png'))
func touch(point: Vector2, pressed: bool, finger := 4, canceled := false) -> void:
 var event := InputEventScreenTouch.new()
 event.index = finger
 event.position = point
 event.pressed = pressed
 event.canceled = canceled
 root.push_input(event,true)
func drag(point: Vector2, finger := 4) -> void:
 var event := InputEventScreenDrag.new()
 event.index = finger
 event.position = point
 root.push_input(event,true)
func tap(control: Control) -> void:
 var point := control.get_global_rect().get_center()
 touch(point,true)
 touch(point,false)
 await frames()
func swipe(start: Vector2, delta: Vector2) -> void:
 touch(start,true)
 drag(start+delta*.5)
 drag(start+delta)
 touch(start+delta,false)
 await frames()
func ready(panel: Control) -> void:
 for frame in 240:
  if panel.phase == "ready": return
  await process_frame
 expect(false,"book animation reached ready state")
func hidden(panel: Control) -> void:
 for frame in 240:
  if not panel.visible: return
  await process_frame
 expect(false,"book closing completed")
func run() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 var collection: Node = root.get_node("FishCollection")
 collection.recording_enabled = false
 collection.records.clear()
 for i in 12:
  collection.records[String(collection.SPECIES[i].id)] = {"count":i+1,"best":2.4+i*.1}
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = "user://book-ui-fixture.cfg"
 var game = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 for i in 20: await physics_frame
 game.get_node("FishingController").set_physics_process(false)
 var hud: FishingHUD = game.get_node("HUD/FishingHUD")
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 var panel: Control = hud.get_node("CollectionPanel")
 await tap(hud.get_node("SafeArea/TopBar/Actions/CollectionButton"))
 expect(paused and panel.phase == "opening", "HUD opens the 3D book and pauses gameplay")
 await ready(panel)
 expect(panel.rows.columns == 5 and panel.rows.get_child_count() == 15, "fish are arranged five per row, fifteen per page")
 expect(not panel.details.visible and panel.selected_species.is_empty(), "right page begins blank without an automatic selection")
 for ribbon in panel.get_node("Card/Content/MapTabs").get_children():
  expect(not "/" in ribbon.text and not "\n" in ribbon.text, "ribbons show names only, without collection counters")
 expect(panel.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS and panel.get_node("Motion").visible and not panel.get_node("Card").has_node("Paper"), "settled background is the real 3D book, without a replacement image")
 for tile in panel.rows.get_children():
  expect(not tile is PanelContainer and not tile.get_node("Content/Name").visible, "fish appear without visible card frames or captions")
 await capture("book-blank-details")
 await tap(panel.rows.get_child(0))
 expect(panel.details.visible and panel.selected_species == String(collection.SPECIES[0].id), "tapping a fish reveals its details")
 expect("2.40" in panel.details.get_node("Stats").text, "detail page uses real collection statistics")
 await capture("book-selected-fish")
 var point: Vector2 = panel.rows.get_child(3).get_global_rect().get_center()
 await swipe(point,Vector2(0,90))
 expect(panel.page == 0 and panel.phase == "ready", "vertical drags do not turn pages")
 await swipe(point,Vector2(-180,4))
 expect(panel.phase == "turning" and panel.selected_species == String(collection.SPECIES[0].id), "swipe starts the physical page turn without selecting the touched fish")
 expect(panel.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "3D rendering is active during the page turn")
 var active_ribbon: Button = panel.get_node("Card/Content/MapTabs/Tab0")
 expect(active_ribbon.get_theme_stylebox("disabled") == active_ribbon.get_theme_stylebox("pressed"), "selected ribbon keeps its artwork during a swipe")
 expect(panel.viewport.own_world_3d and panel.get_node("Card").visible and panel.model_mesh.visible, "the same isolated 3D book stays visible throughout a page turn")
 await capture("book-swipe-turn")
 await ready(panel)
 expect(panel.page == 1 and not panel.details.visible and panel.selected_species.is_empty(), "new page clears details and selection")
 expect(panel.rows.get_child(0).species_id == String(collection.SPECIES[15].id), "next page continues the catalog in order")
 point = panel.rows.get_child(1).get_global_rect().get_center()
 await swipe(point,Vector2(180,-2))
 await ready(panel)
 expect(panel.page == 0, "right swipe returns to the previous page")
 await swipe(point,Vector2(180,0))
 expect(panel.phase == "ready" and panel.page == 0, "swiping past the first page is bounded")
 point = panel.rows.get_child(0).get_global_rect().get_center()
 touch(point,true,4)
 drag(point+Vector2(-150,0),5)
 touch(point+Vector2(-150,0),false,5)
 touch(point,false,4,true)
 await frames()
 expect(panel.page == 0 and panel.selected_species.is_empty(), "unrelated fingers and canceled touches do not select or turn")
 await tap(panel.get_node("Card/Content/MapTabs/Tab2"))
 expect(panel.selected_map == "lotus_marsh" and panel.filtered_species.size() == 14, "ribbon selects the real map's species")
 await tap(panel.rows.get_child(0))
 expect(panel.details.get_node("Name").text == "ยังไม่ค้นพบ" and panel.details.get_node("Guide").text.is_empty(), "unknown species do not disclose names or fishing hints")
 profile.data.history.map_bests["lotus_marsh:tilapia"] = {"map":"lotus_marsh","species":"tilapia","weight":1.2}
 panel._refresh()
 for tile in panel.rows.get_children():
  if tile.species_id == "tilapia": await tap(tile)
 expect("1.20" in panel.details.get_node("Stats").text and not "2.40" in panel.details.get_node("Stats").text, "map detail retains separate per-map best weights")
 await tap(panel.get_node("Card/Content/Filters/OnlyMissing"))
 expect(panel.filtered_species.size() == 13 and not panel.details.visible, "missing-only filter clears the selected detail")
 await tap(panel.get_node("Card/Content/Filters/OnlyMissing"))
 await tap(panel.get_node("Card/Content/MapTabs/Tab0"))
 for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
  root.size = dimensions
  await frames()
  var left: Control = panel.get_node("Card/Content/Scroll")
  for tile in panel.rows.get_children():
   expect(left.get_global_rect().encloses(tile.get_global_rect()), "all fifteen fish fit the left page at " + str(dimensions))
   expect(tile.size.x >= 48 and tile.size.y >= 48, "fish remain touchable at " + str(dimensions))
  for tab in panel.get_node("Card/Content/MapTabs").get_children():
   expect(root.get_visible_rect().encloses(tab.get_global_rect()), "ribbon stays in viewport")
  await capture("book-layout-%d"%dimensions.x)
 root.size = Vector2i(1280,720)
 await frames()
 panel.close()
 expect(paused and panel.phase == "closing", "closing keeps gameplay paused until the cover settles")
 await hidden(panel)
 expect(not paused, "closed book restores gameplay")
 panel.open()
 panel.open()
 panel.close()
 await hidden(panel)
 expect(not paused and panel.phase == "hidden", "repeated open and close during opening resolves safely")
 panel.open()
 await ready(panel)
 await tap(panel.rows.get_child(0))
 await tap(panel.details.get_node("History"))
 expect(paused and hud.get_node("MapPanel").visible, "fish history opens the map without releasing the modal pause")
 await hidden(panel)
 expect(paused and hud.get_node("MapPanel").visible, "book closing does not unpause an open history map")
 hud.get_node("MapPanel").close()
 expect(not paused, "closing the history map restores gameplay")
 var configured: Control = load("res://features/collection/collection_panel.tscn").instantiate()
 configured.ribbon_maps = PackedStringArray(["", "river", "coral_coast"])
 configured.visible = false
 root.add_child(configured)
 expect(configured.get_node("Card/Content/MapTabs").get_child_count() == 3, "Inspector ribbon list can reduce or reorder map buttons")
 configured.select_map(2)
 expect(configured.selected_map == "coral_coast", "configured ribbon order resolves the correct map ID")
 expect(panel.get_node("Card/Content/MapTabs/Tab0").button_pressed, "separate books do not share ribbon selection state")
 configured.queue_free()
 await process_frame
 game.free()
 current_scene = null
 await process_frame
 print("BOOK UI RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
