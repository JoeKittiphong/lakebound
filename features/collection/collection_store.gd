class_name CollectionStore
extends RefCounted

static func save_records(save_path: String, records: Dictionary) -> Error:
 var config := ConfigFile.new()
 config.set_value("meta", "version", 1)
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
  return {"records": records, "error": OK, "incompatible": false}
 if error != OK or config.get_value("meta", "version", 0) != 1:
  return {"records": records, "error": error if error != OK else ERR_INVALID_DATA, "incompatible": true}
 if not config.has_section("fish"):
  return {"records": records, "error": OK, "incompatible": false}
 for id in config.get_section_keys("fish"):
  var entry = config.get_value("fish", id)
  if not entry is Dictionary:
   continue
  var valid := true
  for key in ["count", "total", "best", "smallest", "last"]:
   if not entry.has(key) or not (entry[key] is float or entry[key] is int):
    valid = false
   elif not is_finite(float(entry[key])) or entry[key] <= 0:
    valid = false
  if valid and entry.best >= entry.smallest and entry.total >= entry.best:
   records[id] = entry

 return {"records": records, "error": OK, "incompatible": false}
