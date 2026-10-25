extends SceneTree

class CountingCollection extends "res://features/collection/fish_collection.gd":
 var writes := 0
 func save_records() -> bool:
  writes += 1
  return super.save_records()

var checks := 0
var failures := 0
var token := str(Time.get_ticks_usec())

func _initialize() -> void:
 call_deferred("run")

func expect(ok: bool, message: String) -> void:
 checks += 1
 print("PASS: " if ok else "FAIL: ", message)
 if not ok:
  failures += 1

func record(id: String) -> Dictionary:
 return {"catch_id": id, "species": "tilapia", "name": "ปลานิล", "weight": 1.0,
  "map": "river", "bait": "ไส้เดือน", "rod": "คันเบา", "reel": "รอกพื้นฐาน",
  "line": "ไนลอน", "depth": 1.5, "time": 1000.0, "mission_eligible": false}

func run() -> void:
 var path := "user://settlement-%s.cfg" % token
 var collection_path := "user://settlement-collection-%s.cfg" % token
 var profile := AnglerProfile.new()
 profile.save_path = path
 profile.data = profile.defaults()
 var collection := CountingCollection.new()
 collection.save_path = collection_path
 # A real pre-ledger v1 profile and collection must keep their statistics.
 profile.data.journal = [record("legacy")]
 expect(ProfileStore.save_profile(path, profile.data) == OK, "write existing v1 profile fixture")
 var legacy := {"tilapia": {"count": 2, "total": 2.0, "best": 1.0, "smallest": 1.0, "last": 1.0}}
 expect(CollectionStore.save_records(collection_path, legacy) == OK, "write existing v1 collection fixture")
 profile.load_profile()
 collection.load_records()
 expect(CatchSettlement.reconcile(profile, collection) and collection.stats(&"tilapia").count == 2, "migration seeds old journal IDs without double-counting legacy statistics")
 var first := record("first")
 expect(CatchSettlement.persist(profile, collection, first).saved, "landed event commits journal then collection")
 var writes := collection.writes
 expect(CatchSettlement.persist(profile, collection, first).saved and collection.stats(&"tilapia").count == 3 and profile.data.journal.size() == 2, "duplicate delivery updates neither journal nor collection twice")
 expect(collection.writes == writes, "duplicate delivery performs no collection disk write")
 # Simulate termination after journal commit but before collection commit.
 expect(profile.record_catch(record("interrupted"), false), "commit only the authoritative journal before simulated restart")
 collection.free()
 profile.free()
 profile = AnglerProfile.new()
 profile.save_path = path
 profile.load_profile()
 collection = CountingCollection.new()
 collection.save_path = collection_path
 collection.load_records()
 expect(collection.stats(&"tilapia").count == 3, "reopened collection reflects only its last durable commit")
 expect(CatchSettlement.reconcile(profile, collection) and collection.stats(&"tilapia").count == 4, "journal replay repairs a cross-file interruption after reopen")
 writes = collection.writes
 expect(CatchSettlement.reconcile(profile, collection) and collection.writes == writes, "second replay is idempotent and does not write")
 profile.save_path = "user://missing-%s/profile.cfg" % token
 var before_count: int = profile.data.journal.size()
 expect(not CatchSettlement.persist(profile, collection, record("profile-failure")).saved, "profile write failure blocks settlement")
 expect(profile.data.journal.size() == before_count and collection.stats(&"tilapia").count == 4, "profile failure rolls back the event without touching collection")
 profile.save_path = path
 expect(CatchSettlement.persist(profile, collection, record("profile-failure")).saved and collection.stats(&"tilapia").count == 5, "same event retries successfully once storage returns")
 collection.save_path = "user://missing-%s/collection.cfg" % token
 var failed := record("collection-failure")
 expect(not CatchSettlement.persist(profile, collection, failed).saved, "collection failure is reported after durable journal commit")
 expect(not CatchSettlement.persist(profile, collection, failed).saved and collection.stats(&"tilapia").count == 6, "retry while unavailable cannot inflate in-memory statistics")
 collection.save_path = collection_path
 expect(CatchSettlement.persist(profile, collection, failed).saved and collection.stats(&"tilapia").count == 6, "retry persists pending collection data without recounting")
 collection.load_records()
 expect(collection.stats(&"tilapia").count == 6, "collection statistics and applied IDs survive disk reload together")
 collection.save_path = "user://missing-%s/collection.cfg" % token
 expect(not CatchSettlement.persist(profile, collection, record("crash-after-error")).saved, "failed collection write leaves replayable journal event")
 collection.free()
 collection = CountingCollection.new()
 collection.save_path = collection_path
 collection.load_records()
 profile.load_profile()
 expect(CatchSettlement.reconcile(profile, collection) and collection.stats(&"tilapia").count == 7, "restart after failed collection write repairs the missing event exactly once")
 # Recovery must batch collection writes, even after a long offline gap.
 for index in 100:
  profile.data.journal.append(record("batch-%d" % index))
 expect(ProfileStore.save_profile(path, profile.data) == OK, "persist a batch of recoverable journal events")
 collection.writes = 0
 expect(CatchSettlement.reconcile(profile, collection) and collection.stats(&"tilapia").count == 107, "batch replay restores all 100 missing catches")
 expect(collection.writes == 1, "100 replayed events require a single atomic collection write")
 # Exercise the real controller gate: collection IO failure must keep RESULT
 # and the actual fish, not merely return an error from the service in isolation.
 var game: Node3D = load("res://features/gameplay/gameplay.tscn").instantiate()
 game.economy_enabled = false
 root.add_child(game)
 game.set_process(false)
 game.get_node("FishingEffects").audio_enabled = false
 var fishing: FishingController = game.get_node("FishingController")
 var pond: PondEcosystem = game.get_node("PondEcosystem")
 fishing.set_physics_process(false)
 pond.set_physics_process(false)
 game.profile = profile
 game.collection = collection
 fishing.bind_profile(profile, collection)
 var fish: FishState = pond.fish[0]
 fish.weight = 1.0
 fish.state = &"landed"
 var fish_id := fish.id
 fishing.active_fish = fish
 fishing.catch_event_id = "controller-event"
 fishing._change_state(FishingController.State.RESULT)
 collection.save_path = "user://missing-%s/collection.cfg" % token
 game._on_fish_landed(fish)
 fishing.resolve_catch(true)
 expect(fishing.state == FishingController.State.RESULT and fish in pond.fish and profile.data.catches.is_empty(), "collection failure blocks Keep and preserves the result and original fish")
 collection.save_path = collection_path
 fishing.resolve_catch(true)
 expect(fishing.state == FishingController.State.READY and fish not in pond.fish and profile.data.catches.size() == 1, "restored collection storage allows Keep exactly once")
 var stored_population: Array = profile.data.ponds.river
 var retained := false
 for saved_fish in stored_population:
  retained = retained or saved_fish.id == fish_id
 expect(not retained, "storage and population removal commit together in the profile file")
 fishing.resolve_catch(true)
 expect(profile.data.catches.size() == 1, "duplicate Keep after resolution cannot duplicate inventory")
 game.queue_free()
 await process_frame
 await process_frame
 # An initialized but EMPTY collection still needs its durable marker on reload.
 var empty_profile := AnglerProfile.new()
 empty_profile.data = empty_profile.defaults()
 empty_profile.save_path = "user://empty-profile-%s.cfg" % token
 var empty := CountingCollection.new()
 empty.save_path = "user://empty-collection-%s.cfg" % token
 expect(CatchSettlement.reconcile(empty_profile, empty), "initialize an empty collection before the first journal write")
 empty_profile.record_catch(record("empty-gap"), false)
 empty.load_records()
 expect(CatchSettlement.reconcile(empty_profile, empty) and empty.stats(&"tilapia").count == 1, "empty collection marker survives reload and replays its first interrupted catch")
 var missing := CountingCollection.new()
 missing.save_path = "user://missing-collection-file-%s.cfg" % token
 missing.load_records()
 expect(CatchSettlement.reconcile(empty_profile, missing) and missing.stats(&"tilapia").count == 1, "a genuinely missing collection file rebuilds known events instead of treating them as already counted")
 missing.free()
 # Future profile versions must remain byte-for-byte intact.
 var future := ConfigFile.new()
 future.set_value("meta", "version", 99)
 future.save(empty_profile.save_path)
 var bytes := FileAccess.get_file_as_bytes(empty_profile.save_path)
 empty_profile.load_profile()
 expect(empty_profile.incompatible and not CatchSettlement.persist(empty_profile, empty, record("future")).saved, "unsupported profile version blocks settlement")
 expect(bytes == FileAccess.get_file_as_bytes(empty_profile.save_path), "future profile bytes remain unchanged")
 # Preserve old v1 mission-less saves through additive in-memory migration.
 var old := profile.defaults()
 old.coins = 777
 old.line_remaining = 22.0
 old.erase("missions")
 future = ConfigFile.new()
 future.set_value("meta", "version", 1)
 future.set_value("profile", "data", old)
 future.save(empty_profile.save_path)
 empty_profile.load_profile()
 expect(not empty_profile.incompatible and empty_profile.data.coins == 777 and empty_profile.data.line_remaining == 22.0 and empty_profile.data.has("missions"), "ProfileStore preserves legacy balances and adds only missing mission defaults")
 # Malformed event metadata must not silently reseed or overwrite statistics.
 future = ConfigFile.new()
 future.set_value("meta", "version", 1)
 future.set_value("meta", "catch_events", ["invalid"])
 future.save(empty.save_path)
 bytes = FileAccess.get_file_as_bytes(empty.save_path)
 empty.load_records()
 expect(empty.incompatible_save and not empty.ensure_event_history([]) and not empty.save_records(), "malformed collection event metadata is protected")
 expect(bytes == FileAccess.get_file_as_bytes(empty.save_path), "malformed collection bytes remain unchanged")
 future.set_value("meta", "catch_events_initialized", true)
 future.set_value("meta", "catch_events", {"known-id": 0})
 future.set_value("fish", "tilapia", {"count": -1})
 future.save(empty.save_path)
 bytes = FileAccess.get_file_as_bytes(empty.save_path)
 empty.load_records()
 expect(empty.incompatible_save and not empty.save_records() and bytes == FileAccess.get_file_as_bytes(empty.save_path), "event-aware files protect corrupt statistics instead of discarding stats but retaining applied IDs")
 var blocked := FishingController.new()
 blocked._catch_collection = empty
 expect("สมุดสะสม" in blocked.cast_block_reason(), "incompatible collection blocks casting with a reason before bait is consumed")
 blocked.free()
 empty.free()
 empty_profile.free()
 collection.free()
 profile.free()
 print("CATCH SETTLEMENT RESULT: ", checks, " checks, ", failures, " failures")
 quit(1 if failures else 0)
