extends SceneTree

var failures := 0
var checks := 0
var serial := 0

func _initialize() -> void:
 call_deferred("run")

func expect(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL: " + message)
 else:
  print("PASS: ", message)

func record(species: String = "tilapia", weight: float = 1.2, bait: String = "worm", depth: float = 1.0) -> Dictionary:
 serial += 1
 return {"catch_id": "event-%d" % serial, "fish_key": "river:fish-%d" % serial,
  "species": species, "name": "ปลา", "weight": weight, "map": "river", "depth": depth,
  "bait_id": bait, "bait_kind": "bait" if bait in ["worm", "dough"] else "lure",
  "bait": bait, "rod": "light_rod", "reel": "basic_reel", "line": "nylon", "time": 1.0}

func progress(profile: AnglerProfile, id: String) -> float:
 return MissionProgress.entry(profile.data.missions, MissionCatalog.find(id)).progress

func fresh() -> AnglerProfile:
 var profile := AnglerProfile.new()
 profile.save_path = "user://missions-%d-%d.cfg" % [Time.get_ticks_usec(), serial]
 root.add_child(profile)
 return profile

func run() -> void:
 var profile := fresh()
 expect(MissionCatalog.ITEMS.size() == 12, "catalog contains twelve missions")
 for tier in 4:
  var count := 0
  for definition in MissionCatalog.ITEMS:
   count += int(definition.tier == tier)
  expect(count == 3, "three missions per tier %d" % tier)
 var ids := {}
 var pond := PondEcosystem.new()
 root.add_child(pond)
 for definition in MissionCatalog.ITEMS:
  expect(not ids.has(definition.id) and definition.target > 0 and definition.reward_coins > 0, "valid stable mission " + definition.id)
  ids[definition.id] = true
  if not definition.species_id.is_empty():
   var found := false
   for fish in pond.fish:
    found = found or (String(fish.species.id) == definition.species_id and fish.species.max_weight >= definition.minimum_weight)
   expect(found, "target species and weight available " + definition.id)
 expect(profile.record_catch(record(), false) and progress(profile, "first_three") == 0, "tutorial catches do not advance missions")
 expect(profile.start_missions(), "missions start after tutorial")
 expect(not profile.claim_mission("first_three") and not profile.claim_mission("unknown"), "incomplete and unknown claims denied")
 var a := record()
 expect(profile.record_catch(a, false), "landed event commits")
 expect(progress(profile, "first_three") == 1 and progress(profile, "large_tilapia") == 1, "one fish advances all matching missions")
 var journal_size: int = profile.data.journal.size()
 expect(profile.record_catch(a, false) and profile.data.journal.size() == journal_size and progress(profile, "first_three") == 1, "event replay changes neither journal nor progress")
 var recaught := a.duplicate(true)
 recaught.catch_id = "new-event-same-fish"
 expect(profile.record_catch(recaught, false) and progress(profile, "first_three") == 1, "released fish recaught with new event cannot farm progress")
 var other_map := record()
 other_map.map = "other"
 profile.record_catch(other_map, false)
 expect(progress(profile, "first_three") == 1, "wrong map excluded")
 profile.record_catch(record("tilapia", 0.9, "dough"), false)
 expect(progress(profile, "natural_pair") == 2 and progress(profile, "two_species") == 1, "distinct bait and species counters use unique values")
 profile.record_catch(record("snakehead", 2.5, "minnow", 2.0), false)
 expect(progress(profile, "first_three") == 3 and progress(profile, "two_species") == 2, "count and diversity missions complete")
 expect(progress(profile, "lure_hunter") == 1 and progress(profile, "large_snakehead") == 1 and progress(profile, "deep_catch") == 1, "species bait weight and inclusive depth filters match")
 expect(is_equal_approx(progress(profile, "five_kilos"), 4.6), "weight sums unique qualifying catches")
 profile.record_catch(record("catfish", 2.0, "worm", 4.0), true)
 expect(progress(profile, "five_kilos") == 5 and progress(profile, "deep_catch") == 2 and progress(profile, "pond_champion") == 1, "weight capped depth upper boundary and boss use actual event")
 var coins: int = profile.data.coins
 expect(profile.track_mission("first_three") and profile.claim_mission("first_three"), "track and claim completed mission")
 expect(profile.data.coins == coins + 20 and profile.data.missions.tracked.is_empty(), "claim pays exact reward and clears completed tracker")
 expect(not profile.claim_mission("first_three") and profile.data.coins == coins + 20, "second claim cannot mint coins")
 var reloaded := fresh()
 reloaded.save_path = profile.save_path
 reloaded.load_profile()
 expect(not reloaded.incompatible and reloaded.data == profile.data, "restart restores progress receipts and balance")
 expect(not reloaded.claim_mission("first_three"), "claimed reward remains blocked after reload")
 var original_path := profile.save_path
 profile.save_path = "user://missing-mission-directory/profile.cfg"
 var before := profile.data.duplicate(true)
 expect(not profile.claim_mission("tilapia_pair") and profile.data == before, "failed save rolls back both coins and claimed flag")
 expect(not profile.record_catch(record("koi"), false) and profile.data == before, "failed catch save rolls back journal and progress together")
 profile.save_path = original_path
 expect(profile.claim_mission("tilapia_pair"), "failed claim can safely retry")
 var definition := MissionCatalog.find("large_tilapia").duplicate() as MissionDefinition
 definition.revision += 1
 expect(MissionProgress.entry(profile.data.missions, definition).progress == 0, "unclaimed changed revision resets only its progress")
 definition = MissionCatalog.find("first_three").duplicate() as MissionDefinition
 definition.revision += 1
 expect(MissionProgress.entry(profile.data.missions, definition).claimed, "revision change never reopens a claimed reward")
 var legacy := fresh()
 var config := ConfigFile.new()
 var legacy_data := legacy.defaults()
 legacy_data.erase("missions")
 legacy_data.coins = 912
 config.set_value("meta", "version", 1)
 config.set_value("profile", "data", legacy_data)
 config.save(legacy.save_path)
 legacy.load_profile()
 expect(not legacy.incompatible and legacy.data.coins == 912 and not legacy.data.missions.started, "legacy v1 migration preserves balance and starts with no retrospective progress")
 var corrupt := legacy.data.duplicate(true)
 corrupt.missions.entries = {"bad": {"revision": 1, "progress": NAN, "claimed": false, "seen": [], "unique": []}}
 expect(not legacy._valid(corrupt), "nonfinite mission save rejected")
 var identity: String = pond.fish[0].persistent_key
 var snapshot := pond.snapshot()
 expect(pond.restore(snapshot) and pond.fish[0].persistent_key == identity, "fish identity survives pond save and reload")
 for entry in snapshot:
  entry.erase("persistent_key")
 expect(pond.restore(snapshot), "legacy population without keys migrates")
 identity = pond.fish[0].persistent_key
 expect(pond.restore(snapshot) and pond.fish[0].persistent_key == identity, "legacy fish identity migration deterministic")
 var all_missions := fresh()
 all_missions.start_missions()
 all_missions.record_catch(record("tilapia", 1.2, "worm", 2.0), false)
 all_missions.record_catch(record("tilapia", 1.3, "dough", 3.0), false)
 all_missions.record_catch(record("snakehead", 2.5, "minnow", 1.0), true)
 for species_id in ["catfish", "gourami", "koi", "hampala"]:
  all_missions.record_catch(record(species_id), false)
 var total_reward := 0
 for mission in MissionCatalog.ITEMS:
  expect(MissionProgress.completed(all_missions.data.missions, mission), "content can complete " + mission.id)
  expect(all_missions.claim_mission(mission.id), "content reward claim " + mission.id)
  total_reward += mission.reward_coins
 expect(all_missions.data.coins == 350 + total_reward, "all twelve rewards total exactly catalog sum")
 # Authored hierarchy exists before entering the SceneTree or running _ready.
 var row := load("res://features/missions/mission_row.tscn").instantiate() as Control
 expect(row.has_node("Content/Description") and row.has_node("Content/Footer/Claim") and row.has_node("Content/Progress"), "editable row controls exist before Play")
 row.free()
 var panel := load("res://features/missions/mission_panel.tscn").instantiate() as Control
 expect(panel.has_node("Card/Content/Tiers") and panel.has_node("Card/Content/Scroll/Rows"), "editable modal layout exists before Play")
 panel.free()
 all_missions.free()
 pond.free()
 profile.free()
 reloaded.free()
 legacy.free()
 print("MISSIONS RESULT: ", checks, " checks, ", failures, " failures")
 quit(0 if failures == 0 else 1)
