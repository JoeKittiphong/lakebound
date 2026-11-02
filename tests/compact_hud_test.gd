extends SceneTree

var failures := 0
var checks := 0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1
func settle() -> void:
 for frame in 5: await process_frame
func capture(name: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR")+"/"+name+".png")
func tap(node: Control) -> void:
 var event := InputEventScreenTouch.new()
 event.index = 9
 event.position = node.get_global_rect().get_center()
 event.pressed = true
 root.push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event,true)
 await settle()
func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = "user://compact-hud-test.cfg"
 profile.incompatible = false
 var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingEffects").audio_enabled = false
 for frame in 20: await physics_frame
 var controller: FishingController = scene.get_node("FishingController")
 controller.set_physics_process(false)
 var hud: FishingHUD = scene.get_node("HUD/FishingHUD")
 hud.get_node("SafeArea/FirstCatch").active = false
 hud.get_node("SafeArea/FirstCatch").hide()
 hud.update_wallet(12345,27)
 var actions := hud.get_node("SafeArea/TopBar/Actions")
 expect(hud.get_node("SafeArea/TopBar/Actions/Wallet/Coins/Amount").text == "12.3K" and hud.get_node("SafeArea/TopBar/Actions/Wallet/Gems/Amount").text == "27", "currency amounts bind separately with compact large balances")
 expect(not hud.has_node("SafeArea/BackButton") and not hud.has_node("SafeArea/EcologyButton"), "back and help consolidated into settings")
 for asset in ["shop", "coin", "diamond", "case", "mission", "collections", "setting"]:
  var texture: Texture2D = load("res://assets/ui/hud_affinity/" + asset + ".png")
  expect(texture != null and texture.get_width() > 100, asset + " Affinity export imports")
 var box: FishBoxView = actions.get_node("FishBox")
 box._invalidate()
 box.refresh_if_needed()
 expect(box.get_node("Row/Icon").texture == box.icon_override and box.icon_override != null, "equipment refresh preserves the exported cooler icon")
 expect(box.get_node("Row/Info/Weight").modulate == Color.WHITE, "capacity text remains white after refresh")
 expect(actions.get_node("Wallet/Coins/Icon").position.y < actions.get_node("Wallet/Coins/Amount").position.y, "currency amount is below its icon")
 expect(actions.get_node("MissionButton").text.is_empty(), "mission uses the reference icon without a caption")
 for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
  root.size = resolution
  await settle()
  expect(actions.get_child(0).name == "TackleButton" and actions.get_child(1).name == "Wallet", "wallet follows shop in the same row")
  expect(not hud.has_node("SafeArea/VectorPanel"), "top icons have no panel background")
  expect(actions.get_global_rect().size.x <= 544 and actions.get_global_rect().size.y <= 78, "compact toolbar uses less gameplay space")
  var previous: Control
  for control in actions.get_children():
   expect(control.get_global_rect().size.x >= 44 and control.get_global_rect().size.y >= 44,"touch target at "+str(resolution))
   expect(hud.get_global_rect().encloses(control.get_global_rect()),"action stays in viewport")
   if previous != null:
    expect(not previous.get_global_rect().intersects(control.get_global_rect()),"actions have separate touch regions")
   previous = control
  expect(not hud.get_node("SafeArea/Minimap").get_global_rect().intersects(actions.get_global_rect()),"minimap stays unobstructed")
  expect(not hud.get_node("SafeArea/BossToast").get_global_rect().intersects(hud.get_node("SafeArea/TopBar").get_global_rect()), "boss status does not overlap the taller reference HUD")
  expect(hud.get_node("SafeArea/Status").position.y <= 12, "fishing announcement is authored at the safe top; top bar hides during fishing")
  expect(hud.get_node("SafeArea/TopBar").get_global_rect().encloses(actions.get_global_rect()), "reference composition fits the top HUD region")
  var ranking_button: Control = hud.get_node("SafeArea/RankingButton")
  expect(not ranking_button.get_global_rect().intersects(hud.get_node("SafeArea/MissionTracker").get_global_rect()), "mission tracker cannot cover ranking button")
  expect(hud.get_global_rect().encloses(ranking_button.get_global_rect()) and not ranking_button.get_global_rect().intersects(hud.get_node("SafeArea/Minimap").get_global_rect()), "map ranking touch target fits below minimap")
  await capture("compact-hud-"+str(resolution.x))
  if resolution == Vector2i(1280,720):
   hud.set_process(false)
   hud.update_wallet(100000,100000)
   box.get_node("Row/Info/Weight").text = "20.5/300"
   expect(actions.get_node("Wallet/Coins/Amount").text == "100K" and actions.get_node("Wallet/Gems/Amount").text == "100K", "reference balances display as 100K")
   await capture("reference-values")
   hud.update_wallet(profile.data.coins,profile.data.diamonds)
   box._invalidate()
   hud.set_process(true)
 root.size = Vector2i(1280,720)
 await settle()
 profile.data.identity.name = "Map tester"
 var ranking: Control = hud.get_node("SocialPanel")
 ranking.sheets_url = ""
 await tap(hud.get_node("SafeArea/RankingButton"))
 expect(paused and ranking.visible and ranking.can_process(), "touch ranking opens a processable modal while gameplay pauses")
 expect(str(ranking.get_node("%Filter").get_item_metadata(ranking.get_node("%Filter").selected)) == str(controller.map_id), "touch ranking selects current gameplay map")
 await capture("map-ranking-open")
 await tap(ranking.get_node("%Close"))
 expect(not paused and not ranking.visible, "touch Close restores gameplay from paused ranking")
 await tap(actions.get_node("TackleButton"))
 expect(paused and hud.get_node("TacklePanel").visible,"touch shop opens and pauses play")
 hud.close_top_panel()
 await settle()
 await tap(actions.get_node("FishBox/Open"))
 expect(paused and hud.get_node("FishStoragePanel").visible,"touch cooler opens storage")
 hud.close_top_panel()
 await hud.get_node("FishStoragePanel").closed
 await settle()
 await tap(actions.get_node("MissionButton"))
 expect(paused and hud.get_node("MissionPanel").visible,"mission button still opens missions")
 hud.close_top_panel()
 await settle()
 await tap(actions.get_node("CollectionButton"))
 expect(paused and hud.get_node("CollectionPanel").visible,"collection button still opens journal")
 hud.close_top_panel()
 await hud.get_node("CollectionPanel").closed
 await settle()
 await tap(actions.get_node("SettingsButton"))
 var settings: GameSettingsPanel = hud.get_node("GameSettingsPanel")
 expect(paused and settings.visible,"touch settings opens modal and pauses play")
 await capture("compact-settings")
 await tap(settings.get_node("%Help"))
 expect(settings.get_node("%HelpView").visible and settings.get_node("%Instructions").text.length()>100 and paused,"help displays instructions inside settings")
 await capture("compact-help")
 await tap(settings.get_node("%BackToSettings"))
 expect(settings.get_node("%Menu").visible,"help returns to settings")
 settings.get_node("%Volume").value = 37
 expect(is_equal_approx(AudioServer.get_bus_volume_linear(0),0.37),"volume changes master audio")
 await tap(settings.get_node("%Resume"))
 expect(not paused and not settings.visible,"resume restores gameplay")
 var config := ConfigFile.new()
 expect(config.load(GameSettingsPanel.SAVE_PATH)==OK and is_equal_approx(config.get_value("audio","volume"),0.37),"volume persists to settings config")
 paused = true
 settings.open()
 settings.close()
 expect(paused,"settings preserves existing external pause")
 paused = false
 var menu_events: Array[bool] = []
 hud.back_requested.connect(func(): menu_events.append(not settings.visible and not paused))
 # Disconnect scene navigation so the fixture can inspect the transition.
 for connection in hud.back_requested.get_connections():
  if connection.callable.get_object() == scene: hud.back_requested.disconnect(connection.callable)
 settings.open()
 await tap(settings.get_node("%Home"))
 expect(menu_events == [true],"home closes modal and restores pause before navigation")
 scene.free()
 current_scene = null
 await process_frame
 print("COMPACT HUD RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
