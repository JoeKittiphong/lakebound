extends SceneTree
var checks:=0
var failures:=0
const OUT:="res://../output/showroom-shop-v01/"
func _initialize()->void:call_deferred("run")
func expect(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
func settle()->void:
 await create_timer(.25).timeout
 for i in 3:await process_frame
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+name+".png")
func live(browser:ShopShelfBrowser)->int:
 var total:=0
 for parent in [browser.display.get_node("RodSlots"),browser.display.get_node("DisplaySlots")]:
  for slot:ShopShelfSlot in parent.get_children():total+=int(is_instance_valid(slot.model))
 return total
func run()->void:
 root.size=Vector2i(1280,720)
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.save_path=OUT+"qa_profile.cfg";profile.incompatible=false
 var pond:=PondEcosystem.new()
 var fishing:=FishingController.new();fishing.profile=profile;fishing.ecosystem=pond
 var gateway:=CommerceGateway.new()
 var panel:Control=load("res://features/economy/tackle_panel.tscn").instantiate()
 root.add_child(panel);panel.bind(profile,fishing,pond,gateway);panel.open()
 await settle()
 var shop:Control=panel.get_node("Shop")
 var browser:ShopShelfBrowser=shop.get_node("%Shelf")
 expect(browser.items.size()==29 and browser.page_count()==ceili(29.0/browser.page_size),"all rods occupy responsive shelves")
 expect(not panel.has_node("Card/Content/Tabs"),"old shop tab stack removed")
 expect(live(browser)==browser.page_size,"one physical shelf loads only the items that fit")
 var ids:={}
 for page in browser.page_count():
  browser.change_page(page-browser.page,false);await settle()
  for slot:ShopShelfSlot in browser.slots():
   if slot.item==null:continue
   expect(not ids.has(str(slot.item.id)),"rod occurs once "+str(slot.item.id));ids[str(slot.item.id)]=true
   var box:=slot.local_bounds()
   expect(box.size.y<=browser.rod_display_height+.02 and box.position.y>=-.01,"rod rests upright within shelf "+str(slot.item.id))
   var shape:CollisionShape3D=slot.get_node("Hit/Shape")
   var point:=browser.camera.unproject_position(shape.global_position)
   expect(browser.pick(point)==slot.item,"tap selects physical slot "+str(slot.item.id))
   if slot.model is FishingRodVisual:
    var tip_pixel:=browser.camera.unproject_position(slot.model.tip.global_position)
    expect(Rect2(Vector2.ZERO,Vector2(browser.viewport.size)).has_point(tip_pixel),"rod tip stays visible "+str(slot.item.id)+" "+str(tip_pixel))
  expect(live(browser)<=12,"paging never keeps whole catalog instantiated")
 expect(ids.size()==29,"every rod remains reachable by swiping")
 browser.change_page(-100,false);await settle()
 expect(browser.page==0,"first shelf clamps")
 browser._begin(Vector2(500,200));browser._drag(Vector2(180,202));browser._end(Vector2(180,202));await create_timer(.6).timeout
 expect(browser.page==1,"horizontal drag changes shelf")
 expect(shop.inspector.visible,"swipe keeps inline details visible")
 browser.change_page(-1,false);await settle()
 var slot:ShopShelfSlot=browser.slots()[0]
 var tap:=browser.camera.unproject_position(slot.get_node("Hit/Shape").global_position)
 for pressed in [true,false]:
  var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed
  click.position=browser.global_position+tap*browser.size/Vector2(browser.viewport.size)
  root.push_input(click,true);await process_frame
 await settle()
 var inspector:Control=shop.inspector
 var preview:EquipmentModelPreview=inspector.get_node("%Preview")
 expect(inspector.visible and inspector.selected_item==slot.item,"tap opens item with details below")
 expect(is_instance_valid(preview.instance),"detail window loads actual rod")
 var start:=preview.pivot.rotation
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;preview._gui_input(down)
 var drag:=InputEventMouseMotion.new();drag.relative=Vector2(25,10);preview._gui_input(drag)
 expect(not preview.pivot.rotation.is_equal_approx(start),"detail drag rotates")
 var position:=preview.pivot.position;preview.pan_view(Vector2(30,20))
 expect(not preview.pivot.position.is_equal_approx(position),"detail supports pan")
 var zoom:=preview.camera.size;preview._set_zoom(.5)
 expect(preview.camera.size<zoom,"detail supports zoom")
 preview.reset_view();expect(preview.pivot.position.is_zero_approx(),"reset recovers panned model")
 await capture("rod_detail")
 panel.close_top_layer()
 expect(not panel.visible,"Back closes the single equipment screen")
 panel.open_category(2);await settle()
 for dimensions in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2400,1080)]:
  root.size=dimensions;await settle()
  expect(root.get_visible_rect().encloses(browser.get_global_rect()),"shelf fits viewport "+str(dimensions))
  expect(browser.get_global_rect().position.is_equal_approx(Vector2.ZERO) and browser.get_global_rect().end.x<=inspector.get_global_rect().position.x+1,"3D shelf and details have separate screen areas "+str(dimensions))
  expect(root.get_visible_rect().encloses(shop.get_node("%Gear").get_global_rect()),"header fits viewport "+str(dimensions))
  await capture("rods_%dx%d"%[dimensions.x,dimensions.y])
 root.size=Vector2i(1280,720)
 for category in [3,1,4,5]:
  panel.open_category(category);await settle()
  expect(live(browser)>0 and live(browser)<=12,"category uses real shelf "+str(category))
  for entry in browser.items:expect(entry.model_scene!=null,"all shelf products have models "+str(entry.id))
  await capture("zone_"+str(category))
 shop.get_node("%Owned").button_pressed=true;await settle()
 expect(browser.items.size()==1,"owned filter shows only owned bucket")
 shop.get_node("%Owned").button_pressed=false
 panel.open_category(2);await settle()
 inspector.open_item(TackleCatalog.item("brook_562ul"));await settle()
 var coins:int=profile.data.coins
 inspector.get_node("%Buy").pressed.emit()
 expect(profile.quantity("brook_562ul")==1 and profile.data.coins==coins-TackleCatalog.item("brook_562ul").price,"detail buy uses persistent transaction")
 inspector.get_node("%Equip").pressed.emit()
 expect(profile.equipped("rod").id==&"brook_562ul","detail equip updates actual loadout")
 inspector.open_item(TackleCatalog.item("minnow"));await settle()
 expect(inspector.get_node("%Equip").disabled,"invalid lure is still blocked in new design")
 inspector.close();shop.get_node("%Gear").pressed.emit();await settle()
 expect(shop.get_node("%Loadout").visible and shop.get_node("%Rig").item_count>0,"rig setup moved into loadout drawer")
 expect(shop.pop_layer() and not shop.get_node("%Loadout").visible,"Back closes drawer before shop")
 shop._more(10);await settle()
 expect(shop.get_node("%Journal").visible,"journal remains in secondary menu")
 shop.pop_layer()
 profile.data.pending={"id":"qa","lure":"minnow","cost":TackleCatalog.item("minnow").recovery_cost}
 shop.enter();await settle()
 expect(shop.get_node("%Recovery").visible,"pending lure recovery remains accessible")
 shop.get_node("%Discard").pressed.emit()
 expect(profile.data.pending.is_empty() and not shop.get_node("%Recovery").visible,"discard resolves persistent recovery")
 panel.close();await settle()
 expect(live(browser)==0 and browser.viewport.size==Vector2i(2,2),"closing shop releases shelf models and render target")
 expect(ProfileStore.valid(profile.data),"new design keeps save schema valid")
 panel.queue_free();fishing.free();pond.free();gateway.free();await process_frame
 var file:=FileAccess.open(OUT+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("SHOWROOM SHOP: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
