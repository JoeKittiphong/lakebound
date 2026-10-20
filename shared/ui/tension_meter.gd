@tool
extends Control

@export_range(0.0, 1.25) var value: float = 0.45:
 set(new_value):
  value = new_value
  queue_redraw()
@export var border_width: float = 3.0
@export var base_length: float = 132.0
@export var maximum_length: float = 232.0
@export var small_fish_weight: float = 2.0
@export var large_fish_weight: float = 25.0
@export_range(0.15, 0.8) var yellow_start: float = 0.28
@export_range(0.4, 0.95) var red_start: float = 0.5

func set_zones(yellow: float, red: float) -> void:
 yellow_start = yellow
 red_start = red
 queue_redraw()

func configure_fish(weight: float, danger_start: float) -> void:
 var fraction := clampf(log(maxf(weight, small_fish_weight) / small_fish_weight) / log(large_fish_weight / small_fish_weight), 0.0, 1.0)
 offset_top = offset_bottom - lerpf(base_length, maximum_length, fraction)
 red_start = danger_start
 queue_redraw()

func _notification(what: int) -> void:
 if what == NOTIFICATION_RESIZED:
  queue_redraw()

func _draw() -> void:
 var track := Rect2(Vector2.ONE * border_width, size - Vector2.ONE * border_width * 2.0)
 draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.06, 0.09, 0.9))
 var zones := [Color(0.5, 0.7, 0.77, 0.5), Color(0.38, 0.94, 0.73, 0.6), Color(1, 0.79, 0.3, 0.65), Color(1, 0.28, 0.27, 0.65)]
 var breaks := [0.0, 0.15, yellow_start, red_start, 1.0]
 for index in 4:
  var top: float = track.position.y + track.size.y * (1.0 - breaks[index + 1])
  var bottom: float = top + track.size.y * (breaks[index + 1] - breaks[index])
  draw_rect(Rect2(track.position.x, top, track.size.x, bottom - top), zones[index])
 var normalized := clampf(value, 0.0, 1.0)
 var color := Color(0.55, 1, 0.84) if normalized < yellow_start else (Color(1, 0.85, 0.35) if normalized < red_start else Color(1, 0.25, 0.2))
 var marker_y := track.end.y - track.size.y * normalized
 draw_line(Vector2(0, marker_y), Vector2(size.x, marker_y), color, 4.0, true)
