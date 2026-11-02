class_name FishingJournal
extends RefCounted
## Journal entries remain immutable. User annotations are a separate mutable domain.
static func defaults() -> Dictionary:
 return {"favorites": [], "notes": {}, "next_spot": 1}

static func known_map(id: String) -> bool:
 for entry in RegionCatalog.MAPS:
  if entry.id == id:
   return true
 return false

static func valid_point(point: Variant) -> bool:
 return point is Vector2 and point.is_finite() and absf(point.x) < 100000 and absf(point.y) < 100000

static func valid_location(value: Variant) -> bool:
 return value is Dictionary and valid_point(value.get("angler_xz")) and valid_point(value.get("bite_xz")) and value.get("from_boat") is bool

static func valid_memory(value: Variant) -> bool:
 if not value is Dictionary or not value.get("favorites") is Array or not value.get("notes") is Dictionary or not value.get("next_spot") is int or value.next_spot < 1:
  return false
 if value.favorites.size() > 200:
  return false
 var ids := {}
 for spot in value.favorites:
  if not spot is Dictionary or not spot.get("id") is String or spot.id.is_empty() or ids.has(spot.id):
   return false
  if not spot.get("map") is String or not known_map(spot.map) or not valid_point(spot.get("position")) or not spot.get("from_boat") is bool or not spot.get("name") is String or spot.name.length() > 80:
   return false
  ids[spot.id] = true
 for id in value.notes:
  if not id is String or id.is_empty() or not value.notes[id] is String or value.notes[id].length() > 240:
   return false
 return true

static func has_catch(journal: Array, id: String) -> bool:
 if id.is_empty():
  return false
 for record in journal:
  if record.get("catch_id", "") == id:
   return true
 return false

static func history(journal: Array, map: String, species: String = "") -> Array:
 var result: Array = []
 for index in range(journal.size() - 1, -1, -1):
  var record: Dictionary = journal[index]
  if record.map == map and (species.is_empty() or record.species == species):
   result.append(record)
 return result
