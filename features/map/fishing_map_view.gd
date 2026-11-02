class_name FishingMapView
extends Control
## Specialized map rendering; layout, labels and interaction controls live in scenes.
signal selected(value: Dictionary)
@export var map_data: FishingMapDefinition
@export var interactive := true
@export var player_color := Color(0.65, 0.96, 0.88)
@export var history_color := Color(0.93, 0.79, 0.47)
@export var stand_color := Color(0.87, 0.94, 0.97)
var player_position := Vector2.ZERO
var player_yaw := 0.0
var show_player := true
var records: Array = []
var favorites: Array = []
var selection: Dictionary = {}
var target: Dictionary = {}
var boss: Dictionary = {}
var zoom := 1.0
var pan := Vector2.ZERO
var _clusters: Array = []
var _pressed := false
var _finger := -1
var _press_at := Vector2.ZERO
var _moved := false

func _ready() -> void:
 resized.connect(_rebuild)
 _rebuild()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
  _pressed = false
  _finger = -1

func configure(value: FishingMapDefinition) -> void:
 map_data = value
 zoom = 1.0
 pan = Vector2.ZERO
 selection = {}
 _rebuild()

func set_history(value: Array, spots: Array) -> void:
 records = value
 favorites = spots
 _rebuild()

func map_rect() -> Rect2:
 if map_data == null:
  return Rect2()
 var scale_value := minf(size.x / map_data.bounds.size.x, size.y / map_data.bounds.size.y) * zoom
 var extent := map_data.bounds.size * scale_value
 return Rect2((size - extent) * 0.5 + pan, extent)

func project(point: Vector2) -> Vector2:
 var rect := map_rect()
 return rect.position + (point - map_data.bounds.position) / map_data.bounds.size * rect.size

func unproject(point: Vector2) -> Vector2:
 var rect := map_rect()
 return map_data.bounds.position + (point - rect.position) / rect.size * map_data.bounds.size

func set_zoom(value: float) -> void:
 zoom = clampf(value, 1.0, 4.0)
 _clamp_pan()
 _rebuild()

func reset_view() -> void:
 zoom = 1.0
 pan = Vector2.ZERO
 _rebuild()

func _clamp_pan() -> void:
 var rect := map_rect()
 var limit := (rect.size - size).max(Vector2.ZERO) * 0.5
 pan = pan.clamp(-limit, limit)

func _rebuild() -> void:
 _clusters.clear()
 if map_data == null or size.x <= 0 or size.y <= 0:
  queue_redraw()
  return
 # The authored TextureRect also gives the stopped editor a terrain preview.
 var terrain := get_node_or_null("Terrain") as TextureRect
 if terrain != null:
  terrain.texture = map_data.texture
  terrain.set_anchors_preset(Control.PRESET_TOP_LEFT)
  terrain.position = map_rect().position
  terrain.size = map_rect().size
 var cells := {}
 for record in records:
  if not FishingJournal.valid_location(record.get("location")):
   continue
  var point := project(record.location.bite_xz)
  if not Rect2(Vector2.ZERO, size).grow(18).has_point(point):
   continue
  var cell := Vector2i(floori(point.x / 32), floori(point.y / 32))
  if cells.has(cell):
   cells[cell].count += 1
  else:
   cells[cell] = {"point": point, "record": record, "count": 1}
 _clusters = cells.values()
 queue_redraw()

