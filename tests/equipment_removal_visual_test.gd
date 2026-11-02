extends SceneTree
var checks := 0
var failures := 0
var out: String
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL: " + label)
func settle() -> void:
 await create_timer(0.25).timeout
 for i in 3: await process_frame
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 expect(root.get_texture().get_image().save_png(out.path_join(name)) == OK, "capture " + name)
func run() -> void:
 out = OS.get_environment("LAKEBOUND_QA_DIR")
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = out.path_join("visual-profile.cfg")
 profile.grant_trial_equipment()
 root.get_node("FishCollection").recording_enabled = false
 var pond := PondEcosystem.new()
 var fishing := FishingController.new()
 fishing.profile=profile
 fishing.ecosystem=pond
 var gateway := CommerceGateway.new()
 var panel: Control = load("res://features/economy/tackle_panel.tscn").instantiate()
 root.add_child(panel)
 panel.bind(profile,fishing,pond,gateway)
 panel.open()
 var shop: Control = panel.get_node("Shop")
 var initial := profile.data.duplicate(true)
 for dimensions in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2400,1080)]:
  profile.data=initial.duplicate(true)
  root.size=dimensions
  shop.get_node("%Gear").pressed.emit()
  shop._inspect_item(profile.equipped("reel"))
  await settle()
  var suffix := "_%dx%d.png" % [dimensions.x,dimensions.y]
  for key in ["Rod","Reel","Line","Bait","Box"]:
   var button: Button = shop.get_node("%Remove"+key)
   expect(root.get_visible_rect().encloses(button.get_global_rect()),"remove button inside screen: " + key)
   expect(button.get_global_rect().end.x <= shop.inspector.get_global_rect().position.x+1,"remove button clear of details: " + key)
  expect(shop.inspector.get_node("%Unequip").visible,"selected component has remove action")
  await capture("01-overview-remove"+suffix)
  expect(profile.equip("casting_rod"),"switch rod in overview")
  fishing.refresh_equipment()
  shop.refresh()
  shop._inspect_item(profile.equipped("rod"))
  await settle()
  expect(shop.get_node("%RemoveReel").disabled and shop.get_node("%RemoveLine").disabled and shop.get_node("%RemoveBait").disabled,"empty attached slots disable removal")
  var rod: DetailedFishingRod=shop.get_node("%LoadoutView").assembled_rod()
  expect(rod.held_reel == null and not rod.ribbon.visible,"overview has no old reel or line")
  expect(not shop.get_node("%LoadoutView/View/Viewport/Studio/Leader").visible,"no phantom hanging leader after rod switch")
  await capture("02-new-rod-empty"+suffix)
  shop.get_node("%SelectReel").pressed.emit()
  var reel: TackleItem=profile.reel_for_rod(profile.equipped("rod"))
  shop._inspect_item(reel)
  await settle()
  expect(not shop.inspector.get_node("%Equip").disabled,"new compatible reel is selectable")
  await capture("03-select-reel"+suffix)
  shop.inspector.get_node("%Equip").pressed.emit()
  expect(profile.equip("nylon"),"reattach reserved line")
  var bait_selected := false
  for item: TackleItem in TackleCatalog.ITEMS:
   if item.kind in ["bait","lure"] and profile.quantity(str(item.id))>0 and profile.equipment_fit_error(item).is_empty():
    bait_selected=profile.equip(str(item.id))
    break
  expect(bait_selected,"choose compatible bait")
  shop.get_node("%Gear").pressed.emit()
  shop._inspect_item(profile.equipped("reel"))
  await settle()
  expect(profile.current_fit_error().is_empty(),"complete replacement set works")
  await capture("04-reassembled"+suffix)
  shop.get_node("%RemoveRod").pressed.emit()
  await settle()
  expect(profile.equipped("rod")==null and shop.get_node("%RemoveRod").disabled,"remove rod row works")
  expect(shop.get_node("%LoadoutView/EmptyMessage").visible,"empty overview displays instructions")
  await capture("05-empty-overview"+suffix)
 panel.close()
 panel.queue_free()
 fishing.free()
 pond.free()
 gateway.free()
 await settle()
 print("EQUIPMENT REMOVAL VISUAL RESULT: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
