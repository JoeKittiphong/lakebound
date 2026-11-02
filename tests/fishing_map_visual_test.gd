extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 failures += int(not ok)

func frames() -> void:
 for index in 5:
  await process_frame

func capture(name: String) -> void:
 await frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join(name+".png"))

func tap(control: Control, relative: Vector2 = Vector2(-1,-1)) -> void:
 var point := control.get_global_rect().get_center() if relative.x < 0 else control.global_position+relative
 var event := InputEventScreenTouch.new()
 event.index = 6
 event.pressed = true
 event.position = point
 root.push_input(event, true)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event, true)
 await frames()

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://map-visual.cfg"
 profile.data = profile.defaults()
 var collection := root.get_node("FishCollection")
 collection.recording_enabled = false
 var game: Node3D = load("res://features/regions/lotus_marsh.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 var hud: FishingHUD = game.get_node("HUD/FishingHUD")
 var panel: FishingMapPanel = hud.get_node("MapPanel")
 var mini: Button = hud.get_node("SafeArea/Minimap")
 var controller: FishingController = game.get_node("FishingController")
 game.get_node("FishingEffects").audio_enabled = false
 controller.set_physics_process(false)
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 await frames()
 await tap(mini)
 expect(panel.visible and paused, "real touch on minimap opens map and pauses session")
 expect(panel.records.is_empty() and panel.view._clusters.is_empty(), "new player sees full terrain without fabricated catch history")
 await capture("map-empty")
 panel.close()
 var fish := FishState.new()
 fish.species = load("res://data/fish/tilapia.tres")
 fish.weight = 1.42
 var actor: AnglerPlayer = game.get_node("Player")
 var original_position := actor.global_position
 actor.boat = game.get_node("FishingBoat")
 controller._change_state(FishingController.State.WAITING)
 controller.cast_position = Vector3(-45,1.5,16)
 controller._on_fish_biting(fish)
 actor.boat = null
 actor.position += Vector3(2,0,1)
 controller._change_state(FishingController.State.RESULT)
 controller.fish_landed.emit(fish)
 var landed: Dictionary = profile.data.journal[-1]
 expect(landed.location.angler_xz == Vector2(original_position.x,original_position.z) and landed.location.bite_xz == Vector2(-45,16) and landed.location.from_boat, "real landed signal persists frozen bite and vessel context")
 var count_after_landing: int = profile.data.journal.size()
 controller.fish_landed.emit(fish)
 expect(profile.data.journal.size() == count_after_landing, "repeated landed signal cannot duplicate journal history")
 controller.resolve_catch(false)
 expect(controller.state == FishingController.State.READY and profile.data.journal.size() == count_after_landing, "released fish keeps its journal location")
 actor.global_position = original_position
 for index in 12:
  var location := {"angler_xz":Vector2(-58+index*0.3,20),"bite_xz":Vector2(-45+index*0.3,16),"from_boat":false}
  var record := CatchSettlement.make_record(fish,profile,"lotus_marsh","map-"+str(index),"worm",1.5,false,false,location)
  profile.record_catch(record,false)
 var legacy := CatchSettlement.make_record(fish,profile,"lotus_marsh","old-map","worm",1.5,false,false)
 profile.record_catch(legacy,false)
 profile.add_fishing_spot("lotus_marsh",Vector2(-58,20))
 for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
  root.size = resolution
  await frames()
  await capture("minimap-"+str(resolution.x))
  expect(not mini.get_global_rect().intersects(hud.get_node("SafeArea/TopBar/Actions/FishBox").get_global_rect()), "minimap clears fish box at " + str(resolution))
  expect(not mini.get_global_rect().intersects(hud.get_node("SafeArea/TopBar/Actions/SettingsButton").get_global_rect()), "minimap clears Back at " + str(resolution))
  await tap(mini)
  await tap(panel.history_list, Vector2(80,50))
  panel._select({"kind":"catch","record":profile.data.journal[1]})
  await frames()
  var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
  for node_name in ["Regions","Close","MapView","Navigate","Favorite","Note","SaveNote"]:
   var control: Control = panel.get_node("%"+node_name)
   expect(bounds.encloses(control.get_global_rect()), node_name+" fits at "+str(resolution))
  expect(panel.view._clusters.size() < 12, "nearby history points cluster")
  await capture("map-history-"+str(resolution.x))
  panel.get_node("%Note").text = "ตรงนี้กัดดี ลองกลับมาตอนเย็น"
  await tap(panel.get_node("%SaveNote"))
  expect(profile.data.map_memory.notes.get("map-0","") == "ตรงนี้กัดดี ลองกลับมาตอนเย็น", "touch saves optional note")
  await tap(panel.get_node("%Navigate"))
  expect(not panel.visible and not paused and mini.target.position == Vector2(-58,20), "navigation targets saved standing position and resumes game")
  await tap(mini)
  panel._select({"kind":"catch","record":legacy})
  expect(panel.get_node("%Navigate").disabled and panel.get_node("%Favorite").disabled, "legacy history cannot invent a destination")
  panel.close()
 # Touch dragging must pan without accidentally bookmarking/selecting the release point.
 hud.open_map()
 panel.view.set_zoom(2)
 var start := panel.view.get_global_rect().get_center()
 var press := InputEventScreenTouch.new()
 press.index = 9
 press.pressed = true
 press.position = start
 root.push_input(press,true)
 var drag := InputEventScreenDrag.new()
 drag.index = 9
 drag.position = start+Vector2(50,30)
 drag.relative = Vector2(50,30)
 root.push_input(drag,true)
 press = press.duplicate()
 press.pressed = false
 press.position = drag.position
 root.push_input(press,true)
 expect(panel.view.pan.length() > 0 and panel.selected.is_empty(), "map drag pans and does not select a point")
 for index in RegionCatalog.MAPS.size():
  panel._region_selected(index)
  expect(panel.view.map_data.map_id == RegionCatalog.MAPS[index].id, "region picker loads correct map")
  await capture("map-region-"+RegionCatalog.MAPS[index].id)
 panel.close()
 # A real encyclopedia row opens a filtered map without unpausing between panels.
 collection.records[String(fish.species.id)] = {"count":1,"best":1.42,"smallest":1.42,"total":1.42,"last":1.42}
 hud.get_node("CollectionPanel").open()
 await create_timer(0.7).timeout
 await frames()
 var rows: GridContainer = hud.get_node("CollectionPanel/Card/Content/Scroll/Rows")
 await tap(rows.get_child(0))
 var history_button: Button = hud.get_node("CollectionPanel/Card/Content/DetailsFrame/History")
 expect(history_button.visible and not history_button.disabled, "selected discovered fish exposes its history action")
 expect(rows.get_child(0).get_node("Content/Preview").size.y >= 60, "fish portrait retains visible image space")
 await capture("collection-image-history")
 await tap(history_button)
 await create_timer(0.7).timeout
 expect(panel.visible and not hud.get_node("CollectionPanel").visible and paused and panel.species == String(fish.species.id), "collection shortcut opens filtered map in one continuous modal pause")
 panel.close()
 hud.open_map()
 await tap(panel.get_node("%Here"))
 var favorite_count: int = profile.data.map_memory.favorites.size()
 await tap(panel.get_node("%Here"))
 expect(profile.data.map_memory.favorites.size() == favorite_count, "repeated one-touch bookmark does not duplicate the spot")
 var saved_spot: Dictionary = profile.data.map_memory.favorites[-1]
 panel._select({"kind":"spot","spot":saved_spot})
 await tap(panel.get_node("%Favorite"))
 expect(profile.data.map_memory.favorites.size() == favorite_count-1, "favorite removal works through actual button touch")
 expect(panel.selected.is_empty() and panel.view.selection.is_empty(), "deleted favorite clears both details and map selection")
 panel._region_selected(0)
 expect(panel.get_node("%Here").disabled, "cannot bookmark current player into another region")
 panel.close()
 controller._change_state(FishingController.State.WAITING)
 hud.open_map()
 expect(paused and panel.visible, "waiting for a bite can safely open the paused map")
 panel.close()
 expect(not paused and controller.state == FishingController.State.WAITING, "closing waiting map preserves fishing state")
 controller.reset_cast()
 var boat: FishingBoat = game.get_node("FishingBoat")
 actor.global_position = boat.global_position + Vector3(0,1,0)
 expect(boat.board(actor), "real player can board boat for HUD layout check")
 for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
  root.size = resolution
  await frames()
  var actions: Control = hud.get_node("SafeArea/BoatActions")
  expect(actions.visible and not mini.get_global_rect().intersects(actions.get_global_rect()), "boat controls clear minimap at " + str(resolution))
  expect(not actions.get_global_rect().intersects(hud.get_node("SafeArea/MovementActions/Jump").get_global_rect()), "boat controls clear jump region at " + str(resolution))
 await capture("minimap-boat")
 controller._change_state(FishingController.State.BITE)
 hud.open_map()
 expect(not panel.visible and not paused, "map cannot interrupt bite window")
 controller.reset_cast()
 hud.open_map()
 game._on_back_pressed()
 expect(not panel.visible and not paused and current_scene == game, "Android/session Back closes map without leaving fishing")
 game.free()
 current_scene = null
 print("RESULT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
