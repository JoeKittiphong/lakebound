extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 failures += int(not ok)

func run() -> void:
 var profile := AnglerProfile.new()
 var qa_dir := OS.get_environment("LAKEBOUND_QA_DIR")
 profile.save_path = qa_dir.path_join("fishing-map-data.cfg") if not qa_dir.is_empty() else "user://fishing-map-data.cfg"
 profile.data = profile.defaults()
 var legacy := profile.defaults()
 legacy.erase("map_memory")
 expect(ProfileStore.save_profile(profile.save_path, legacy) == OK, "write pre-map v1 save")
 profile.load_profile()
 expect(not profile.incompatible and profile.data.map_memory == FishingJournal.defaults(), "old profile gains empty map memory without resetting progress")
 var actor := Node3D.new()
 root.add_child(actor)
 actor.position = Vector3(-60, 3, 20)
 var fishing := FishingController.new()
 var ecosystem := PondEcosystem.new()
 fishing.ecosystem = ecosystem
 fishing.player = actor
 fishing.cast_position = Vector3(-45, 2.3, 16)
 fishing.state = FishingController.State.WAITING
 var fish := FishState.new()
 fish.species = load("res://data/fish/tilapia.tres")
 fish.weight = 1.25
 fishing._on_fish_biting(fish)
 var context := fishing.bite_context.duplicate(true)
 actor.position = Vector3(80, 0, 90)
 fish.position = Vector3(79, 0.3, 89)
 fishing.cast_position = Vector3(70, 0.1, 85)
 var record := CatchSettlement.make_record(fish, profile, "lotus_marsh", fishing.catch_event_id, "worm", fishing.bite_depth, false, false, fishing.bite_context)
 expect(record.location.angler_xz == Vector2(-60,20) and record.location.bite_xz == Vector2(-45,16), "landed record retains original stand and bite, not landing positions")
 expect(is_equal_approx(record.depth, 2.3), "depth stays positive metres and is not world height")
 fishing.bite_context.angler_xz = Vector2.ZERO
 expect(record.location.angler_xz == context.angler_xz, "saved context is detached from controller mutation")
 expect(profile.record_catch(record, false), "commit located catch through authoritative journal")
 expect(profile.record_catch(record, false) and profile.data.journal.size() == 1, "same event replay does not duplicate map history")
 expect(FishingJournal.history(profile.data.journal, "river").is_empty(), "history separates regions")
 expect(FishingJournal.history(profile.data.journal, "lotus_marsh", "snakehead").is_empty(), "history separates species")
 expect(profile.set_catch_note(record.catch_id, "ลองกลับมาตอนเย็น"), "optional annotation persists")
 expect(not profile.data.journal[0].has("note"), "annotations do not mutate immutable catch ledger")
 expect(not profile.set_catch_note("unknown", "note") and not profile.set_catch_note(record.catch_id, "x".repeat(241)), "unknown catch and oversized note are rejected")
 expect(profile.add_fishing_spot("lotus_marsh", context.angler_xz), "one-action favorite needs no name")
 expect(profile.add_fishing_spot("lotus_marsh", context.angler_xz) and profile.data.map_memory.favorites.size() == 1, "repeated save of the same spot does not create duplicates")
 expect(profile.add_fishing_spot("river", Vector2(42,-24), true), "boat favorite and another region persist")
 var first_id: String = profile.data.map_memory.favorites[0].id
 expect(profile.data.map_memory.favorites[0].name == "จุดตกปลา #1", "favorite name is assigned automatically")
 profile.load_profile()
 expect(profile.data.map_memory.notes[record.catch_id] == "ลองกลับมาตอนเย็น" and profile.data.journal[0].location == record.location, "reload retains note and both original coordinates")
 expect(profile.data.map_memory.favorites.size() == 2 and profile.data.map_memory.favorites[1].from_boat, "reload retains favorites and vessel context")
 var saved_path := profile.save_path
 profile.save_path = "user://missing-dir/fail.cfg"
 var before := profile.data.duplicate(true)
 expect(not profile.set_catch_note(record.catch_id, "should roll back") and profile.data == before, "failed note write restores previous text")
 expect(not profile.add_fishing_spot("river", Vector2(1,2)) and profile.data == before, "failed favorite write restores counter and array")
 expect(not profile.remove_fishing_spot(first_id) and profile.data == before, "failed removal restores favorite")
 profile.save_path = saved_path
 expect(profile.remove_fishing_spot(first_id) and profile.data.map_memory.favorites.size() == 1, "favorite can be removed")
 expect(profile.set_catch_note(record.catch_id, "") and profile.data.map_memory.notes.is_empty(), "empty note removes annotation")
 expect(not profile.add_fishing_spot("unknown", Vector2.ZERO) and not profile.add_fishing_spot("river", Vector2(NAN,0)), "invalid region and non-finite coordinates cannot enter saves")
 var invalid := profile.data.duplicate(true)
 invalid.journal[0].location.bite_xz = Vector2(INF,0)
 expect(not ProfileStore.valid(invalid), "loader rejects corrupt located records")
 fishing.reset_cast()
 expect(fishing.bite_context.is_empty(), "next cast cannot reuse previous location")
 for region in RegionCatalog.MAPS:
  var definition := FishingMapDefinition.for_region(region.id)
  expect(definition != null and definition.texture != null and definition.bounds.size.x > 0, "baked map exists for " + region.id)
 var authored_scene: PackedScene = load("res://features/map/fishing_map_panel.tscn")
 var authored := authored_scene.get_state()
 var terrain_preview := false
 for index in authored.get_node_count():
  if authored.get_node_name(index) == &"Terrain":
   terrain_preview = true
 expect(terrain_preview, "saved scene includes terrain preview before scripts run in editor")
 var view := FishingMapView.new()
 view.size = Vector2(620,410)
 root.add_child(view)
 view.configure(FishingMapDefinition.for_region("river"))
 for zoom_value in [1.0,2.0,4.0]:
  view.set_zoom(zoom_value)
  for point in [Vector2(-70,42),Vector2(0,-116),Vector2(42,-24)]:
   expect(view.unproject(view.project(point)).distance_to(point) < 0.001, "world/map projection round-trips at zoom " + str(zoom_value))
 var many: Array = []
 for index in 10000:
  var entry := record.duplicate(true)
  entry.location.bite_xz = Vector2(index%20,index%30)
  many.append(entry)
 view.set_history(many, [])
 expect(view._clusters.size() < 100, "ten thousand nearby catches render as bounded screen clusters")
 view.free()
 actor.free()
 fishing.free()
 ecosystem.free()
 profile.free()
 print("RESULT: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
