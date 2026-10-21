extends SceneTree

var errors := 0
var checks := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR")

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  errors += 1
  push_error("FAIL: " + message)

func run() -> void:
 var collection = root.get_node("FishCollection")
 collection.recording_enabled = false
 var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("FishingController").set_physics_process(false)
 scene.get_node("PondEcosystem").set_physics_process(false)
 scene.get_node("FishingEffects").audio_enabled = false
 var panel = scene.get_node("HUD/FishingHUD/CollectionPanel")
 # Open before the first draw, then reopen and resize while gameplay is paused.
 for resolution in [Vector2i(1280, 720), Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(960, 540), Vector2i(720, 1280)]:
  root.size = resolution
  for repeat in 3:
   panel.open()
   expect(paused and panel.visible, "journal opens and pauses gameplay")
   for frame in 8:
    await process_frame
   var scroll: ScrollContainer = panel.get_node("Card/Content/Scroll")
   var rows: GridContainer = scroll.get_node("Rows")
   var screen := root.get_visible_rect()
   var card: Control = panel.get_node("Card")
   expect(panel.size.is_equal_approx(screen.size), "journal covers the viewport after binary scene export")
   expect(card.size.x >= screen.size.x * 0.85 and card.size.y >= screen.size.y * 0.85, "journal card uses the full mobile display")
   expect(rows.get_child_count() == 16, "exported catalog contains all sixteen fish")
   expect(scroll.size.y >= 160 and rows.size.y >= 400, "grid has visible height on mobile aspect ratios")
   var clip := scroll.get_global_rect()
   var visible_cards := 0
   for row in rows.get_children():
    var icon: TextureRect = row.get_node("Content/Preview")
    expect(row.size.x >= 130 and row.size.y >= 100, "fish card retains readable dimensions")
    expect(icon.texture != null and icon.size.y > 20, "fish icon survives export and paused layout")
    if clip.intersects(row.get_global_rect()):
     visible_cards += 1
   expect(visible_cards >= rows.columns, "first row is visible below the heading")
   scroll.scroll_vertical = 100000
   for frame in 3:
    await process_frame
   expect(clip.intersects(rows.get_child(15).get_global_rect()), "last fish can be reached by scrolling")
   scroll.scroll_vertical = 0
   if repeat == 0 and not output.is_empty():
    DirAccess.make_dir_recursive_absolute(output)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output + "/mobile-collection-%dx%d.png" % [resolution.x, resolution.y])
   panel.close()
   expect(not paused, "closing resumes gameplay")
 scene.queue_free()
 await process_frame
 print("MOBILE COLLECTION RESULT: ", checks, " checks, ", errors, " failures")
 quit(0 if errors == 0 else 1)
