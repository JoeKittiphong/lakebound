extends SceneTree
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ",message)
 if not ok:failures+=1
func run() -> void:
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.save_path="user://bag-test.cfg"
 profile.data=profile.defaults()
 profile.data.coins=100000
 profile.incompatible=false
 profile.data.identity.name="Bag QA"
 root.get_node("AccountAuth")._offline_chosen=true
 profile.shopping_locked=true
 var before: Dictionary=profile.data.duplicate(true)
 check(not profile.buy("worm") and profile.data==before,"locked purchase changes neither wallet nor stock")
 profile.shopping_locked=false
 check(profile.buy("worm"),"menu purchase succeeds")
 var menu: Control=load("res://features/menu/main_menu_ui.tscn").instantiate()
 root.add_child(menu)
 root.size=Vector2i(1280,720)
 await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("user://bag-menu.png")
 menu.get_node("ShopPanel").open()
 await process_frame
 check(menu.get_node("ShopPanel").visible,"menu shop opens without fishing controller")
 menu.get_node("ShopPanel").close()
 menu.queue_free()
 await process_frame
 var game: Node3D=load("res://features/regions/lotus_marsh.tscn").instantiate()
 root.add_child(game)
 current_scene=game
 await process_frame
 check(profile.shopping_locked,"gameplay locks shopping")
 var hud: FishingHUD=game.get_node("HUD/FishingHUD")
 hud.open_tackle()
 await process_frame
 var shop: Control=hud.get_node("TacklePanel/Shop")
 hud.get_node("TacklePanel/DepthSettings/Slider").value=2.0
 check(is_equal_approx(game.fishing.selected_depth,2.0),"bag depth slider reaches fishing configuration")
 if DisplayServer.get_name()!="headless":
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("user://bag-owned.png")
 check(shop.inventory_only and not shop.inspector.get_node("%Buy").visible,"in-game bag hides purchase")
 check(shop.browser.items.all(func(item: TackleItem):return profile.quantity(str(item.id))>0 or (item.kind=="line" and profile.spare_line_count(str(item.id))>0)),"bag lists owned items only")
 hud.close_top_panel()
 hud.get_node("SafeArea/FirstCatch")._skip()
 var dock: Control=hud.get_node("SafeArea/BagDock")
 dock.session_fish=true
 for i in 9:dock.add_fish({"species":["tilapia","catfish","arowana","freshwater_eel"][i%4],"name":"test","weight":float(i+1)})
 dock.change_page(-20)
 check(dock.page==0,"fish pages clamp at beginning")
 await process_frame
 await process_frame
 for slot in dock.get_node("Equipment").get_children():
  if slot.name == "Boat":
   check(slot.get_node("Preview").model == null,"unowned boat slot stays empty")
   continue
  check(slot.icon==null and is_instance_valid(slot.get_node("Preview").model),"equipment slot contains a 3D model: "+str(slot.name))
 var preview: Control=dock.get_node("Fish/Slot0/Preview")
 check(preview.resource==FishCatalog.find(&"tilapia") and is_instance_valid(preview.model),"fish slot uses the species 3D scene")
 var original: Node3D=preview.model
 dock.refresh()
 check(preview.model==original,"refresh reuses unchanged 3D instances")
 dock.hide()
 check(preview.model==null and preview.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden dock releases models and stops rendering")
 dock.show()
 await process_frame
 await process_frame
 check(is_instance_valid(preview.model),"showing dock restores 3D previews")
 dock._start=Vector2(100,0)
 dock._finish(Vector2(20,0))
 check(dock.page==1,"left swipe advances fish page")
 dock._start=Vector2(20,0)
 dock._finish(Vector2(100,0))
 check(dock.page==0,"right swipe returns fish page")
 dock.change_page(20)
 check(dock.page==2,"fish pages clamp at last partial page")
 check(dock.get_node("Fish/Slot1/Preview").resource==null and dock.get_node("Fish/Slot1/Preview").model==null,"empty slots release the previous fish model")
 dock.change_page(-2)
 for width in [1280,1024,1600]:
  root.size=Vector2i(width,720)
  await process_frame
  await process_frame
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("user://bag-%d.png"%width)
 game.queue_free()
 await process_frame
 check(not profile.shopping_locked,"leaving gameplay unlocks purchases")
 print("BAG RESULT: ",failures," failures")
 quit(1 if failures else 0)

