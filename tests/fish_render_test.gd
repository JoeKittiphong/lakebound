extends SceneTree

const Catalog = preload("res://data/fish/fish_catalog.gd")
var output := OS.get_environment("LAKEBOUND_QA_DIR") if not OS.get_environment("LAKEBOUND_QA_DIR").is_empty() else "res://exports/qa/screenshots"
var failures := 0

func _initialize() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 call_deferred("run")

func frames(count: int = 5) -> void:
 for tick in count:
  await process_frame

func capture(name: String) -> void:
 await frames(6)
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 if image == null or image.is_empty() or image.save_png(output + "/" + name + ".png") != OK:
  failures += 1
  push_error("Could not capture " + name)

func run() -> void:
 root.size = Vector2i(1280, 720)
 var collection := root.get_node("FishCollection")
 collection.recording_enabled = false
 var saved_records: Dictionary = collection.records.duplicate(true)
 var gallery: Node3D = load("res://world/pond/models/fish_catalog_preview.tscn").instantiate()
 root.add_child(gallery)
 current_scene = gallery
 await create_timer(0.4).timeout
 await capture("godot-fish-catalog-16")
 gallery.free()
 await frames(2)
 var scene: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 var pond: Node = scene.get_node("PondEcosystem")
 var fishing: Node = scene.get_node("FishingController")
 var hud: Control = scene.get_node("HUD/FishingHUD")
 pond.set_physics_process(false)
 fishing.set_physics_process(false)
 scene.get_node("Player").set_physics_process(false)
 for definition in Catalog.SPECIES:
  collection.records[String(definition.id)] = {"count": 1, "total": 1.0, "best": 1.0, "smallest": 1.0, "last": 1.0}
 hud.get_node("CollectionPanel").open()
 await capture("godot-collection-first-page")
 var scroll: ScrollContainer = hud.get_node("CollectionPanel/Card/Content/Scroll")
 scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
 await capture("godot-collection-last-page")
 root.size = Vector2i(1600, 720)
 scroll.scroll_vertical = 0
 await capture("godot-collection-wide")
 hud.get_node("CollectionPanel").close()
 root.size = Vector2i(1280, 720)
 for index in mini(7, pond.fish.size()):
  var fish: RefCounted = pond.fish[index]
  fish.position = Vector3(-5.0 + index * 1.65, 0.1, -10.5)
  fish.heading = PI * 0.5
  fish.state = &"roaming"
 await capture("godot-fish-surface")
 var ray: RefCounted
 for fish in pond.fish:
  if fish.species.id == &"freshwater_stingray":
   ray = fish
 if ray != null:
  ray.state = &"landed"
  fishing.active_fish = ray
  fishing._change_state(fishing.State.RESULT)
  hud.show_catch_result(ray, "")
  await capture("godot-catch-stingray")
 else:
  failures += 1
 collection.records = saved_records
 scene.free()
 await frames(3)
 print("FISH RENDER RESULT: ", failures, " failures")
 quit(failures)

