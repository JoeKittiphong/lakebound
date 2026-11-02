extends SceneTree
var failures := 0
func _initialize() -> void:
 call_deferred("run")

func check(ok: bool,label: String) -> void:
 print("PASS: " if ok else "FAIL: ",label)
 failures += int(not ok)

func frames() -> void:
 for i in 8: await process_frame

func swipe(control: Control,delta: Vector2,cancelled: bool = false) -> void:
 var point := control.get_global_rect().get_center()
 var event := InputEventScreenTouch.new()
 event.index = 5
 event.position = point
 event.pressed = true
 root.push_input(event,true)
 event = event.duplicate()
 event.pressed = false
 event.canceled = cancelled
 event.position += delta
 root.push_input(event,true)
 await frames()

func run() -> void:
 var profile: AnglerProfile = root.get_node("AnglerSave")
 profile.data = profile.defaults()
 profile.data.identity.name = "นักตกปลาริมน้ำ"
 root.size = Vector2i(1280,720)
 var menu: Control = load("res://features/menu/main_menu.tscn").instantiate()
 root.add_child(menu)
 await frames()
 var carousel: MapCarousel = menu.get_node("SafeArea/PlayCard/Content/MapCarousel")
 check(not menu.has_node("SafeArea/PlayCard/Content/ChooseRegion"),"old map dropdown removed")
 check(carousel.ART.size()==6,"six generated map images are available")
 for entry in RegionCatalog.MAPS:
  carousel.set_region(entry.id,true)
  check(menu.selected_region==entry.id and menu.get_node("SafeArea/PlayCard/Content/Location").text==entry.name,"card selects the real map: "+entry.id)
  check(ResourceLoader.exists(entry.scene),"selected scene exists")
 carousel.set_region("river",true)
 await swipe(carousel.get_node("%Images"),Vector2(-140,0))
 check(menu.selected_region=="lotus_marsh","real left swipe selects next map")
 await swipe(carousel.get_node("%Images"),Vector2(140,0))
 check(menu.selected_region=="river","real right swipe selects previous map")
 await swipe(carousel.get_node("%Images"),Vector2(0,90))
 check(menu.selected_region=="river","vertical gesture does not change map")
 await swipe(carousel.get_node("%Images"),Vector2(-140,0),true)
 check(menu.selected_region=="river","cancelled gesture does not select map")
 carousel.get_node("%Previous").pressed.emit()
 check(menu.selected_region=="coral_coast","previous wraps from first to last")
 carousel.get_node("%Next").pressed.emit()
 check(menu.selected_region=="river","next wraps from last to first")
 DirAccess.make_dir_recursive_absolute("res://exports/qa-map-carousel")
 if DisplayServer.get_name() != "headless":
  for dimensions in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1024,768)]:
   root.size = dimensions
   for style in 2:
    carousel.set_style(style)
    carousel.set_region("river",true)
    await frames()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://exports/qa-map-carousel/%s-%dx%d.png"%[["A-cards","B-banner"][style],dimensions.x,dimensions.y])
    check(root.get_visible_rect().encloses(carousel.get_global_rect()),"carousel fits viewport %s"%dimensions)
    check(menu.get_node("SafeArea/PlayCard").get_global_rect().encloses(carousel.get_global_rect()),"map images stay inside the original right-hand play card")
    check(carousel.get_global_rect().position.x >= menu.size.x*0.6,"angler and bridge area stays clear")
  root.size = Vector2i(1280,720)
  carousel.set_style(1)
  for entry in RegionCatalog.MAPS:
   carousel.set_region(entry.id,true)
   await frames()
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://exports/qa-map-carousel/map-%s.png"%entry.id)
 menu.queue_free()
 await process_frame
 await process_frame
 print("MAP CAROUSEL RESULT: ",failures," failures")
 quit(1 if failures else 0)
