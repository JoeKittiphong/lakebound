class_name LineSpec
extends Resource
## Mechanical material is independent of the selected wound-line texture.
@export_enum("mono", "fluoro", "braid", "coated_mono", "fly") var material := "mono"
@export var diameter_mm := -1.0
@export var break_kgf := -1.0
@export var stretch_factor := 1.0
@export var sinks := false
@export var fly_weight := 0
