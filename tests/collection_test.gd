extends SceneTree

var errors := 0
var output := OS.get_environment("LAKEBOUND_QA_DIR") if not OS.get_environment("LAKEBOUND_QA_DIR").is_empty() else "res://exports/qa/screenshots"

func _initialize() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  errors += 1

func run() -> void:
 var collection := root.get_node("FishCollection")
 var test_save_path := output + "/collection-test-%d.cfg" % OS.get_process_id()
 collection.save_path = test_save_path
 DirAccess.remove_absolute(collection.save_path)
 collection.load_records()
 expect(collection.records.is_empty(), "new player starts undiscovered")
 var scene = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var fishing = scene.get_node("FishingController")
 var pond = scene.get_node("PondEcosystem")
 scene.get_node("FishingEffects").audio_enabled = false
 var hud = scene.get_node("HUD/FishingHUD")
 fishing.set_physics_process(false)
 pond.set_physics_process(false)
 var fish = pond.fish[0]
 fish.weight = 1.2
 fishing.active_fish = fish
 fishing._change_state(fishing.State.RESULT)
 fishing.fish_landed.emit(fish)
 expect(collection.stats(fish.species.id).count == 1, "landed catch records before keep/release choice")
 fishing.resolve_catch(false)
 expect(collection.stats(fish.species.id).count == 1, "release does not count twice")
 fish.weight = 2.4
 fishing.active_fish = fish
 fishing._change_state(fishing.State.RESULT)
 fishing.fish_landed.emit(fish)
 fishing.resolve_catch(true)
 expect(collection.stats(fish.species.id).count == 2, "keeping also counts once")
 fish.weight = 0.6
 collection.record_catch(fish)
 collection.load_records()
 var stats: Dictionary = collection.stats(fish.species.id)
 expect(stats.count == 3 and is_equal_approx(stats.total, 4.2) and is_equal_approx(stats.best, 2.4) and is_equal_approx(stats.smallest, 0.6) and is_equal_approx(stats.last, 0.6), "save reload preserves all statistics and replacement saves")
 await process_frame
 var collection_button: Button = hud.get_node("SafeArea/CollectionButton")
 var open_point := collection_button.get_global_rect().get_center()
 for pressed in [true, false]:
  var touch := InputEventScreenTouch.new()
  touch.index = 0
  touch.position = open_point
  touch.pressed = pressed
  root.push_input(touch, true)
  await process_frame
 expect(paused and hud.get_node("CollectionPanel").visible, "collection button opens a paused modal")
 expect(hud.get_node("CollectionPanel/Card/Content/Scroll/Rows").get_child_count() == 16, "all sixteen pond species have cards")
 await process_frame
 var rows: Node = hud.get_node("CollectionPanel/Card/Content/Scroll/Rows")
 var shared_atlas: Texture2D
 for index in rows.get_child_count():
  var icon: TextureRect = rows.get_child(index).get_node("Content/Preview")
  var definition: Resource = collection.SPECIES[index]
  expect(icon.texture != null and icon.texture == definition.collection_icon, String(definition.id) + " has its assigned collection icon")
  expect(icon.texture is AtlasTexture and rows.get_child(index).find_children("*", "SubViewport", true, false).is_empty(), String(definition.id) + " uses the atlas without a 3D viewport")
  if icon.texture is AtlasTexture:
   if shared_atlas == null:
    shared_atlas = icon.texture.atlas
   expect(icon.texture.atlas == shared_atlas and icon.texture.region.size == Vector2(256, 176), String(definition.id) + " shares the 1024 atlas with a padded 256 pixel wide region")
 for index in rows.get_child_count():
  var row: Control = rows.get_child(index)
  var unlocked: bool = collection.stats(collection.SPECIES[index].id).count > 0
  expect(row.get_node("Content/Name").visible == unlocked and (unlocked or row.get_node("Content/Name").text.is_empty()), "locked card hides its species name")
  expect(row.get_node("Content/Preview/Question").visible == not unlocked and (row.get_node("Content/Preview").material != null) == not unlocked, "only locked cards use a silhouette and question mark")
 var card := rows.get_child(0) as Control
 var point := card.get_global_rect().get_center()
 for pressed in [true, false]:
  var event := InputEventScreenTouch.new()
  event.index = 12
  event.pressed = pressed
  event.position = point
  Input.parse_input_event(event)
  await process_frame
 expect(rows.get_child(0).get_node("Content/Stats").text == "สูงสุด 2.40 กก. • 3 ตัว", "unlocked card directly shows best weight and catch count")
 expect(not hud.get_node("CollectionPanel/Card/Content").has_node("DetailsFrame"), "tapping a card cannot open a details area")
 expect(not rows.get_child(1).get_node("Content/Stats").visible and rows.get_child(1).get_node("Content/Stats").text.is_empty(), "locked cards reveal no catch statistics")
 for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1920, 864)]:
  root.size = viewport_size
  for tick in 5:
   await process_frame
  var close_button: Button = hud.get_node("CollectionPanel/Card/Content/Header/Close")
  var modal_card: PanelContainer = hud.get_node("CollectionPanel/Card")
  expect(modal_card.get_global_rect().encloses(close_button.get_global_rect()), "close button stays inside the journal at " + str(viewport_size))
  expect(hud.get_node("CollectionPanel/Card/Content/Scroll").size.y > 180, "fish grid remains visible at " + str(viewport_size))
  var scroll: ScrollContainer = hud.get_node("CollectionPanel/Card/Content/Scroll")
  expect(rows.get_rect().size.y <= scroll.size.y + 1.0, "all sixteen slots fit without vertical scrolling at " + str(viewport_size))
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output + "/collection-%d.png" % viewport_size.x)
 var close_point: Vector2 = hud.get_node("CollectionPanel/Card/Content/Header/Close").get_global_rect().get_center()
 for pressed in [true, false]:
  var touch := InputEventScreenTouch.new()
  touch.index = 0
  touch.position = close_point
  touch.pressed = pressed
  root.push_input(touch, true)
  await process_frame
 expect(not paused and not hud.get_node("CollectionPanel").visible, "close resumes game")
 var newly_caught = load("res://world/pond/fish_state.gd").new()
 newly_caught.species = collection.SPECIES[1]
 newly_caught.weight = 1.5
 collection.record_catch(newly_caught)
 collection.load_records()
 hud.get_node("CollectionPanel").open()
 var unlocked_row: Control = hud.get_node("CollectionPanel/Card/Content/Scroll/Rows").get_child(1)
 expect(unlocked_row.get_node("Content/Name").text == newly_caught.species.display_name and unlocked_row.get_node("Content/Name").visible, "first catch permanently unlocks the species name")
 expect(unlocked_row.get_node("Content/Preview").material == null and not unlocked_row.get_node("Content/Preview/Question").visible, "first catch replaces the silhouette with the full color icon")
 hud.get_node("CollectionPanel").close()
 collection.save_path = output + "/missing-folder/collection.cfg"
 expect(not collection.save_records() and not collection.save_error.is_empty(), "failed save is reported without losing in-memory stats")
 DirAccess.remove_absolute(test_save_path)
 print("COLLECTION RESULT: ", errors, " failures")
 quit(errors)

