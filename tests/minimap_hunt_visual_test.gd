extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok: failures += 1

func frames(count := 5) -> void:
 for i in count: await process_frame

func tap(control: Control) -> void:
 var point := control.get_global_rect().get_center()
 for down in [true, false]:
  var event := InputEventScreenTouch.new()
  event.index = 8; event.pressed = down; event.position = point
  root.push_input(event, true)
 await frames(2)

func fish_at(weight: float, point: Vector2) -> FishState:
 var fish := FishState.new()
 fish.species = load("res://data/fish/tilapia.tres")
 fish.weight = weight
 fish.position = Vector3(point.x, 2, point.y)
 return fish

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join(label + ".png"))

func run() -> void:
 root.get_node("FishCollection").recording_enabled = false
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = "user://minimap-hunt-profile.cfg"
 var game = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled = true
 root.add_child(game); current_scene = game
 game.get_node("FishingEffects").audio_enabled = false
 game.get_node("FishingController").set_physics_process(false)
 var pond: PondEcosystem = game.get_node("PondEcosystem")
 pond.set_physics_process(false)
 var player: AnglerPlayer = game.get_node("Player")
 player.set_physics_process(false)
 var hud: FishingHUD = game.get_node("HUD/FishingHUD")
 hud.get_node("SafeArea/FirstCatch")._skip()
 var mini = hud.get_node("SafeArea/Minimap")
 var panel: FishingMapPanel = hud.get_node("MapPanel")
 await frames(15)
 var palette: Resource = mini.view.scan_palette
 for entry in [[0.01,0],[0.999,0],[1.0,1],[4.999,1],[5.0,2],[19.999,2],[20.0,3],[200.0,3]]:
  expect(palette.classify(entry[0]) == entry[1], "absolute weight boundary %.3f kg" % entry[0])
 expect(palette.classify(0.01,true) == 4, "boss overrides ordinary weight band")
 var colors: Array[Color] = []
 for tier in 5:
  var color: Color = palette.color_for(tier)
  expect(not colors.has(color), "tier %d has a distinct color" % tier)
  colors.append(color)
  var label: Label = mini.get_node("ScanLegend/Content").get_child(tier+1)
  expect(label.text == palette.legend_for(tier) and label.get_theme_color("font_color") == color, "legend matches the marker palette")
 var origin := Vector2(player.position.x,player.position.z)
 var small := fish_at(.5,origin+Vector2(-50,-30))
 var medium := fish_at(2,origin+Vector2(-20,-55))
 var large := fish_at(10,origin+Vector2(35,-50))
 var colossal := fish_at(30,origin+Vector2(60,0))
 var boss := fish_at(50,origin+Vector2(180,0))
 pond.fish.assign([small,medium,large,colossal,boss])
 pond.population_changed.emit()
 expect(mini.view.fish_positions.is_empty() and mini.view.fish_tiers.is_empty() and not mini.get_node("ScanLegend").visible, "no echoes or legend before scanning")
 await tap(mini.get_node("HelpButton"))
 expect(mini.get_node("ScanLegend").visible and mini._scan_remaining == 0 and not panel.visible and not paused, "question mark opens help without scanning or opening the large map")
 await tap(mini.get_node("HelpButton"))
 expect(not mini.get_node("ScanLegend").visible, "question mark closes help on second touch")
 await tap(mini.get_node("ScanButton"))
 expect(mini.view.fish_tiers == PackedInt32Array([0,1,2,3]), "out-of-range boss stays hidden; nearby largest is colossal, not boss")
 expect(not panel.visible and not paused, "scan touch leaves gameplay active")
 expect(not mini.get_node("ScanLegend").visible, "scanning leaves the color key collapsed")
 await tap(mini.get_node("HelpButton"))
 expect(mini.get_node("ScanLegend").visible, "question mark opens the color key during scan")
 boss.position.x = origin.x + 75
 mini._process(.11)
 expect(not mini.view.fish_tiers.has(4), "unscanned boss entering the radius stays hidden until another scan")
 await tap(mini.get_node("ScanButton"))
 expect(mini.view.fish_tiers == PackedInt32Array([0,1,2,3,4]), "rescan reveals all five tiers including actual boss")
 boss.position.z -= 10
 mini._process(.11)
 expect(mini.view.fish_positions.has(Vector2(boss.position.x,boss.position.z)), "scanned boss follows its real movement")
 for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(2400,1080)]:
  root.size = resolution
  await frames()
  mini.scan_fish()
  var legend: Control = mini.get_node("ScanLegend")
  expect(hud.get_global_rect().encloses(legend.get_global_rect()), "legend fits viewport %s" % resolution)
  for path in ["SafeArea/RankingButton","SafeArea/TopBar","SafeArea/MoveJoystick","SafeArea/MovementActions/LeftActions"]:
   expect(not legend.get_global_rect().intersects(hud.get_node(path).get_global_rect()), "legend clears %s at %s" % [path,resolution])
  for child in mini.get_node("ScanLegend/Content").get_children():
   expect(legend.get_global_rect().encloses(child.get_global_rect()), "legend text fits its panel")
  await capture("scan-five-tiers-%dx%d" % [resolution.x,resolution.y])
 # Expired detections cannot be recovered just by walking closer.
 mini._process(mini.scan_duration + .1)
 expect(mini.view.fish_positions.is_empty() and mini.view.fish_tiers.is_empty() and mini.get_node("ScanLegend").visible, "expiry removes echoes while leaving requested help readable")
 await tap(mini.get_node("HelpButton"))
 expect(not mini.get_node("ScanLegend").visible, "help can be closed after scan expiry")
 player.position.x += 50
 mini._process(.11)
 expect(mini.view.fish_positions.is_empty(), "walking after expiry cannot reveal the boss")
 await tap(mini.get_node("ScanButton"))
 expect(mini.view.fish_tiers.has(4), "walking and scanning again can locate the boss")
 pond.keep(boss)
 expect(not mini.view.fish_positions.has(Vector2(boss.position.x,boss.position.z)), "caught boss is removed immediately")
 expect(mini.view.fish_tiers.has(4), "current heaviest detected survivor becomes boss")
 var promoted_index: int = mini.view.fish_positions.find(Vector2(colossal.position.x,colossal.position.z))
 expect(promoted_index >= 0 and mini.view.fish_tiers[promoted_index] == 4, "boss promotion uses ecosystem identity")
 mini.bind(player,"river",pond)
 expect(mini.view.fish_tiers.is_empty() and not mini.get_node("ScanLegend").visible, "map bind clears classified detections")
 await tap(mini.get_node("ScanButton"))
 await tap(mini)
 expect(panel.visible and paused, "large map still opens from minimap")
 expect(panel.find_children("Boss*","",true,false).is_empty(), "large map has no boss card or labels")
 var property_names: Array = []
 for property in panel.view.get_property_list(): property_names.append(property.name)
 expect(not property_names.has("boss"), "large map view has no boss coordinate channel")
 for region in RegionCatalog.MAPS.size():
  panel._region_selected(region)
  expect(not "จ้าวบ่อ" in panel.get_node("SafeArea/Content/Body/MapColumn/Legend").text, "no boss symbol in region legend")
  var world_point: Vector2 = panel.view.map_data.bounds.get_center()
  panel.view._pick(panel.view.project(world_point))
  expect(panel.view.selection.get("kind") == "point", "large map cannot pick a live/saved boss")
 await capture("large-map-without-boss")
 panel.close()
 expect(not paused, "closing large map resumes gameplay")
 pond.fish.clear(); pond.population_changed.emit()
 mini.scan_fish()
 expect(mini.view.fish_positions.is_empty() and mini.view.fish_tiers.is_empty(), "empty population invents no boss")
 game.queue_free(); await frames(2)
 print("MINIMAP HUNT RESULT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
