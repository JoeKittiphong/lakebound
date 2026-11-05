extends Resource
## Each future boat can provide its own authored hull, anchors and walkable deck.
@export_file("*.tscn") var scene_path := "res://actors/boat/fishing_boat.tscn"
@export var speed := 8.0
@export var acceleration := 3.5
@export var turn_speed := 1.25
@export var minimum_depth := 0.6
@export var deck_bounds := Rect2(-0.85, -1.85, 1.7, 3.25)
@export var deck_walk_speed := 1.8
@export var placement_distance := 22.0
