extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,message: String) -> void:
 checks+=1;print("PASS: " if ok else "FAIL: ",message)
 if not ok:failures+=1
func frames(count:=8) -> void:
 for i in count:await process_frame
func tap(control: Control) -> void:
 for down in [true,false]:
  var event:=InputEventScreenTouch.new();event.index=3;event.position=control.get_global_rect().get_center();event.pressed=down
  root.push_input(event,true)
 await frames()
func run() -> void:
 var profile: AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.data.coins=2000;profile.save_path="user://boat-shop.cfg";profile.shopping_locked=false
 var fishing:=FishingController.new();fishing.profile=profile
 var pond:=PondEcosystem.new();fishing.ecosystem=pond
 var gateway:=CommerceGateway.new()
 var panel: Control=load("res://features/economy/tackle_panel.tscn").instantiate()
 root.add_child(panel);panel.bind(profile,fishing,pond,gateway);panel.open_category(6)
 await frames(20)
 var shop: Control=panel.get_node("Shop")
 expect(shop.browser.items.size()==1 and shop.browser.items[0].id==&"lake_skiff","boat category exposes purchasable boat model")
 expect(shop.inspector.selected_item==TackleCatalog.item("lake_skiff"),"boat details are selected from catalog")
 expect(shop.inspector.get_node("%Buy").text.contains("1500") and not shop.inspector.get_node("%Buy").disabled,"shop shows real boat price and available purchase")
 expect(shop.browser.slots().any(func(slot:ShopShelfSlot):return slot.item!=null and slot.model!=null),"boat has a live three-dimensional shelf preview")
 await tap(shop.inspector.get_node("%Buy"))
 expect(profile.quantity("lake_skiff")==1 and profile.data.coins==500,"real touch on Buy purchases one boat")
 expect(shop.inspector.get_node("%Buy").disabled,"owned permanent boat cannot be bought again")
 await tap(shop.inspector.get_node("%Equip"))
 expect(profile.equipped("boat")==TackleCatalog.item("lake_skiff"),"real touch on Select equips purchased boat")
 for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(2400,1080)]:
  root.size=resolution;await frames()
  expect(panel.get_global_rect().encloses(shop.inspector.get_node("%Name").get_global_rect()),"boat name fits shop at "+str(resolution))
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("LAKEBOUND_QA_DIR").path_join("boat-shop-%dx%d.png"%[resolution.x,resolution.y]))
 panel.close();panel.queue_free();await frames(2)
 fishing.free();pond.free();gateway.free()
 print("BOAT SHOP RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
