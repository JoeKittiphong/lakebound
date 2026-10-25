class_name MissionCatalog
extends RefCounted

const TIERS := ["Easy · เริ่มต้น", "Normal · เรียนรู้", "Hard · ท้าทาย", "Pro · ชำนาญ"]
const ITEMS: Array[MissionDefinition] = [
 preload("res://data/missions/first_three.tres"),
 preload("res://data/missions/tilapia_pair.tres"),
 preload("res://data/missions/two_species.tres"),
 preload("res://data/missions/five_kilos.tres"),
 preload("res://data/missions/natural_pair.tres"),
 preload("res://data/missions/first_lure.tres"),
 preload("res://data/missions/large_tilapia.tres"),
 preload("res://data/missions/lure_hunter.tres"),
 preload("res://data/missions/deep_catch.tres"),
 preload("res://data/missions/pond_champion.tres"),
 preload("res://data/missions/large_snakehead.tres"),
 preload("res://data/missions/six_species.tres")]

const REGION_ITEMS: Array[MissionDefinition] = [
 preload("res://data/missions/lotus_marsh_arrival.tres"),
 preload("res://data/missions/lotus_marsh_diversity.tres"),
 preload("res://data/missions/lotus_marsh_resident.tres"),
 preload("res://data/missions/lotus_marsh_weight.tres"),
 preload("res://data/missions/lotus_marsh_depth.tres"),
 preload("res://data/missions/lotus_marsh_champion.tres"),
 preload("res://data/missions/forest_stream_arrival.tres"),
 preload("res://data/missions/forest_stream_diversity.tres"),
 preload("res://data/missions/forest_stream_resident.tres"),
 preload("res://data/missions/forest_stream_weight.tres"),
 preload("res://data/missions/forest_stream_depth.tres"),
 preload("res://data/missions/forest_stream_champion.tres"),
 preload("res://data/missions/wild_reservoir_arrival.tres"),
 preload("res://data/missions/wild_reservoir_diversity.tres"),
 preload("res://data/missions/wild_reservoir_resident.tres"),
 preload("res://data/missions/wild_reservoir_weight.tres"),
 preload("res://data/missions/wild_reservoir_depth.tres"),
 preload("res://data/missions/wild_reservoir_champion.tres"),
 preload("res://data/missions/mangrove_estuary_arrival.tres"),
 preload("res://data/missions/mangrove_estuary_diversity.tres"),
 preload("res://data/missions/mangrove_estuary_resident.tres"),
 preload("res://data/missions/mangrove_estuary_weight.tres"),
 preload("res://data/missions/mangrove_estuary_depth.tres"),
 preload("res://data/missions/mangrove_estuary_champion.tres"),
 preload("res://data/missions/coral_coast_arrival.tres"),
 preload("res://data/missions/coral_coast_diversity.tres"),
 preload("res://data/missions/coral_coast_resident.tres"),
 preload("res://data/missions/coral_coast_weight.tres"),
 preload("res://data/missions/coral_coast_depth.tres"),
 preload("res://data/missions/coral_coast_champion.tres"),
]
const ALL_ITEMS: Array[MissionDefinition] = ITEMS + REGION_ITEMS

# IDs are stable authored catalog keys; retain the original Resource instances.
static var _by_id: Dictionary = {}

static func find(id: String) -> MissionDefinition:
 if _by_id.is_empty():
  for entry in ALL_ITEMS:
   _by_id[String(entry.id)] = entry
 return _by_id.get(id)
