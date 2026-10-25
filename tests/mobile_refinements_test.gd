extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
 call_deferred("run")
func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 failures += int(not ok)
func frames() -> void:
 for i in 8:
  await process_frame
func touch(down: bool, point: Vector2) -> void:
 var event := InputEventScreenTouch.new()
 event.index = 7
 event.pressed = down
 event.position = point
 root.push_input(event, true)
func swipe(point: Vector2) -> void:
 touch(true, point)
 for i in 6:
  var event := InputEventScreenDrag.new()
  event.index = 7
  event.position = point - Vector2(0, (i + 1) * 22)
  event.relative = Vector2(0, -22)
  event.velocity = Vector2(0, -300)
  root.push_input(event, true)
  await process_frame
 touch(false, point - Vector2(0, 132))
 await frames()
func run() -> void:
 var profile := root.get_node("AnglerSave") as AnglerProfile
 profile.save_path = "user://mobile-refinements-%d.cfg" % Time.get_ticks_usec()
 profile.data = profile.defaults()
 profile.start_missions()
 var panel: Control = load("res://features/missions/mission_panel.tscn").instantiate()
 root.add_child(panel)
 panel.bind(profile)
 panel.open()
 var scroll: ScrollContainer = panel.get_node("Card/Content/Scroll")
 for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1024, 768)]:
  root.size = viewport_size
  await frames()
  for region in ["Content/Description", "Content/Progress", "Content/Footer/Track"]:
   scroll.stop_scrolling()
   scroll.scroll_vertical = 0
   await frames()
   var row: Control = scroll.get_node("Rows").get_child(0)
   var target: Control = row.get_node(region)
   var point := target.get_global_rect().get_center()
   var tracked: String = profile.data.missions.tracked
   await swipe(point)
   var extent := scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page
   expect(scroll.scroll_vertical >= minf(50, extent) , "swipe over %s scrolls at %s" % [region, viewport_size])
   expect(str(profile.data.missions.tracked) == tracked, "drag does not activate mission button")
  scroll.stop_scrolling()
  scroll.scroll_vertical = 0
  await frames()
  var button: Button = scroll.get_node("Rows").get_child(0).get_node("Content/Footer/Track")
  var before_tap: String = profile.data.missions.tracked
  touch(true, button.get_global_rect().get_center())
  touch(false, button.get_global_rect().get_center())
  expect(str(profile.data.missions.tracked) != before_tap, "tap still toggles mission tracking")
  profile.data.missions.tracked = ""
  panel.refresh()
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("missions_swipe.png"))
 panel.close()
 panel.queue_free()
 var row: Control = load("res://features/economy/tackle_row.tscn").instantiate()
 root.add_child(row)
 var item := TackleCatalog.item("worm")
 row.buy_requested.connect(func(id: String): profile.buy(id))
 row.bind(item, profile)
 var quantity := profile.quantity("worm")
 var coins: int = profile.data.coins
 expect(not row.get_node("Buy").disabled, "bait buy button is available")
 row.get_node("Buy").pressed.emit()
 expect(profile.quantity("worm") == quantity + item.quantity and profile.data.coins == coins - item.price, "buy button adds exact bait pack and deducts price")
 profile.load_profile()
 expect(profile.quantity("worm") == quantity + item.quantity, "purchased bait survives reload")
 profile.data.coins = 0
 row.bind(item, profile)
 expect(row.get_node("Buy").disabled and not profile.buy("worm"), "insufficient coins block purchase")
 row.queue_free()
 profile.data = profile.defaults()
 root.size = Vector2i(1280, 720)
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 await frames()
 game.get_node("HUD/FishingHUD/SafeArea/FirstCatch")._skip()
 var shop: Control = game.get_node("HUD/FishingHUD/TacklePanel")
 shop.open()
 await frames()
 var buy: Button = shop.get_node("Card/Content/Tabs/Tackle/Scroll/Rows").get_child(0).get_node("Buy")
 quantity = profile.quantity("worm")
 for down in [true, false]:
  var click := InputEventMouseButton.new()
  click.position = buy.get_global_rect().get_center()
  click.button_index = MOUSE_BUTTON_LEFT
  click.pressed = down
  root.push_input(click, true)
  await process_frame
 expect(profile.quantity("worm") == quantity + item.quantity, "actual shop button purchases bait through panel signals")
 expect(root.get_visible_rect().encloses(buy.get_global_rect()), "bait price button fits the mobile shop")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("bait_shop.png"))
 shop.close()
 game.queue_free()
 await frames()
 print("MOBILE REFINEMENTS RESULT: ", checks, " checks, ", failures, " failures")
 quit(int(failures > 0))
