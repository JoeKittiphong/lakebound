extends Control
@export var minimum_margin: float = 32.0

func _ready() -> void:
 get_viewport().size_changed.connect(_update_safe_area)
 _update_safe_area()

func _update_safe_area() -> void:
 var margins := Vector4(minimum_margin, minimum_margin, minimum_margin, minimum_margin)
 if OS.has_feature("android") or OS.has_feature("ios"):
  var safe := DisplayServer.get_display_safe_area()
  var screen := DisplayServer.screen_get_size()
  var scale_factor := get_viewport_rect().size / Vector2(screen)
  margins.x = maxf(minimum_margin, safe.position.x * scale_factor.x)
  margins.y = maxf(minimum_margin, safe.position.y * scale_factor.y)
  margins.z = maxf(minimum_margin, (screen.x - safe.end.x) * scale_factor.x)
  margins.w = maxf(minimum_margin, (screen.y - safe.end.y) * scale_factor.y)
 offset_left = margins.x
 offset_top = margins.y
 offset_right = -margins.z
 offset_bottom = -margins.w
