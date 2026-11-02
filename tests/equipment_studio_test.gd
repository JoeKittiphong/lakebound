extends SceneTree
const OUT:="res://../output/equipment-studio-v02/"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func expect(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
func settle()->void:
 await create_timer(.18).timeout
 for i in 4:await process_frame
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+name+".png")
func model_fits(view:EquipmentModelPreview)->bool:
 if not is_instance_valid(view.instance):return false
 var bounds:=Rect2(Vector2.ZERO,Vector2(view.viewport.size)).grow(1)
 for point in view.framing_points():
  if not bounds.has_point(view.camera.unproject_position(point)):return false
 return true
func run()->void:
 root.size=Vector2i(1280,720)
 var profile:AnglerProfile=root.get_node("AnglerSave")
 profile.data=profile.defaults();profile.incompatible=false;profile.save_path=OUT+"qa_profile.cfg";profile.grant_trial_equipment();profile.equip("brook_702m")
 var pond:=PondEcosystem.new();var fishing:=FishingController.new();fishing.profile=profile;fishing.ecosystem=pond
 var gateway:=CommerceGateway.new()
 var panel:Control=load("res://features/economy/tackle_panel.tscn").instantiate();root.add_child(panel);panel.bind(profile,fishing,pond,gateway);panel.open()
 var shop:Control=panel.get_node("Shop")
 var inspector:Control=load("res://features/economy/equipment_inspector.tscn").instantiate()
 root.add_child(inspector);inspector.profile=profile
 inspector.buy_requested.connect(func(id:String):profile.buy(id))
 var view:EquipmentModelPreview=inspector.get_node("%Preview")
 for entry:TackleItem in TackleCatalog.ITEMS:
  inspector.open_item(entry);await settle()
  expect(not inspector.get_node("%Information").visible,"details hidden by default "+str(entry.id))
  expect(view.get_global_rect().size.is_equal_approx(root.get_visible_rect().size),"product view occupies entire screen "+str(entry.id))
  expect(model_fits(view),"entire product framed "+str(entry.id))
 var boxes:=JSON.parse_string(FileAccess.get_file_as_string(OUT+"box_manifest.json")) as Array
 profile.data.catches=[{"weight":26.0}]
 inspector.open_item(TackleCatalog.item("micro_box"));inspector.show_details();await settle()
 expect(inspector.get_node("%Equip").disabled and inspector.get_node("%Status").text.contains("เกิน"),"too-small fish box explains capacity block before equipping")
 profile.data.catches=[]
 expect(boxes.size()==6,"six authored fish box variants")
 var last_width:=0.0
 for box:Dictionary in boxes:
  expect(box.audit.evaluated_triangles<=500,"complete low polygon cooler "+box.id)
  expect(box.dimensions[0]>last_width,"box width increases by capacity "+box.id);last_width=box.dimensions[0]
 for dimensions in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2400,1080)]:
  root.size=dimensions
  for id in ["brook_702m","spinning_reel","worm","xl_box"]:
   inspector.open_item(TackleCatalog.item(id));await settle()
   expect(model_fits(view),"full product remains visible "+id+str(dimensions))
   expect(view.get_global_rect().position.is_zero_approx(),"no fixed header/footer gutters")
   if id in ["brook_702m","xl_box"]:await capture(id+"_full_%dx%d"%[dimensions.x,dimensions.y])
   inspector.show_details();await settle()
   var info:Control=inspector.get_node("%Information")
   expect(view.get_global_rect().end.x<=info.get_global_rect().position.x+1,"details panel never covers model viewport "+id)
   expect(root.get_visible_rect().encloses(info.get_global_rect()),"details panel remains within screen")
   expect(model_fits(view),"model refits beside details "+id)
   if id in ["brook_702m","xl_box"]:await capture(id+"_details_%dx%d"%[dimensions.x,dimensions.y])
  inspector.close();shop.get_node("%Gear").pressed.emit();await settle()
  var loadout:EquipmentLoadoutView=shop.get_node("%LoadoutView")
  expect(loadout.get_global_rect().end.x<=shop.inspector.get_global_rect().position.x+1,"assembled model clear of inline sidebar")
  var assembled:=loadout.assembled_rod()
  expect(is_instance_valid(assembled.held_reel),"actual mounted equipped reel")
  expect(loadout.slots.get_node("Reel").model==null and loadout.slots.get_node("Line").model==null,"no exploded reel or spool")
  await capture("equipped_%dx%d"%[dimensions.x,dimensions.y])
  shop.get_node("%LoadoutSettings").pressed.emit();await settle()
  expect(loadout.get_global_rect().end.x<=shop.get_node("%RigPanel").get_global_rect().position.x+1,"rig settings never cover loadout models")
  shop.get_node("%CloseRig").pressed.emit();shop.get_node("%CloseLoadout").pressed.emit()
 root.size=Vector2i(1280,720);panel.open_category(5);await settle();await capture("six_box_shelf")
 var previous_box_width:=0.0
 for slot:ShopShelfSlot in shop.browser.slots():
  if slot.item==null:continue
  var width:=slot.local_bounds().size.x
  expect(width>previous_box_width,"box shelf preserves comparative physical size")
  previous_box_width=width
 for id in ["micro_box","small_box","medium_box","large_box","xl_box","expedition_box"]:
  inspector.open_item(TackleCatalog.item(id));await settle();await capture("box_"+id)
 inspector.show_details();await settle()
 var before:int=profile.data.coins
 inspector.get_node("%Buy").pressed.emit()
 expect(profile.data.coins==before,"owned durable box cannot be bought again by enabled UI")
 inspector.close();profile.equip("lotus_450m");shop.get_node("%Gear").pressed.emit();await settle()
 expect(shop.get_node("%LoadoutView").slots.get_node("Reel").model==null,"fixed pole never pretends unused reel is active")
 inspector.close();panel.close();await settle()
 expect(not is_instance_valid(view.instance) and shop.get_node("%LoadoutView").viewport.size==Vector2i(2,2),"closing releases product and equipped models")
 inspector.queue_free();panel.queue_free();fishing.free();pond.free();gateway.free();await process_frame
 var file:=FileAccess.open(OUT+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("EQUIPMENT STUDIO: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
