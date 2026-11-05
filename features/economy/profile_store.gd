class_name ProfileStore
extends RefCounted

const Catalog = preload("res://data/equipment/tackle_catalog.gd")
const Travel = preload("res://features/gameplay/map_travel_state.gd")

static func defaults() -> Dictionary:
 return {"terminal_rig": "float", "identity": AnglerIdentity.create(), "coins": 350, "diamonds": 0, "stock": {"worm": 20, "dough": 10, "minnow": 1, "light_rod": 1, "basic_reel": 1, "small_box": 1},
  "equipped": {"bait": "worm", "lure": "minnow", "rod": "light_rod", "reel": "basic_reel", "box": "small_box", "line": "nylon", "boat": ""},
  "line_remaining": 65.0, "spares": {}, "stored_lines": {}, "catches": [], "journal": [], "boss_history": [], "ponds": {}, "pond_revisions": {}, "travel": {}, "pending": {}, "receipts": [], "missions": MissionProgress.defaults(), "map_memory": FishingJournal.defaults(), "history": CatchArchive.defaults(), "cloud": CloudOutbox.defaults()}

static func valid(value: Variant) -> bool:
 if not value is Dictionary:
  return false
 var expected := defaults()
 for key in expected:
  if not value.has(key) or typeof(value[key]) != typeof(expected[key]):
   return false
 if not CloudOutbox.valid(value.cloud): return false
 for map_id in value.travel:
  if not map_id is String or not FishingJournal.known_map(map_id) or not Travel.valid(value.travel[map_id]): return false
 if not AnglerIdentity.valid(value.identity):
  return false
 if value.coins < 0 or value.diamonds < 0 or not is_finite(value.line_remaining) or value.line_remaining < 0:
  return false
 if not MissionProgress.valid(value.missions):
  return false
 if not FishingJournal.valid_memory(value.map_memory):
  return false
 if not CatchArchive.valid(value.history):
  return false
 for slot in expected.equipped:
  if not value.equipped.has(slot) or not value.equipped[slot] is String: return false
  if value.equipped[slot].is_empty() and slot in ["rod", "reel", "line", "bait", "box", "boat"]: continue
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
 var line := Catalog.item(str(value.equipped.line))
 if (line == null and value.line_remaining != 0) or (line != null and value.line_remaining > line.length):
  return false
 for id in value.stored_lines:
  var stored := Catalog.item(str(id))
  if stored == null or stored.kind != "line" or not value.stored_lines[id] is Array: return false
  for length in value.stored_lines[id]:
   if not (length is float or length is int) or not is_finite(float(length)) or length <= 0 or length > stored.length: return false
 if not value.pending.is_empty():
  var lure := Catalog.item(str(value.pending.get("lure", "")))
  if lure == null or lure.kind != "lure" or not value.pending.get("id") is String or str(value.pending.id).is_empty() or value.pending.get("cost", -1) != lure.recovery_cost:
   return false
 for receipt in value.receipts:
  if not receipt is String or receipt.is_empty():
   return false
 for entries in [value.catches, value.journal, value.boss_history, value.history.pending]:
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
   if record.has("location") and not FishingJournal.valid_location(record.location):
    return false
 for map_id in value.pond_revisions:
  if not map_id is String or not value.pond_revisions[map_id] is String:return false
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
 if saved is Dictionary and saved.get("equipped") is Dictionary and not saved.equipped.has("boat"): saved.equipped["boat"] = ""
 if saved is Dictionary: saved["travel"] = Travel.clean_memory(saved.get("travel",{}))
 if saved is Dictionary and not saved.has("cloud"): saved["cloud"] = CloudOutbox.defaults()
 if saved is Dictionary and not saved.has("stored_lines"): saved["stored_lines"] = {}
 if saved is Dictionary and not saved.has("identity"):
  saved["identity"] = AnglerIdentity.create()
 if saved is Dictionary and not saved.has("missions"):
  saved["missions"] = MissionProgress.defaults()
 if saved is Dictionary and not saved.has("map_memory"):
  saved["map_memory"] = FishingJournal.defaults()
 if saved is Dictionary and not saved.has("history"):
  saved["history"] = CatchArchive.defaults()
 if saved is Dictionary and not saved.has("pond_revisions"):saved["pond_revisions"]={}
 if saved is Dictionary and not saved.has("terminal_rig"): saved["terminal_rig"] = ""
 if not valid(saved):
  result.incompatible = true
  result.error = ERR_INVALID_DATA
  result.invalid_data = true
  return result
 CatchArchive.prepare(saved)
 result.data = saved
 return result

static func save_profile(path: String, value: Dictionary) -> Error:
 var config := ConfigFile.new()
 config.set_value("meta", "version", 1)
 config.set_value("profile", "data", value)
 return AtomicConfig.save(config, path)
