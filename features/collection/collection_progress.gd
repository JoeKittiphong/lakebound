extends RefCounted
const Membership = preload("res://data/regions/collection_species.gd")
const Catalog = preload("res://data/fish/fish_catalog.gd")

static func species_for(map_id: String) -> Array:
 if map_id.is_empty(): return Catalog.ALL_SPECIES
 var result: Array = []
 for id in Membership.BY_MAP.get(map_id, []):
  var species: Resource = Catalog.find(StringName(id))
  if species != null: result.append(species)
 return result

## map_bests retains lifetime discovery even when the top-ten journal compacts.
static func map_records(data: Dictionary, map_id: String) -> Dictionary:
 var found := {}
 var history: Dictionary = data.get("history", {})
 var sources: Array = history.get("map_bests", {}).values()
 sources.append_array(data.get("journal", []))
 for record in sources:
  if str(record.get("map", "")) != map_id: continue
  var id := str(record.get("species", ""))
  var weight := float(record.get("weight", 0.0))
  if id.is_empty() or weight <= 0.0: continue
  if not found.has(id) or weight > float(found[id].best):
   found[id] = {"count":1,"best":weight}
 return found
