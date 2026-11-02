class_name ReelSpec
extends Resource
## Authored game envelopes, not universal manufacturer lure ratings.
# Explicit packed default preserves authored values during Godot 4.7.2 export.
@export var techniques: PackedStringArray = PackedStringArray()
@export var cast_min_g := -1.0
@export var cast_max_g := -1.0
@export var diameter_min_mm := -1.0
@export var diameter_max_mm := -1.0
@export var reference_diameter_mm := 0.25
@export var reference_capacity_m := 65.0
@export var max_drag_kgf := 3.0
@export var bfs := false
@export var fly_weight_min := 0
@export var fly_weight_max := 0

func capacity_for(diameter: float) -> float:
 if diameter <= 0.0: return 0.0
 return reference_capacity_m * pow(reference_diameter_mm / diameter, 2.0)