func _draw() -> void:
 if map_data == null or map_data.texture == null:
  return
 if not has_node("Terrain"):
  draw_texture_rect(map_data.texture, map_rect(), false)
 for cluster in _clusters:
  draw_circle(cluster.point, 6.0 if cluster.count == 1 else 10.0, history_color)
  if cluster.count > 1 and interactive:
   draw_string(ThemeDB.fallback_font, cluster.point + Vector2(12, 5), str(cluster.count), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, stand_color)
 for spot in favorites:
  var point := project(spot.position)
  draw_colored_polygon(PackedVector2Array([point + Vector2(0,-7),point + Vector2(7,0),point + Vector2(0,7),point + Vector2(-7,0)]), history_color)
 if selection.get("kind") == "catch":
  var location: Dictionary = selection.record.get("location", {})
  if FishingJournal.valid_location(location):
   var stand := project(location.angler_xz)
   var bite := project(location.bite_xz)
   draw_line(stand, bite, stand_color, 2, true)
   draw_circle(stand, 8, stand_color, false, 2, true)
   draw_circle(bite, 12, history_color, false, 2, true)
 elif selection.get("kind") == "point":
  draw_circle(project(selection.point), 10, history_color, false, 2, true)
 if not target.is_empty():
  var point := project(target.position)
  draw_circle(point, 12, player_color, false, 2, true)
  draw_line(point - Vector2(0,16), point + Vector2(0,16), player_color, 1, true)
  draw_line(point - Vector2(16,0), point + Vector2(16,0), player_color, 1, true)
 if show_player:
  var point := project(player_position)
  var direction := Vector2(sin(-player_yaw), -cos(player_yaw))
  var side := direction.orthogonal()
  draw_circle(point, 11, Color(0.03,0.09,0.12,0.9))
  draw_colored_polygon(PackedVector2Array([point+direction*10,point-direction*6+side*6,point-direction*3,point-direction*6-side*6]), player_color)
 if not boss.is_empty():
  var point := project(boss.position)
  draw_circle(point, 18, Color(0.025, 0.07, 0.06, 0.95))
  draw_circle(point, 18, Color(0.95, 0.79, 0.4), false, 2, true)
  var crown := PackedVector2Array()
  for offset in [Vector2(-10,-6), Vector2(-5,-1), Vector2(0,-11), Vector2(5,-1), Vector2(10,-6), Vector2(8,7), Vector2(-8,7)]:
   crown.append(point + offset)
  draw_colored_polygon(crown, Color(0.98, 0.82, 0.43))

func _pick(point: Vector2) -> void:
 if not boss.is_empty() and point.distance_to(project(boss.position)) <= 24.0:
  selection = {"kind": "boss"}
  selected.emit(selection)
  queue_redraw()
  return
 var nearest: Dictionary = {}
 var distance := 24.0
 for spot in favorites:
  var candidate := point.distance_to(project(spot.position))
  if candidate < distance:
   distance = candidate
   nearest = {"kind": "spot", "spot": spot}
 for cluster in _clusters:
  var candidate := point.distance_to(cluster.point)
  if candidate < distance:
   distance = candidate
   nearest = {"kind": "catch", "record": cluster.record}
 if nearest.is_empty():
  if not map_rect().has_point(point):
   return
  nearest = {"kind": "point", "point": unproject(point)}
 selection = nearest
 selected.emit(nearest)
 queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if not interactive or map_data == null:
  return
 if event is InputEventMouseButton and event.device != -1:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
   set_zoom(zoom + 0.5)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
   set_zoom(zoom - 0.5)
  elif event.button_index == MOUSE_BUTTON_LEFT:
   _press(event.position, event.pressed)
 elif event is InputEventMouseMotion and _pressed and _finger == -1:
  _drag(event.position, event.relative)
 elif event is InputEventScreenTouch:
  if event.pressed and _finger == -1:
   _finger = event.index
   _press(event.position, true)
  elif event.index == _finger and not event.pressed:
   if event.canceled:
    _moved = true
   _press(event.position, false)
   _finger = -1
 elif event is InputEventScreenDrag and event.index == _finger:
  _drag(event.position, event.relative)
 accept_event()

func _press(point: Vector2, down: bool) -> void:
 if down:
  _pressed = true
  _press_at = point
  _moved = false
 elif _pressed:
  _pressed = false
  if not _moved:
   _pick(point)

func _drag(point: Vector2, relative: Vector2) -> void:
 if point.distance_to(_press_at) > 8:
  _moved = true
 if _moved:
  pan += relative
  _clamp_pan()
  _rebuild()
