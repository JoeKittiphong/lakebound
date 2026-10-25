class_name CollectionStore
extends RefCounted

static func save_records(save_path: String, records: Dictionary, events: Dictionary = {}, events_initialized: bool = false) -> Error:
 var config := ConfigFile.new()
 config.set_value("meta", "version", 1)
 if events_initialized:
  config.set_value("meta", "catch_events_initialized", true)
  config.set_value("meta", "catch_events", events)
 for id in records:
  config.set_value("fish", id, records[id])
 var error := config.save(save_path + ".tmp")
 if error == OK:
  error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
 return error

static func load_records(save_path: String) -> Dictionary:
 var records := {}
 var config := ConfigFile.new()
 var error := config.load(save_path)
 if error == ERR_FILE_NOT_FOUND:
  return {"records": records, "error": OK, "incompatible": false, "missing": true}
 if error != OK or config.get_value("meta", "version", 0) != 1:
  return {"records": records, "error": error if error != OK else ERR_INVALID_DATA, "incompatible": true}
 var initialized = config.get_value("meta", "catch_events_initialized", false)
 var events = config.get_value("meta", "catch_events", {})
 if not initialized is bool or not events is Dictionary:
  return {"records": {}, "error": ERR_INVALID_DATA, "incompatible": true}
 for id in events:
  if not id is String or id.is_empty() or not events[id] is int or events[id] < 0 or events[id] > 3:
   return {"records": {}, "error": ERR_INVALID_DATA, "incompatible": true}
 if not initialized and not events.is_empty():
  return {"records": {}, "error": ERR_INVALID_DATA, "incompatible": true}
 var ids := config.get_section_keys("fish") if config.has_section("fish") else PackedStringArray()
 for id in ids:
  var entry = config.get_value("fish", id)
  if not entry is Dictionary:
   if initialized:
    return {"records": {}, "error": ERR_INVALID_DATA, "incompatible": true}
   continue
  var valid := true
  for key in ["count", "total", "best", "smallest", "last"]:
   if not entry.has(key) or not (entry[key] is float or entry[key] is int):
    valid = false
   elif not is_finite(float(entry[key])) or entry[key] <= 0:
    valid = false
  if valid and entry.best >= entry.smallest and entry.total >= entry.best:
   records[id] = entry
  elif initialized:
   # With applied event IDs, dropping corrupt statistics would leave those
   # events marked as counted forever. Protect the file rather than overwriting.
   return {"records": {}, "error": ERR_INVALID_DATA, "incompatible": true}

 return {"records": records, "error": OK, "incompatible": false, "events": events, "events_initialized": initialized}
