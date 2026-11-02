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
 # The book paginates rather than placing the whole catalog in a vertical scroll.
 panel.open()
 for frame in 240:
  if panel.phase == "ready": break
  await process_frame
 for resolution in [Vector2i(1280,720), Vector2i(2400,1080), Vector2i(2340,1080), Vector2i(960,540), Vector2i(720,1280)]:
  root.size = resolution
  for frame in 8: await process_frame
  expect(paused and panel.visible, "journal remains a paused modal while resizing")
  var rows: GridContainer = panel.get_node("Card/Content/Scroll/Rows")
  var screen := root.get_visible_rect()
  var card: Control = panel.get_node("Card")
  expect(panel.size.is_equal_approx(screen.size), "book covers the viewport")
  expect(card.size.x >= screen.size.x * 0.85 and card.size.y >= screen.size.y * 0.85, "book uses the mobile display")
  expect(panel.filtered_species.size() == FishCatalog.ALL_SPECIES.size() and rows.get_child_count() == 15, "expanded catalog is paginated into fifteen visible fish")
  expect(rows.columns == 5, "five columns remain stable")
  var area: Control = panel.get_node("Card/Content/Scroll")
  for tile in rows.get_children():
   expect(tile.size.x >= 48 and tile.size.y >= 48, "fish retain a usable touch target")
   expect(area.get_global_rect().encloses(tile.get_global_rect()), "fish remain inside the left page")
   expect(tile.get_node("Content/Preview").texture != null, "fish portrait survives paused layout")
  if not output.is_empty():
   DirAccess.make_dir_recursive_absolute(output)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output + "/mobile-collection-%dx%d.png" % [resolution.x,resolution.y])
 panel.turn_page(panel.page_count-1)
 for frame in 240:
  if panel.phase == "ready": break
  await process_frame
 var final_id := String(FishCatalog.ALL_SPECIES.back().id)
 var final_tile: Control = panel.rows.get_child(panel.rows.get_child_count()-1)
 expect(final_tile.species_id == final_id, "the last species remains reachable through paging")
 panel.close()
 await panel.closed
 expect(not paused, "closing the cover resumes gameplay")
 scene.queue_free()
 await process_frame
 print("MOBILE COLLECTION RESULT: ", checks, " checks, ", errors, " failures")
 quit(0 if errors == 0 else 1)
