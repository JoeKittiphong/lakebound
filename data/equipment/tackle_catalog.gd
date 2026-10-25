class_name TackleCatalog
extends RefCounted

const ITEMS: Array[Resource] = [
 preload("res://data/equipment/worm.tres"), preload("res://data/equipment/dough.tres"),
 preload("res://data/equipment/minnow.tres"), preload("res://data/equipment/frog.tres"), preload("res://data/equipment/soft_plastic.tres"),
 preload("res://data/equipment/light_rod.tres"), preload("res://data/equipment/heavy_rod.tres"),
 preload("res://data/equipment/basic_reel.tres"), preload("res://data/equipment/fast_reel.tres"),
 preload("res://data/equipment/nylon.tres"), preload("res://data/equipment/fine_line.tres"), preload("res://data/equipment/braid.tres"),
 preload("res://data/equipment/small_box.tres"), preload("res://data/equipment/large_box.tres")]

# IDs are stable authored catalog keys; retain the original Resource instances.
static var _by_id: Dictionary = {}

static func item(id: String) -> Resource:
 if _by_id.is_empty():
  for entry in ITEMS:
   _by_id[String(entry.id)] = entry
 return _by_id.get(id)
