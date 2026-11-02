extends Node3D
## The scene contains every model before Play; only flex is driven at runtime.
@export_range(0.0, 1.0) var preview_load: float = 0.65
@export var animate_load: bool = false
var elapsed := 0.0
func _process(delta: float) -> void:
 elapsed += delta
 var load_value := (0.5 - 0.5 * cos(elapsed * 1.5)) if animate_load else preview_load
 for rod in $Rods.get_children():
  if rod is DetailedFishingRod:
   rod.set_pull_direction(Vector3.DOWN)
   rod.set_load(load_value, 0)
