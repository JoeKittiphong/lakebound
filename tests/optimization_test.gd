extends SceneTree

var failures := 0
var report: Dictionary = {}
const CATCH = {"name": "test", "map": "river", "bait": "worm", "rod": "light_rod", "reel": "basic_reel", "line": "nylon", "species": "tilapia", "weight": 1.0, "depth": 1.5, "time": 1.0}

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 if not value:
  failures += 1
  print("FAIL: ", message)

func run() -> void:
 for entry in TackleCatalog.ITEMS:
  expect(TackleCatalog.item(String(entry.id)) == entry, "equipment lookup preserves resource identity")
 for entry in MissionCatalog.ALL_ITEMS:
  expect(MissionCatalog.find(entry.id) == entry, "mission lookup preserves resource identity")
 expect(TackleCatalog.item("missing") == null and MissionCatalog.find("missing") == null, "unknown catalog IDs remain null")
 var start := Time.get_ticks_usec()
 for index in 10000:
  TackleCatalog.item("large_box")
  MissionCatalog.find("coral_coast_champion")
 report["catalog_20000_lookups_us"] = Time.get_ticks_usec() - start
 var saves: Array[Dictionary] = []
 for count in [0, 200, 2000]:
  var value := ProfileStore.defaults()
  for index in count:
   var record := CATCH.duplicate()
   record["catch_id"] = str(index)
   value.journal.append(record)
  var profile := AnglerProfile.new()
  profile.data = value
  var copies: Array[int] = []
  var deep_copies: Array[int] = []
  var writes: Array[int] = []
  var path := "user://profile-stress.cfg"
  for iteration in 5:
   start = Time.get_ticks_usec()
   var before := profile._transaction_snapshot()
   copies.append(Time.get_ticks_usec() - start)
   expect(before == value, "rollback copy remains complete")
   start = Time.get_ticks_usec()
   var deep := value.duplicate(true)
   deep_copies.append(Time.get_ticks_usec() - start)
   expect(deep == before, "optimized snapshot matches deep baseline")
   start = Time.get_ticks_usec()
   expect(ProfileStore.save_profile(path, value) == OK, "stress profile save succeeds")
   writes.append(Time.get_ticks_usec() - start)
  var loaded := ProfileStore.load_profile(path)
  var migrated := value.duplicate(true)
  CatchArchive.prepare(migrated)
  expect(not loaded.incompatible and loaded.data == migrated, "large profile survives save and bounded-history migration")
  expect(int(loaded.data.history.stats.get("tilapia",{}).get("count",0)) == count and loaded.data.journal.size() == mini(count,10), "large migration preserves lifetime count with at most ten detailed catches")
  profile.save_path = "user://missing-optimization-directory/profile.cfg"
  var original := value.duplicate(true)
  expect(not profile.buy("worm") and profile.data == original, "failed purchase restores full large profile")
  expect(not profile.start_missions() and profile.data == original, "failed mission mutation restores nested entries")
  expect(not profile.store_pond("river", [{"test": 1}]) and profile.data == original, "failed pond replacement restores old maps")
  expect(not profile.record_catch(CATCH, true) and profile.data == original, "failed catch restores journal and boss history")
  expect(not profile.keep_catch(CATCH, "river", [{"test": 2}]) and profile.data == original, "failed keep restores storage and population together")
  profile.free()
  deep_copies.sort()
  copies.sort()
  writes.sort()
  saves.append({"journal_entries": count, "median_copy_us": copies[2], "median_deep_copy_us": deep_copies[2], "median_save_us": writes[2], "bytes": FileAccess.get_file_as_bytes(path).size()})
 report["profile_transactions"] = saves
 root.get_node("FishCollection").recording_enabled = false
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled = false
 root.add_child(game)
 game.set_process(false)
 var pond: PondEcosystem = game.get_node("PondEcosystem")
 var fishing: FishingController = game.get_node("FishingController")
 var effects = game.get_node("FishingEffects")
 pond.set_physics_process(false)
 fishing.set_physics_process(false)
 effects.set_process(false)
 effects.audio_enabled = false
 var here := Vector2(effects.player.global_position.x, effects.player.global_position.z)
 var candidate_counts: Array[int] = []
 for scenario in 3:
  for index in pond.fish.size():
   var fish: RefCounted = pond.fish[index]
   fish.state = &"roaming"
   fish.position = Vector3(here.x + float(index % 12), 1.0, here.y - float(index / 12))
   if scenario == 1 and index % 3 != 0:
    fish.position.y = 12.0
   if scenario == 2:
    fish.position.x += 100.0
  fishing.active_fish = pond.fish[-1] if scenario == 2 else null
  var expected: Array = pond.fish.duplicate()
  expected.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
   var da := here.distance_squared_to(Vector2(a.position.x, a.position.z))
   var db := here.distance_squared_to(Vector2(b.position.x, b.position.z))
   return da < db if not is_equal_approx(da, db) else a.id < b.id)
  if fishing.active_fish != null:
   expected.erase(fishing.active_fish)
   expected.push_front(fishing.active_fish)
  expected = expected.filter(func(fish: RefCounted) -> bool:
   return (fish == fishing.active_fish or here.distance_squared_to(Vector2(fish.position.x, fish.position.z)) <= 3025.0) and (fish.position.y <= effects.visible_fish_depth or fish.state == &"landed"))
  expected.resize(mini(expected.size(), effects.visual_pool.size()))
  effects._update_fish_visuals()
  candidate_counts.append(effects._visible_candidates.size())
  var actual: Array = []
  for visual in effects.visual_pool:
   if visual.visible:
    actual.append(visual.record)
  expect(actual == expected, "filtered visual selection matches legacy nearest-first behavior")
 report["fish_population"] = pond.fish.size()
 report["visible_sort_candidates"] = candidate_counts
 game.free()
 var output := OS.get_environment("LAKEBOUND_QA_DIR").get_base_dir()
 var file := FileAccess.open(output.path_join("optimization.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify(report, " "))
 print("OPTIMIZATION RESULT: ", JSON.stringify(report), " failures=", failures)
 quit(1 if failures else 0)
