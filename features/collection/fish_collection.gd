extends Node

signal changed
const Catalog = preload("res://data/fish/fish_catalog.gd")
const SPECIES = Catalog.ALL_SPECIES
var save_path := PlayerSavePaths.COLLECTION
var records: Dictionary = {}
var save_error := ""
var recording_enabled := true
var incompatible_save := false
var _catch_events: Dictionary = {}
var _events_initialized := false
var _events_dirty := false
var _records_missing := true

func _ready() -> void:
 load_records()

func stats(id: StringName) -> Dictionary:
 return records.get(String(id), {"count": 0, "total": 0.0, "best": 0.0, "smallest": 0.0, "last": 0.0}).duplicate()

func record_catch(fish: RefCounted) -> String:
 var outcome := record_catch_result(fish)
 return catch_message(outcome)

static func catch_message(outcome: Dictionary) -> String:
 if outcome.is_empty():
  return ""
 if outcome.new_species:
  return "ค้นพบปลาชนิดใหม่!"
 if outcome.new_record:
  return "สถิติน้ำหนักใหม่!"
 return "บันทึกลงสมุดสะสมแล้ว"

func record_catch_result(fish: RefCounted) -> Dictionary:
 if not recording_enabled or fish == null or fish.species == null or not is_finite(fish.weight) or fish.weight <= 0:
  return {}
 var entry := stats(fish.species.id)
 var outcome := {"new_species": entry.count == 0, "new_record": fish.weight > entry.best}
 entry.smallest = fish.weight if entry.count == 0 else minf(entry.smallest, fish.weight)
 entry.count += 1
 entry.total += fish.weight
 entry.best = maxf(entry.best, fish.weight)
 entry.last = fish.weight
 records[String(fish.species.id)] = entry
 outcome.saved = save_records()
 changed.emit()
 return outcome

func save_records() -> bool:
 if incompatible_save:
  return false
 var error := CollectionStore.save_records(save_path, records, _catch_events, _events_initialized)
 if error == OK:
  _events_dirty = false
  _records_missing = false
 save_error = "" if error == OK else "บันทึกไม่สำเร็จ สถิติยังอยู่ในรอบนี้"
 return error == OK

func load_records() -> void:
 var result := CollectionStore.load_records(save_path)
 records = result.records
 incompatible_save = result.incompatible
 _catch_events = result.get("events", {})
 _events_initialized = result.get("events_initialized", false)
 _events_dirty = false
 _records_missing = result.get("missing", false)
 save_error = "" if result.error == OK else "อ่านสมุดสะสมเดิมไม่สำเร็จ"

func ensure_event_history(journal: Array) -> bool:
 if not recording_enabled:
  return true
 if incompatible_save:
  return false
 if _events_initialized:
  return true
 # Existing v1 journals were already counted by the old app. Establish their
 # baseline without incrementing statistics, before any NEW journal commit.
 var before := _catch_events.duplicate()
 if not _records_missing or not records.is_empty():
  for record in journal:
   var id := str(record.get("catch_id", ""))
   if not id.is_empty():
    _catch_events[id] = 0
 _events_initialized = true
 if not save_records():
  _events_initialized = false
  _catch_events = before
  return false
 return true

func _stage_event(record: Dictionary) -> Dictionary:
 if not recording_enabled:
  return {}
 if incompatible_save or not _events_initialized:
  return {}
 var id := str(record.get("catch_id", ""))
 var species := str(record.get("species", ""))
 var weight := float(record.get("weight", 0.0))
 if id.is_empty() or species.is_empty() or not is_finite(weight) or weight <= 0:
  save_error = "ข้อมูลการจับปลาไม่ถูกต้อง"
  return {}
 var changed_stats := false
 if not _catch_events.has(id):
  var entry := stats(StringName(species))
  var flags := int(entry.count == 0) | (int(weight > entry.best) << 1)
  entry.smallest = weight if entry.count == 0 else minf(entry.smallest, weight)
  entry.count += 1
  entry.total += weight
  entry.best = maxf(entry.best, weight)
  entry.last = weight
  records[species] = entry
  _catch_events[id] = flags
  _events_dirty = true
  changed_stats = true
 var flags: int = _catch_events[id]
 return {"new_species": bool(flags & 1), "new_record": bool(flags & 2), "changed": changed_stats}

func record_event_result(record: Dictionary) -> Dictionary:
 var outcome := _stage_event(record)
 if outcome.is_empty():
  return {}
 var changed_stats: bool = outcome.changed
 outcome.erase("changed")
 outcome.saved = save_records() if _events_dirty else true
 if changed_stats or not outcome.saved:
  changed.emit()
 return outcome

func replay_events(journal: Array) -> bool:
 if not recording_enabled:
  return true
 if incompatible_save or not _events_initialized:
  return false
 var changed_stats := false
 for record in journal:
  var id := str(record.get("catch_id", ""))
  if id.is_empty() or _catch_events.has(id):
   continue
  var outcome := _stage_event(record)
  if outcome.is_empty():
   return false
  changed_stats = changed_stats or outcome.changed
 var saved := save_records() if _events_dirty else true
 if changed_stats or not saved:
  changed.emit()
 return saved
