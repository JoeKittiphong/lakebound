class_name MatchRules
extends RefCounted
const DURATIONS := [180,300,600,900,1200]
const MODES := ["species_total","total_weight","biggest_fish"]
const NAMES := ["น้ำหนักรวมปลาชนิดที่กำหนด","น้ำหนักรวมปลาทุกชนิด","ปลาตัวใหญ่ที่สุด · ทุกชนิด"]
const MAP_SPECIES = preload("res://data/regions/collection_species.gd")

static func species_for(map_id: String) -> Array:
 return MAP_SPECIES.BY_MAP.get(map_id,[])

static func description(room: Dictionary) -> String:
 var rule: String=str(room.get("rule","legacy_top3"))
 var text := "รวมปลา 3 ตัวที่หนักที่สุด"
 if rule=="species_total":
  var fish: Resource=FishCatalog.find(StringName(room.get("target_species","")))
  text="น้ำหนักรวม · "+(str(fish.display_name) if fish!=null else str(room.get("target_species","")))
 elif rule=="total_weight": text="น้ำหนักรวมปลาทุกชนิด"
 elif rule=="biggest_fish": text="ปลาตัวใหญ่ที่สุด · ทุกชนิด"
 return "%d นาที · %s" % [int(room.get("duration",600))/60,text]

static func counts_species(room: Dictionary, species: String) -> bool:
 return room.get("rule","")!="species_total" or room.get("target_species","")==species
