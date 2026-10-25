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
 return collection.ensure_event_history(profile.data.journal) and collection.replay_events(profile.data.journal)

static func persist(profile: AnglerProfile, collection: Node, record: Dictionary) -> Dictionary:
 if profile.incompatible:
  return {"saved": false, "error": profile.save_error, "outcome": {}}
 if not collection.ensure_event_history(profile.data.journal):
  return {"saved": false, "error": collection.save_error, "outcome": {}}
 if not profile.record_catch(record, bool(record.get("boss", false))):
  return {"saved": false, "error": profile.save_error, "outcome": {}}
 var outcome: Dictionary = collection.record_event_result(record)
 var saved: bool = not collection.recording_enabled or outcome.get("saved", false)
 return {"saved": saved, "error": "" if saved else collection.save_error, "outcome": outcome}

static func make_record(fish: FishState, profile: AnglerProfile, map_id: String, event_id: String, bait_id: String, depth: float, boss: bool, mission_eligible: bool) -> Dictionary:
 return {"species": String(fish.species.id), "name": fish.species.display_name,
  "weight": fish.weight, "map": map_id, "depth": depth, "catch_id": event_id,
  "fish_key": map_id + ":" + fish.persistent_key,
  "bait_id": bait_id if not bait_id.is_empty() else String(profile.equipped("bait").id),
  "bait_kind": profile.equipped("bait").kind, "boss": boss, "mission_eligible": mission_eligible,
  "bait": profile.equipped("bait").display_name, "rod": profile.equipped("rod").display_name,
  "reel": profile.equipped("reel").display_name, "line": profile.equipped("line").display_name,
  "time": Time.get_unix_time_from_system()}
