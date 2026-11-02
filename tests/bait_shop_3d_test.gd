extends SceneTree
const OUT := "res://../output/game-baits-3d-v01/"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + label)
func settle() -> void:
 await create_timer(.28).timeout
 for i in 4: await process_frame
func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT + name + ".png")
func loaded(shelf:ShopShelfBrowser)->int:
 var count:=0
 for slot:ShopShelfSlot in shelf.slots():
  if is_instance_valid(slot.model):count+=1
 return count
func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = OUT + "preview_profile.cfg";profile.data = profile.defaults();profile.incompatible = false
 profile.grant_trial_equipment()
 var pond := PondEcosystem.new()
 var controller := FishingController.new();controller.ecosystem = pond;controller.profile = profile
 var gateway := CommerceGateway.new()
 root.size = Vector2i(1280,720)
 var shop: Control = load("res://features/economy/tackle_panel.tscn").instantiate()
 root.add_child(shop);shop.bind(profile, controller, pond, gateway);shop.open_category(1)
 await settle()
 var browser:ShopShelfBrowser=shop.get_node("Shop/%Shelf")
 var entries:Array[TackleItem]=[]
 for item:TackleItem in TackleCatalog.ITEMS:
  if item.kind not in ["bait","lure"]:continue
  entries.append(item)
  expect(item.model_scene!=null,"3D product assigned "+str(item.id))
 expect(entries.size()==25,"all natural baits and lures have 3D products")
 expect(not shop.has_node("Card/Content/Tabs/Tackle/Scroll/Rows"),"no legacy sprite cards remain")
 for resolution in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2400,1080)]:
  root.size=resolution;await settle()
  expect(loaded(browser)>0 and loaded(browser)<=12,"only current shelf products load")
  await capture("shop_baits_%dx%d"%[resolution.x,resolution.y])
 root.size = Vector2i(1280,720)
 var inspector: Control = shop.get_node("Shop/%EquipmentInspector")
 var preview: EquipmentModelPreview = inspector.get_node("%Preview")
 for entry in entries:
  inspector.open_item(entry);await settle()
  expect(is_instance_valid(preview.instance) and preview.instance.scene_file_path == entry.model_scene.resource_path, "inspector loads actual catalog model " + str(entry.id))
  var corners := preview.framing_points()
  expect(not corners.is_empty(), "imported meshes have real bounds " + str(entry.id))
  var screen := Rect2(preview.camera.unproject_position(corners[0]),Vector2.ZERO)
  for corner in corners: screen = screen.expand(preview.camera.unproject_position(corner))
  var coverage := maxf(screen.size.x / preview.viewport.size.x, screen.size.y / preview.viewport.size.y)
  expect(coverage > .6 and coverage < .99, "full model stays framed " + str(entry.id))
  if str(entry.id) in ["worm","dough","minnow","corn","shrimp","spinnerbait"]: await capture("inspect_"+str(entry.id))
 var rotation := preview.pivot.rotation
 var down := InputEventMouseButton.new();down.button_index = MOUSE_BUTTON_LEFT;down.pressed = true
 preview._gui_input(down)
 var drag := InputEventMouseMotion.new();drag.relative = Vector2(35,12);preview._gui_input(drag)
 expect(not preview.pivot.rotation.is_equal_approx(rotation), "bait inspector rotates actual geometry")
 var zoom := preview.camera.size;preview._set_zoom(.5)
 expect(preview.camera.size < zoom, "bait inspector zooms actual geometry")
 inspector.close();await settle()
 expect(not is_instance_valid(preview.instance), "closing inspector releases model")
 shop.close();await settle()
 expect(loaded(browser) == 0, "hidden shop releases all bait models")
 root.size = Vector2i(1600,1200)
 var gallery: Control = load("res://tests/previews/bait_model_gallery.tscn").instantiate()
 root.add_child(gallery)
 for entry in entries:
  var cell: Control = load("res://tests/previews/bait_gallery_cell.tscn").instantiate()
  gallery.get_node("Margin/Grid").add_child(cell)
  cell.get_node("Name").text = entry.display_name.get_slice(" ×",0)
  cell.get_node("Preview").set_item(entry)
 await settle();await settle()
 for cell in gallery.get_node("Margin/Grid").get_children():
  cell.get_node("Preview/Hint").hide()
 await capture("all_25_models")
 gallery.queue_free();shop.queue_free();controller.free();pond.free();gateway.free()
 await process_frame
 var file := FileAccess.open(OUT + "godot_verification.json", FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":entries.size()},"  "))
 print("BAIT SHOP 3D: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
