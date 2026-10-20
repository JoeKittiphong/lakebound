@tool
extends Control

@export_range(0.0, 1.25) var value: float = 0.45:
 set(new_value):
  value = new_value
  queue_redraw()
@export var border_width: float = 3.0

func _draw() -> void:
 var track := Rect2(Vector2.ONE * border_width, size - Vector2.ONE * border_width * 2.0)
 draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.06, 0.09, 0.9))
 var zones := [Color(0.5, 0.7, 0.77, 0.5), Color(0.38, 0.94, 0.73, 0.6), Color(1, 0.79, 0.3, 0.65), Color(1, 0.28, 0.27, 0.65)]
 var breaks := [0.0, 0.15, 0.72, 0.9, 1.0]
 for index in 4:
  var top: float = track.position.y + track.size.y * (1.0 - breaks[index + 1])
  draw_rect(Rect2(track.position.x, top, track.size.x, track.size.y * (breaks[index + 1] - breaks[index])), zones[index])
 var normalized := clampf(value, 0.0, 1.0)
 var color := Color(0.55, 1, 0.84) if normalized < 0.72 else (Color(1, 0.85, 0.35) if normalized < 0.9 else Color(1, 0.25, 0.2))
 var marker_y := track.end.y - track.size.y * normalized
 draw_line(Vector2(0, marker_y), Vector2(size.x, marker_y), color, 4.0, true)
