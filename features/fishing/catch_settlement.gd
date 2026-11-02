class_name CatchSettlement
extends RefCounted

## The profile journal is the durable event source; the collection stores
## applied event IDs atomically with its statistics. These are two writes, not
## a cross-file transaction. Replaying the journal repairs an interrupted gap.
static func reconcile(profile: AnglerProfile, collection: Node) -> bool:
 if profile.incompatible:
  return false
 if not collection.recording_enabled:
  return true
 CatchArchive.prepare(profile.data)
 var records := CatchArchive.replay_records(profile.data)
 if not collection.restore_archive(profile.data.history.stats, records): return false
 if not collection.ensure_event_history(records) or not collection.replay_events(records): return false
 if not profile.finish_catch_history(collection): return false
 collection.trim_event_history(profile.data)
 return true

static func persist(profile: AnglerProfile, collection: Node, record: Dictionary) -> Dictionary:
 if profile.incompatible:
  return {"saved": false, "error": profile.save_error, "outcome": {}}
 CatchArchive.prepare(profile.data)
 if not collection.ensure_event_history(CatchArchive.replay_records(profile.data)):
  return {"saved": false, "error": collection.save_error, "outcome": {}}
 if not profile.record_catch(record, bool(record.get("boss", false)), collection.recording_enabled):
  return {"saved": false, "error": profile.save_error, "outcome": {}}
 var outcome: Dictionary = collection.record_event_result(record)
 var saved: bool = not collection.recording_enabled or outcome.get("saved", false)
 if saved:
  saved = profile.finish_catch_history(collection)
  if saved: collection.trim_event_history(profile.data)
 return {"saved": saved, "error": "" if saved else (profile.save_error if not profile.save_error.is_empty() else collection.save_error), "outcome": outcome}

static func make_record(fish: FishState, profile: AnglerProfile, map_id: String, event_id: String, bait_id: String, depth: float, boss: bool, mission_eligible: bool, location: Dictionary = {}) -> Dictionary:
 var record := {"species": String(fish.species.id), "name": fish.species.display_name,
  "weight": fish.weight, "map": map_id, "depth": depth, "catch_id": event_id,
  "fish_key": map_id + ":" + fish.persistent_key,
  "bait_id": bait_id if not bait_id.is_empty() else str(profile.data.equipped.bait),
  "bait_kind": (profile.equipped("bait").kind if profile.equipped("bait") != null else "bait"), "boss": boss, "mission_eligible": mission_eligible,
  "bait": profile.equipment_name("bait"), "rod": profile.equipment_name("rod"),
  "reel": profile.equipment_name("reel"), "line": profile.equipment_name("line"),
  "time": Time.get_unix_time_from_system()}
 if FishingJournal.valid_location(location):
  record["location"] = location.duplicate(true)
 return record
