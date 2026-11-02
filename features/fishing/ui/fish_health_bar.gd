@tool
extends Control
@export var minimum_bar_width: float = 150.0
@export var full_width_weight: float = 30.0
var fish_weight: float = 1.0
func _ready() -> void:
 if get_parent() is Control: get_parent().resized.connect(_refresh_width)
 _refresh_width()
func bar_width(weight: float, available: float) -> float:
 var fraction := clampf(log(1.0 + maxf(weight, 0.0)) / log(1.0 + full_width_weight), 0.0, 1.0)
 return lerpf(minf(minimum_bar_width, available), available, fraction)
func _refresh_width() -> void:
 if not get_parent() is Control: return
 var area := get_parent() as Control
 # A phone's camera cutout can make the safe area's left/right insets unequal.
 # Keep the bar on the screen centre, with equal room to both safe edges.
 var center := area.get_global_transform_with_canvas().affine_inverse() * get_viewport_rect().get_center()
 var available := maxf(0.0, 2.0 * minf(center.x, area.size.x - center.x))
 var width := bar_width(fish_weight, available)
 var shift := center.x - area.size.x * 0.5
 offset_left = shift - width * 0.5
 offset_right = shift + width * 0.5
func update_health(weight: float, current: float, maximum: float) -> void:
 fish_weight = weight
 _refresh_width()
 var ratio := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
 $Track.value = ratio
 $Title.text = "เลือดปลา • %d%%" % ceili(ratio * 100) if current > 0 else "หมดแรง • กรอเข้ามา"
