extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func check(ok: bool,label: String) -> void:
 print("PASS: " if ok else "FAIL: ",label)
 failures += int(not ok)

func frames() -> void:
 for i in 6: await process_frame

func run() -> void:
 var preview: Control = load("res://tests/previews/fishing_methods_preview.tscn").instantiate()
 root.add_child(preview)
 var view: Control = preview.get_node("Margin/Content/Methods")
 var profile: AnglerProfile = preview.sample_profile
 var before := profile.data.duplicate(true)
 check(view.get_node("%Maps").tab_count==6,"one tab per real map")
 check(view.groups.size()==4,"left list contains only species caught in selected map")
 check(view.get_node("%FishRows").columns==3,"fish gallery has three columns")
 check(not view.get_node("%Detail").visible,"details wait until a fish is clicked")
 check(not view.get_node("%FishRows").get_child(0).has_node("Row/Text/Meta"),"fish tile shows only picture and name")
 var index := -1
 for i in view.groups.size():
  if view.groups[i].species=="tilapia": index=i
 check(index>=0 and view.groups[index].records.size()==2,"repeated species grouped with separate catch histories")
 view.get_node("%FishRows").get_child(index).pressed.emit()
 check(view.records.size()==2 and "1.80" in view.get_node("%CatchInfo").text,"select fish shows its latest capture")
 check(view.get_node("%Bait").text==TackleCatalog.item("worm").display_name.get_slice(" ×",0),"bait resolved from captured bait ID without shop pack quantity")
 view.get_node("%Capture").select(1)
 view.get_node("%Capture").item_selected.emit(1)
 check(view.get_node("%Bait").text==TackleCatalog.item("dough").display_name.get_slice(" ×",0) and view.get_node("%Depth").text=="0.8 ม.","older capture keeps its own equipment and depth")
 check(view.get_node("%Brake").text=="40%","brake shown from selected record")
 check(profile.data==before,"view never mutates saved journal")
 check(FishingMethods.setting({"settings":{"drag_strength":0}},"drag_strength","%") == "0%","zero adjustment is not treated as missing")
 check(FishingMethods.setting({},"drag_strength","%") == "ไม่ได้บันทึก","legacy record never invents missing adjustment")
 check(FishingMethods.setting({"settings":"invalid"},"drag_strength","%") == "ไม่ได้บันทึก","bad optional legacy settings are handled")
 DirAccess.make_dir_recursive_absolute("res://exports/qa-fishing-methods")
 if DisplayServer.get_name()!="headless":
  for dimensions in [Vector2i(1280,720),Vector2i(1024,768)]:
   root.size=dimensions
   view._select_species(index)
   await frames()
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://exports/qa-fishing-methods/journal-%dx%d.png"%[dimensions.x,dimensions.y])
   check(root.get_visible_rect().encloses(view.get_global_rect()),"journal fits %s"%dimensions)
   for tile: Button in view.get_node("%FishRows").get_children():
    check(tile.get_global_rect().encloses(tile.get_node("Row/Text/Name").get_global_rect()),"fish name stays inside its image tile")
  root.size=Vector2i(1280,720)
 view.get_node("%Maps").current_tab=1
 await frames()
 check(view.groups.size()==1 and view.groups[0].species=="tilapia","map tab filters catches without cross-map leakage")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-fishing-methods/lotus-tab.png")
 view.get_node("%Maps").current_tab=5
 await frames()
 check(view.groups.is_empty() and view.get_node("%Empty").visible,"uncaught map has honest empty state")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://exports/qa-fishing-methods/empty-map.png")
 var legacy: Dictionary = profile.data.journal[0].duplicate(true)
 legacy.erase("settings")
 profile.data.journal=[legacy]
 view.get_node("%Maps").current_tab=0
 await frames()
 view._select_species(0)
 check(view.get_node("%Brake").text=="ไม่ได้บันทึก" and view.get_node("%Depth").text=="1.5 ม.","old saves retain known depth and mark absent settings")
 var shop: Control = load("res://features/economy/tackle_panel.tscn").instantiate()
 var controller := FishingController.new()
 var pond := PondEcosystem.new()
 var gateway := CommerceGateway.new()
 root.add_child(shop)
 shop.bind(profile,controller,pond,gateway)
 shop.open()
 shop.get_node("Shop")._more(10)
 await frames()
 var embedded: Control = shop.get_node("Shop").get_node("%Methods")
 check(embedded.groups.size()==1,"actual shop journal tab renders recorded catches")
 check(not shop.has_node("Card/Content/Tabs/Journal/Scroll/Records"),"old long text journal removed")
 shop.queue_free()
 await process_frame
 controller.free()
 pond.free()
 gateway.free()
 preview.queue_free()
 await process_frame
 await process_frame
 print("FISHING METHODS RESULT: ",failures," failures")
 quit(1 if failures else 0)
