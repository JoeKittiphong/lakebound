extends Node3D
## Small decorative school: authored model and path settings, no gameplay state.
@export var path_radius := Vector2(2.0, 0.8)
@export var swim_speed := 0.28
@export var phase := 0.0
var _origin: Vector3
var _time := 0.0
func _ready() -> void:
 _origin = position
 $Model.reset_phase(get_index())
 _process(0.0)
func _process(delta: float) -> void:
 _time += delta
 var angle := phase + _time * swim_speed
 position = _origin + Vector3(cos(angle)*path_radius.x, sin(angle*1.7)*0.025, sin(angle)*path_radius.y)
 # Fish models face local -Z, matching the gameplay ecosystem's heading.
 var direction := Vector2(-sin(angle)*path_radius.x, cos(angle)*path_radius.y) * swim_speed
 rotation.y = atan2(-direction.x, -direction.y)
