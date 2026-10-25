class_name MissionDefinition
extends Resource

@export var id: String = ""
@export_range(1, 100) var revision: int = 1
@export_enum("Easy", "Normal", "Hard", "Pro") var tier: int = 0
@export var title: String = "ภารกิจ"
@export_multiline var description: String = ""
@export_enum("count", "weight", "species", "baits") var metric: String = "count"
@export var target: float = 1.0
@export var map_id: String = "river"
@export var species_id: String = ""
@export var bait_id: String = ""
@export_enum("any", "bait", "lure") var bait_kind: String = "any"
@export var minimum_weight: float = 0.0
@export var depth_range: Vector2 = Vector2(0, 100)
@export var boss_only: bool = false
@export_range(1, 10000) var reward_coins: int = 20

func matches(record: Dictionary) -> bool:
 return record.get("map", "") == map_id and (species_id.is_empty() or record.get("species") == species_id) \
  and (bait_id.is_empty() or record.get("bait_id") == bait_id) \
  and (bait_kind == "any" or record.get("bait_kind") == bait_kind) \
  and float(record.get("weight", 0)) >= minimum_weight \
  and float(record.get("depth", -1)) >= depth_range.x and float(record.get("depth", -1)) <= depth_range.y \
  and (not boss_only or record.get("boss", false))
