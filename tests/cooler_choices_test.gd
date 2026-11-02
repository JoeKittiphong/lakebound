extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func check(ok: bool,label: String) -> void:
 print("PASS: " if ok else "FAIL: ",label)
 failures += int(not ok)

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.save_path = "user://cooler-choices-test.cfg"
 for i in 10:
  var species: Resource = FishCatalog.ALL_SPECIES[i]
  profile.data.catches.append({"name":species.display_name,"species":str(species.id),"weight":0.6+i*0.1,"map":"river","depth":1.0,"time":100.0,"bait":"worm","rod":"light_rod","reel":"basic_reel","line":"nylon","catch_id":"choice-%d"%i})
 var panel: Control = load("res://features/fishing/ui/fish_storage_panel.tscn").instantiate()
 root.add_child(panel)
 panel.bind(profile,null)
 panel.open()
 await create_timer(1.05).timeout
 check(not panel.has_node("Card/Content/Header/View"),"only A camera remains; no view selector")
 check(not panel.detail.has_node("Icon"),"details have no duplicate fish picture")
 check(panel.find_children("*","ProgressBar",true,false).is_empty(),"weight is numeric only; no bar")
 DirAccess.make_dir_recursive_absolute("res://exports/qa-cooler-choices")
 for dimensions in [Vector2i(1280,720),Vector2i(1024,768)]:
  root.size = dimensions
  for view in 1:
   for i in 6: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://exports/qa-cooler-choices/%s-%dx%d.png"%["A-mouth",dimensions.x,dimensions.y])
   var frame := Rect2(Vector2.ZERO,Vector2(panel.viewport.size))
   var fits := true
   for point in panel._frame_points:
    fits = fits and frame.has_point(panel.camera.unproject_position(panel.box.to_global(point)))
   check(fits,"full cooler fits view %d at %s"%[view,dimensions])
   check(not panel.preview.get_global_rect().intersects(panel.detail.get_parent().get_global_rect()),"details never overlap cooler viewport")
   var slot: StoredFishDisplay = panel.grid.get_child(1)
   var target: Vector2 = panel.camera.unproject_position(slot.to_global(slot.mesh_bounds().get_center())) * panel.preview.size / Vector2(panel.viewport.size)
   panel._pick_inventory(target)
   check(panel.selected_index == 1,"fish picking works in camera %d"%view)
   check(root.get_visible_rect().encloses(panel.detail.get_node("SellAll").get_global_rect()),"sell-all button remains within screen")
 var original := profile.data.duplicate(true)
 panel.detail.get_node("SellAll").pressed.emit()
 check(profile.data == original and panel.detail.get_node("Confirm").visible,"sell all requires confirmation")
 panel.detail.get_node("Confirm/No").pressed.emit()
 check(profile.data == original,"cancel sell all preserves every fish and coins")
 panel.detail.get_node("SellAll").pressed.emit()
 var path: String = profile.save_path
 profile.save_path = "user://missing-cooler-directory/profile.cfg"
 panel.detail.get_node("Confirm/Yes").pressed.emit()
 check(profile.data == original,"failed bulk-sale save rolls back inventory and coins")
 profile.save_path = path
 var total := 0
 for record in original.catches:
  total += maxi(1,int(round(float(record.weight)*35.0)))
 panel.detail.get_node("SellAll").pressed.emit()
 panel.detail.get_node("Confirm/Yes").pressed.emit()
 check(profile.data.catches.is_empty() and profile.data.coins == original.coins+total,"sell all covers every page and pays exact total")
 check(panel.detail.get_node("SellAll").disabled,"empty bucket disables bulk sale")
 var after: int = profile.data.coins
 panel._confirm_action()
 check(profile.data.coins==after,"repeated confirmation cannot double-pay")
 var restored := ProfileStore.load_profile(path)
 check(restored.data.catches.is_empty() and restored.data.coins == after,"bulk sale survives reload")
 panel.queue_free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("COOLER CHOICES RESULT: ",failures," failures")
 quit(1 if failures else 0)
