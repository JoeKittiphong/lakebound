class_name FishingMapDefinition
extends Resource

@export var map_id: String = "river"
@export var bounds := Rect2(-144, -168, 288, 336)
@export var texture: Texture2D

static func for_region(id: String) -> FishingMapDefinition:
 if not FishingJournal.known_map(id):
  return null
 return load("res://features/map/maps/%s.tres" % id)
