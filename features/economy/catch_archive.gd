class_name CatchArchive
extends RefCounted

const PER_SPECIES := 10
const RECENT_LIMIT := 128

static func defaults() -> Dictionary:
 return {"initialized": false, "stats": {}, "boss_counts": {}, "map_bests": {}, "recent_ids": [], "pending": []}

static func better(a: Dictionary, b: Dictionary) -> bool:
 if AnglerIdentity.grams(a) != AnglerIdentity.grams(b):
  return AnglerIdentity.grams(a) > AnglerIdentity.grams(b)
 if float(a.time) != float(b.time):
  return float(a.time) < float(b.time)
 return str(a.get("catch_id", "")) < str(b.get("catch_id", ""))

static func top(records: Array) -> Array:
 var ordered := records.duplicate()
 ordered.sort_custom(better)
 var counts := {}
 var kept: Array = []
 for record in ordered:
  var species := str(record.species)
  if int(counts.get(species, 0)) < PER_SPECIES:
   kept.append(record)
   counts[species] = int(counts.get(species, 0)) + 1
 # Keep the retained records chronological for journal/map callers.
 kept.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.time) < float(b.time))
 return kept

static func remember(history: Dictionary, record: Dictionary) -> void:
 var id := str(record.get("catch_id", ""))
 if not id.is_empty() and id not in history.recent_ids:
  history.recent_ids.append(id)
 while history.recent_ids.size() > RECENT_LIMIT:
  history.recent_ids.pop_front()
 var species := str(record.species)
 var entry: Dictionary = history.stats.get(species, {"count": 0, "total": 0.0, "best": 0.0, "smallest": 0.0, "last": 0.0}).duplicate()
 var weight := float(record.weight)
 entry.smallest = weight if entry.count == 0 else minf(entry.smallest, weight)
 entry.count += 1
 entry.total += weight
 entry.best = maxf(entry.best, weight)
 entry.last = weight
 history.stats[species] = entry
 var key := str(record.map) + ":" + species
 if not history.map_bests.has(key) or better(record, history.map_bests[key]):
  # Rankings need no full gear/location/fish snapshot for this extra summary.
  history.map_bests[key] = {"catch_id": id, "map": str(record.map), "species": species, "name": str(record.name), "weight": weight, "time": float(record.time)}

static func prepare(data: Dictionary) -> void:
 if not data.has("history"):
  data.history = defaults()
 if data.history.initialized:
  return
 for index in data.journal.size():
  var record: Dictionary = data.journal[index].duplicate(true)
  if str(record.get("catch_id", "")).is_empty():
   record["catch_id"] = "legacy_" + (str(index) + JSON.stringify(record)).sha256_text()
  data.journal[index] = record
  remember(data.history, record)
  data.history.pending.append(record)
 for record in data.boss_history:
  var map := str(record.map)
  data.history.boss_counts[map] = int(data.history.boss_counts.get(map, 0)) + 1
 data.history.initialized = true
 compact(data)

static func compact(data: Dictionary) -> void:
 data.journal = top(data.journal)
 # Boss details must not retain a second set of catches outside the same top ten.
 # Lifetime boss victories are kept separately in boss_counts.
 data.boss_history = data.boss_history.filter(func(record: Dictionary): return record in data.journal)
 for id in data.map_memory.notes.keys():
  if not FishingJournal.has_catch(data.journal, str(id)):
   data.map_memory.notes.erase(id)

static func contains(data: Dictionary, id: String) -> bool:
 if id.is_empty(): return false
 return id in data.history.recent_ids or FishingJournal.has_catch(data.journal, id) or FishingJournal.has_catch(data.history.pending, id)

static func replay_records(data: Dictionary) -> Array:
 var result: Array = data.history.pending.duplicate()
 var ids := {}
 for record in result: ids[str(record.get("catch_id", ""))] = true
 for record in data.journal:
  if not ids.has(str(record.get("catch_id", ""))): result.append(record)
 return result

static func valid(history: Variant) -> bool:
 if not history is Dictionary or not history.get("initialized") is bool:
  return false
 for key in ["stats", "boss_counts", "map_bests"]:
  if not history.get(key) is Dictionary: return false
 for key in ["recent_ids", "pending"]:
  if not history.get(key) is Array: return false
 if history.recent_ids.size() > RECENT_LIMIT: return false
 for id in history.recent_ids:
  if not id is String or id.is_empty(): return false
 for count in history.boss_counts.values():
  if not count is int or count < 0: return false
 for stats in history.stats.values():
  if not stats is Dictionary or not stats.get("count") is int or stats.count < 1: return false
  for key in ["total", "best", "smallest", "last"]:
   if not (stats.get(key) is float or stats.get(key) is int) or not is_finite(float(stats[key])) or stats[key] <= 0: return false
 for record in history.map_bests.values():
  if not record is Dictionary or not record.get("species") is String or not record.get("map") is String or not record.get("name") is String or not record.get("catch_id") is String: return false
  for key in ["weight", "time"]:
   if not (record.get(key) is float or record.get(key) is int) or not is_finite(float(record[key])) or record[key] < 0: return false
  if record.weight <= 0: return false
 return true
