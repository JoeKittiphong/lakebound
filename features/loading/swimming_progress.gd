extends Control
## Fish nose follows the fill edge; all artwork and layout live in the scene.
@export_range(0.0, 12.0) var bob_height: float = 3.0
@export_range(0.0, 20.0) var swim_speed: float = 8.0
@export_range(0.0, 0.6) var tail_swing: float = 0.22
@onready var bar: ProgressBar = $ProgressBar
@onready var fish: Control = $Fish
@onready var tail: TextureRect = $Fish/Tail
var phase: float = 0.0

func _process(delta: float) -> void:
 phase += delta * swim_speed
 var ratio := bar.get_as_ratio()
 # Keep the fish within the control at both ends of the track.
 var fill_edge := bar.position.x + bar.size.x * ratio
 fish.position.x = clampf(fill_edge - fish.size.x * 0.94, 0.0, maxf(size.x - fish.size.x, 0.0))
 fish.position.y = sin(phase) * bob_height
 fish.rotation = cos(phase) * 0.025
 tail.rotation = sin(phase * 1.8) * tail_swing
