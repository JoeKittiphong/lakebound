extends ScrollContainer
## A whole-card touch surface. A swipe over a button scrolls without clicking it.
@export var drag_threshold := 10.0
@export var friction := 1800.0
var _finger := -1
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _dragging := false
var _speed := 0.0
var _position := 0.0
var _button: BaseButton

func stop_scrolling() -> void:
 _speed = 0.0
 _finger = -1
 _button = null

func _input(event: InputEvent) -> void:
 if not is_visible_in_tree():
  _finger = -1
  _speed = 0.0
  return
 if event is InputEventScreenTouch:
  if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
   _finger = event.index
   _start = event.position
   _last = event.position
   _position = scroll_vertical
   _speed = 0.0
   _dragging = false
   _button = _button_at(self, event.position)
  elif not event.pressed and event.index == _finger:
   if not event.canceled and not _dragging and is_instance_valid(_button) and not _button.disabled and _button.get_global_rect().has_point(event.position):
    _button.pressed.emit()
   _finger = -1
   _button = null
  else:
   return
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index == _finger:
  if not _dragging and event.position.distance_to(_start) >= drag_threshold:
   _dragging = true
  if _dragging:
   _scroll(_last.y - event.position.y)
   _speed = -event.velocity.y
  _last = event.position
  get_viewport().set_input_as_handled()
 elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION and get_global_rect().has_point(event.position):
  get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
 if _finger == -1 and absf(_speed) > 1.0 and is_visible_in_tree():
  _scroll(_speed * delta)
  _speed = move_toward(_speed, 0.0, friction * delta)

func _scroll(amount: float) -> void:
 var bar := get_v_scroll_bar()
 _position = clampf(_position + amount, 0.0, maxf(0.0, bar.max_value - bar.page))
 scroll_vertical = roundi(_position)

func _button_at(node: Node, point: Vector2) -> BaseButton:
 for child in node.get_children():
  if child is Control and child.is_visible_in_tree() and child.get_global_rect().has_point(point):
   if child is BaseButton:
    return child
   var found := _button_at(child, point)
   if found != null:
    return found
 return null
