extends SceneTree
const OUT:="res://../output/equipment-flow-v03/"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func expect(value:bool,label:String)->void:
 checks+=1
 if not value:failures+=1;push_error(label)
func settle()->void:
 await create_timer(.2).timeout
 for i in 3:await process_frame
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+name+".png")
func run()->void:
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.save_path=OUT+"qa.cfg";profile.grant_trial_equipment()
 var pond:=PondEcosystem.new();var fishing:=FishingController.new();fishing.profile=profile;fishing.ecosystem=pond
 var gateway:=CommerceGateway.new()
 var panel:Control=load("res://features/economy/tackle_panel.tscn").instantiate()
 root.add_child(panel);panel.bind(profile,fishing,pond,gateway);panel.open()
 var shop:Control=panel.get_node("Shop")
 var details:Control=shop.inspector
 for resolution in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2400,1080)]:
  root.size=resolution;shop.set_category(2);await settle()
  expect(details.visible and details.get_node("%Information").visible,"details are already open")
  expect(shop.browser.get_global_rect().end.x<=details.get_global_rect().position.x+1,"shelf never overlaps details")
  expect(root.get_visible_rect().encloses(details.get_global_rect()),"sidebar fits screen")
  expect(is_instance_valid(details.preview.instance),"selected model shown directly in list page")
  expect(not details.has_node("Floating/Info"),"no second details button")
  await capture("rods_%dx%d"%[resolution.x,resolution.y])
  shop.set_category(3);await settle()
  var rod_id:=str(profile.equipped("rod").id)
  for item:TackleItem in shop.browser.items:
   shop.browser.item_pressed.emit(item)
   expect(details.selected_item==item,"one tap selects reel in place")
   expect(details.get_node("%Information").visible,"details immediately visible")
   if not EquipmentFit.compatible(profile.equipped("rod"),item):
    expect(details.get_node("%Equip").disabled,"incompatible reel cannot equip")
    expect(details.get_node("%Status").text.contains("ใช้กับคัน:"),"incompatible reel explains matching rods")
    expect(str(profile.equipped("rod").id)==rod_id,"inspection never changes rod")
  await settle();await capture("reels_%dx%d"%[resolution.x,resolution.y])
  for category in [4,1]:
   shop.set_category(category)
   for item:TackleItem in shop.browser.items:
    shop.browser.item_pressed.emit(item)
    var reason:=profile.equipment_fit_error(item)
    if not reason.is_empty():expect(details.get_node("%Equip").disabled,"blocked line/bait cannot equip "+str(item.id))
    expect(details.selected_item==item,"same-page model selection "+str(item.id))
   await settle();await capture("category%d_%dx%d"%[category,resolution.x,resolution.y])
  shop.get_node("%Gear").pressed.emit();await settle()
  var loadout:Control=shop.get_node("%LoadoutView")
  expect(loadout.get_global_rect().end.x<=details.get_global_rect().position.x+1,"assembled set remains clear of details")
  var mounted:DetailedFishingRod=loadout.assembled_rod()
  var target:Vector2=loadout.camera.unproject_position(mounted.held_reel.get_node("ReelFoot").global_position)
  for pressed in [true,false]:
   var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed
   click.position=loadout.global_position+target*loadout.size/Vector2(loadout.viewport.size)
   root.push_input(click,true);await process_frame
  await settle()
  expect(shop.get_node("%Loadout").visible and details.selected_item==profile.equipped("reel"),"tap mounted reel changes inline details without leaving assembly")
  await capture("assembled_%dx%d"%[resolution.x,resolution.y])
  shop.get_node("%SelectReel").pressed.emit();await settle()
  expect(shop.category==3 and not shop.get_node("%Loadout").visible,"component opens list directly")
 # Follow the actual equip button flow, with trial-owned gear.
 shop.set_category(2);shop.browser.item_pressed.emit(TackleCatalog.item("cover_702mh"));await settle()
 expect(not details.get_node("%Equip").disabled,"trial-owned compatible rod selectable")
 details.get_node("%Equip").pressed.emit();await settle()
 expect(str(profile.equipped("rod").id)=="cover_702mh" and shop.category==3,"rod equips then advances to reel")
 var selected_reel:TackleItem
 for item:TackleItem in shop.browser.items:
  if EquipmentFit.compatible(profile.equipped("rod"),item) and str(item.id)!=str(profile.data.equipped.reel) and profile.quantity(str(item.id))>0:selected_reel=item;break
 expect(selected_reel!=null,"an alternative compatible owned reel is available")
 if selected_reel!=null:
  shop.browser.item_pressed.emit(selected_reel);details.get_node("%Equip").pressed.emit();await settle()
  expect(shop.category==4 and profile.equipped("reel")==selected_reel,"reel equips then advances to line")
 shop.set_category(4)
 for item:TackleItem in shop.browser.items:
  shop.browser.item_pressed.emit(item)
  if not details.get_node("%Equip").disabled:
   details.get_node("%Equip").pressed.emit();break
 await settle();expect(shop.category==1,"line equips then advances to bait")
 panel.close();expect(not is_instance_valid(details.preview.instance),"close releases inline model")
 panel.open();await settle();expect(details.visible,"reopening restores inline details")
 panel.close();panel.queue_free();fishing.free();pond.free();gateway.free();await process_frame
 print("EQUIPMENT FLOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
