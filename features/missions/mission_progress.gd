class_name MissionProgress
extends RefCounted

const Catalog = preload("res://features/missions/mission_catalog.gd")

static func defaults() -> Dictionary:
 return {"started": false, "tracked": "", "entries": {}}

static func valid(value: Variant) -> bool:
 if not value is Dictionary or not value.get("started") is bool or not value.get("tracked") is String or not value.get("entries") is Dictionary:
  return false
 for id in value.entries:
  var entry: Variant = value.entries[id]
  if not id is String or not entry is Dictionary:
   return false
  if not entry.get("revision") is int or entry.revision < 1 or not entry.get("claimed") is bool:
   return false
  if not (entry.get("progress") is int or entry.get("progress") is float) or not is_finite(float(entry.progress)) or entry.progress < 0:
   return false
  for key in ["seen", "unique"]:
   if not entry.get(key) is Array:
    return false
   for token in entry[key]:
    if not token is String or token.is_empty():
     return false
 return true

static func entry(state: Dictionary, definition: MissionDefinition) -> Dictionary:
 var stored: Dictionary = state.entries.get(definition.id, {})
 # Claimed rewards never become claimable again when content is revised.
 if stored.is_empty() or (stored.revision != definition.revision and not stored.claimed):
  return {"revision": definition.revision, "progress": 0.0, "claimed": false, "seen": [], "unique": []}
 return stored.duplicate(true)

static func completed(state: Dictionary, definition: MissionDefinition) -> bool:
 var value := entry(state, definition)
 return value.claimed or value.progress >= definition.target

static func apply_catch(state: Dictionary, record: Dictionary) -> Array[String]:
 var newly_complete: Array[String] = []
 if not state.started or str(record.get("catch_id", "")).is_empty() or str(record.get("fish_key", "")).is_empty():
  return newly_complete
 for definition in Catalog.ALL_ITEMS:
  var value := entry(state, definition)
  if value.claimed or value.progress >= definition.target or not definition.matches(record):
   continue
  # A fish instance may contribute only once to each permanent mission, even
  # after being released, recaught or restored from a saved population.
  var token: String = record.fish_key
  if token in value.seen:
   continue
  if definition.metric in ["species", "baits"]:
   var unique_token: String = str(record.get("species", "") if definition.metric == "species" else record.get("bait_id", ""))
   if unique_token.is_empty() or unique_token in value.unique:
    continue
  value.seen.append(token)
  match definition.metric:
   "weight": value.progress += float(record.weight)
   "species", "baits":
    var unique: String = str(record.species if definition.metric == "species" else record.bait_id)
    if unique not in value.unique:
     value.unique.append(unique)
    value.progress = float(value.unique.size())
   _: value.progress += 1.0
  value.progress = minf(value.progress, definition.target)
  state.entries[definition.id] = value
  if value.progress >= definition.target:
   newly_complete.append(definition.id)
 return newly_complete

static func progress_text(state: Dictionary, definition: MissionDefinition) -> String:
 var value := entry(state, definition)
 if definition.metric == "weight":
  return "%.1f / %.1f กก." % [value.progress, definition.target]
 return "%d / %d" % [int(value.progress), int(definition.target)]
