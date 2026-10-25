extends Button

signal orbit_started
signal orbit_ended
signal orbit_dragged(horizontal_motion: float)
var finger := -1
var dragging_mouse := false
var suppress_mouse_until := 0

func _input(event: InputEvent) -> void:
 if disabled or not is_visible_in_tree():
  cancel_drag()
  return
 if event is InputEventScreenTouch:
  if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
   suppress_mouse_until = Time.get_ticks_msec() + 250
   finger = event.index
   orbit_started.emit()
   get_viewport().set_input_as_handled()
  elif not event.pressed and event.index == finger:
   suppress_mouse_until = Time.get_ticks_msec() + 250
   cancel_drag()
   get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index == finger:
  orbit_dragged.emit(event.relative.x)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  if OS.has_feature("mobile") or finger != -1 or (Time.get_ticks_msec() < suppress_mouse_until and event.device == InputEvent.DEVICE_ID_EMULATION):
   return
  if event.pressed and get_global_rect().has_point(event.position):
   dragging_mouse = true
   orbit_started.emit()
   get_viewport().set_input_as_handled()
  elif not event.pressed and dragging_mouse:
   cancel_drag()
   get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and dragging_mouse:
  orbit_dragged.emit(event.relative.x)
  get_viewport().set_input_as_handled()

func cancel_drag() -> void:
 var held := finger != -1 or dragging_mouse
 finger = -1
 dragging_mouse = false
 if held:
  orbit_ended.emit()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
  cancel_drag()
