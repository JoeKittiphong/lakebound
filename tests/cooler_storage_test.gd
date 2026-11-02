extends SceneTree
var failures := 0
var output := "res://exports/qa-cooler"

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 failures += int(not ok)

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.save_path = "user://cooler-qa.cfg"
 profile.data = profile.defaults()
 for i in 10:
  var species: Resource = FishCatalog.ALL_SPECIES[i]
  profile.data.catches.append({"name":species.display_name,"species":str(species.id),"weight":0.6+i*0.1,"map":"river","depth":1.0,"time":100.0,"bait":"worm","rod":"light_rod","reel":"basic_reel","line":"nylon","catch_id":"cooler-qa-%d"%i})
 var panel: Control = load("res://features/fishing/ui/fish_storage_panel.tscn").instantiate()
 root.add_child(panel)
 panel.bind(profile,null)
 panel.open()
 await create_timer(1.05).timeout
 check(panel.grid.get_child_count() == 8, "eight editable 3D fish positions")
 check(panel.box.get_node("Body").scene_file_path.ends_with("cooler_body.glb"), "body is exported Blender model")
 check(panel.box.get_node("Lid/Model").scene_file_path.ends_with("cooler_lid.glb"), "lid is exported Blender model")
 check(is_equal_approx(panel.box.get_node("Lid").rotation.x,-1.8325957), "lid opens at original hinge")
 for slot: StoredFishDisplay in panel.grid.get_children():
  var bounds := slot.mesh_bounds()
  check(slot.model != null and bounds.size.length() > 0, "real species mesh in slot %d"%slot.record_index)
  check(bounds.size.x <= slot.fit_size.x+0.01 and bounds.size.y <= slot.fit_size.y+0.01 and bounds.size.z <= slot.fit_size.z+0.01, "fish fits within its space")
  check(bounds.position.y >= 0 and bounds.end.y + slot.position.y < 4.04, "fish stays above ice and below rim")
 if DisplayServer.get_name() != "headless":
  DirAccess.make_dir_recursive_absolute(output)
  for resolution in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
   root.size = resolution
   for i in 8: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("cooler-%dx%d.png" % [resolution.x,resolution.y]))
   var frame := Rect2(Vector2.ZERO,Vector2(panel.viewport.size))
   var fits := true
   for fish_slot: StoredFishDisplay in panel.grid.get_children():
    if fish_slot.disabled: continue
    var bounds := fish_slot.mesh_bounds()
    for corner in 8:
     var local := bounds.position + bounds.size * Vector3(float(corner&1),float((corner>>1)&1),float((corner>>2)&1))
     fits = fits and frame.has_point(panel.camera.unproject_position(fish_slot.to_global(local)))
   check(fits,"all stored fish fit the close-up camera at %s"%resolution)
   var opening_fits := true
   for point in panel._frame_points:
    opening_fits = opening_fits and frame.has_point(panel.camera.unproject_position(panel.box.to_global(point)))
   check(opening_fits,"entire opening remains visible in the close-up at %s"%resolution)
   check(not panel.has_node("Card/Content/Capacity") and not panel.detail.has_node("Icon"),"no weight bar or duplicate fish picture")
   var slot: StoredFishDisplay = panel.grid.get_child(1)
   var center := slot.to_global(slot.mesh_bounds().get_center())
   var point: Vector2 = panel.camera.unproject_position(center) * panel.preview.size / Vector2(panel.viewport.size)
   panel._pick_inventory(point)
   check(panel.selected_index == 1, "3D ray selects actual fish at %s" % resolution)
 panel._change_page(1)
 check(panel.page == 1 and panel.grid.get_child(0).record_index == 8, "page two shows later catches")
 check(panel.grid.get_child(2).disabled and panel.grid.get_child(2).model == null, "unused slots have no fish")
 var before: int = profile.data.coins
 panel._dispose(true)
 check(profile.data.catches.size() == 9 and profile.data.coins > before, "sale updates inventory and 3D scene")
 var probe: StoredFishDisplay = panel.grid.get_child(0)
 var all_fit := true
 for species in FishCatalog.ALL_SPECIES:
  probe.bind({"species":str(species.id)},0,false)
  var bounds := probe.mesh_bounds()
  all_fit = all_fit and probe.model != null and bounds.size.length()>0 and bounds.size.x <= probe.fit_size.x+0.01 and bounds.size.z <= probe.fit_size.z+0.01
 check(all_fit,"all catalog species have real 3D models that fit the cooler")
 profile.data.catches.clear()
 profile.changed.emit()
 for slot in panel.grid.get_children():
  check(slot.disabled and slot.model == null, "empty inventory clears all models")
 panel.close()
 await create_timer(1.05).timeout
 check(not panel.visible and panel.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "closed cooler stops rendering")
 panel.queue_free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.save_path))
 print("COOLER STORAGE RESULT: ",failures," failures")
 quit(1 if failures else 0)
