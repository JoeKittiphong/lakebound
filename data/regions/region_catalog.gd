class_name RegionCatalog
extends RefCounted
const MAPS = [
 {"id": "river", "name": "แม่น้ำสายใหญ่", "subtitle": "วังน้ำลึก · ตลิ่งหิน · ปลายักษ์", "scene": "res://features/regions/grand_river.tscn", "fish_count": 28, "mission_count": 12},
 {"id": "lotus_marsh", "name": "บึงบัวริมทุ่ง", "subtitle": "น้ำนิ่งตื้น · กอบัว · ฝึกตกปลา", "scene": "res://features/regions/lotus_marsh.tscn", "fish_count": 14, "mission_count": 6},
 {"id": "forest_stream", "name": "ลำธารป่าภูเขา", "subtitle": "แก่งหิน · ป่าลึก · ปลาพื้นถิ่น", "scene": "res://features/regions/forest_stream.tscn", "fish_count": 28, "mission_count": 6},
 {"id": "wild_reservoir", "name": "เขื่อนดงตอไม้", "subtitle": "อ่างน้ำลึก · ซากไม้จม · ชะโดยักษ์", "scene": "res://features/regions/wild_reservoir.tscn", "fish_count": 14, "mission_count": 6},
 {"id": "mangrove_estuary", "name": "ปากอ่าวป่าชายเลน", "subtitle": "น้ำกร่อย · รากโกงกาง · ชายเลน", "scene": "res://features/regions/mangrove_estuary.tscn", "fish_count": 14, "mission_count": 6},
 {"id": "coral_coast", "name": "ทะเลแนวปะการัง", "subtitle": "หาดทราย · แนวหิน · ทูน่าและกระโทง", "scene": "res://features/regions/coral_coast.tscn", "fish_count": 15, "mission_count": 6},
]
static func find(id: String) -> Dictionary:
 for entry in MAPS:
  if entry.id == id:return entry
 return MAPS[0]
