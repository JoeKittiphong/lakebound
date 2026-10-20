class_name FishCatalog
extends RefCounted

const SPECIES: Array[Resource] = [
 preload("res://data/fish/tilapia.tres"),
 preload("res://data/fish/snakehead.tres"),
 preload("res://data/fish/catfish.tres"),
 preload("res://data/fish/golden_barb.tres"),
 preload("res://data/fish/gourami.tres"),
 preload("res://data/fish/featherback.tres"),
 preload("res://data/fish/betta.tres"),
 preload("res://data/fish/lionhead_goldfish.tres"),
 preload("res://data/fish/koi.tres"),
 preload("res://data/fish/arowana.tres"),
 preload("res://data/fish/tigerfish.tres"),
 preload("res://data/fish/hampala.tres"),
 preload("res://data/fish/giant_catfish.tres"),
 preload("res://data/fish/redtail_catfish.tres"),
 preload("res://data/fish/freshwater_eel.tres"),
 preload("res://data/fish/freshwater_stingray.tres")
]

static func find(id: StringName) -> Resource:
 for definition in SPECIES:
  if definition.id == id:
   return definition
 return null
