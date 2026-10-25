class_name ProfileStore
extends RefCounted

const Catalog = preload("res://data/equipment/tackle_catalog.gd")

static func defaults() -> Dictionary:
 return {"coins": 350, "diamonds": 0, "stock": {"worm": 20, "dough": 10, "minnow": 1, "light_rod": 1, "basic_reel": 1, "small_box": 1},
  "equipped": {"bait": "worm", "lure": "minnow", "rod": "light_rod", "reel": "basic_reel", "box": "small_box", "line": "nylon"},
  "line_remaining": 65.0, "spares": {}, "catches": [], "journal": [], "boss_history": [], "ponds": {}, "pending": {}, "receipts": [], "missions": MissionProgress.defaults()}

static func valid(value: Variant) -> bool:
 if not value is Dictionary:
  return false
 var expected := defaults()
 for key in expected:
  if not value.has(key) or typeof(value[key]) != typeof(expected[key]):
   return false
 if value.coins < 0 or value.diamonds < 0 or not is_finite(value.line_remaining) or value.line_remaining < 0:
  return false
 if not MissionProgress.valid(value.missions):
  return false
 for slot in expected.equipped:
  var entry := Catalog.item(str(value.equipped.get(slot, "")))
  if entry == null or (entry.kind != slot and not (slot == "bait" and entry.kind == "lure")):
   return false
 for key in value.stock:
  if Catalog.item(str(key)) == null or not value.stock[key] is int or value.stock[key] < 0:
   return false
 for key in value.spares:
  var spare := Catalog.item(str(key))
  if spare == null or spare.kind != "line" or not value.spares[key] is int or value.spares[key] < 0:
   return false
 if value.line_remaining > Catalog.item(str(value.equipped.line)).length:
  return false
 if not value.pending.is_empty():
  var lure := Catalog.item(str(value.pending.get("lure", "")))
  if lure == null or lure.kind != "lure" or not value.pending.get("id") is String or str(value.pending.id).is_empty() or value.pending.get("cost", -1) != lure.recovery_cost:
   return false
 for receipt in value.receipts:
  if not receipt is String or receipt.is_empty():
   return false
 for entries in [value.catches, value.journal, value.boss_history]:
  for record in entries:
   if not record is Dictionary:
    return false
   for key in ["name", "map", "bait", "rod", "reel", "line", "species"]:
    if not record.get(key) is String:
     return false
   for key in ["weight", "depth", "time"]:
    if not (record.get(key) is float or record.get(key) is int) or not is_finite(float(record[key])) or record[key] < 0:
     return false
   if record.weight <= 0:
    return false
 for map_id in value.ponds:
  if not map_id is String or not value.ponds[map_id] is Array:
   return false
 return true

static func load_profile(path: String) -> Dictionary:
 var result := {"data": defaults(), "incompatible": false, "error": OK, "invalid_data": false}
 var config := ConfigFile.new()
 var error := config.load(path)
 if error == ERR_FILE_NOT_FOUND:
  return result
 if error != OK or config.get_value("meta", "version", 0) != 1:
  result.incompatible = true
  result.error = error if error != OK else ERR_INVALID_DATA
  return result
 var saved = config.get_value("profile", "data", {})
 if saved is Dictionary and not saved.has("missions"):
  saved["missions"] = MissionProgress.defaults()
 if not valid(saved):
  result.incompatible = true
  result.error = ERR_INVALID_DATA
  result.invalid_data = true
  return result
 result.data = saved
 return result

static func save_profile(path: String, value: Dictionary) -> Error:
 var config := ConfigFile.new()
 config.set_value("meta", "version", 1)
 config.set_value("profile", "data", value)
 var error := config.save(path + ".tmp")
 if error == OK:
  error = DirAccess.rename_absolute(path + ".tmp", path)
 return error
