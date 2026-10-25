extends Button

## Own a distinct finger, so jump/run still work while another finger walks.
var touch_index := -1
var _suppress_mouse_until := 0

func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() < _suppress_mouse_until:
  get_viewport().set_input_as_handled()
  return
 if not is_visible_in_tree():
  touch_index = -1
  return
 if event is InputEventScreenTouch:
  if event.pressed and not disabled and touch_index == -1 and get_global_rect().has_point(event.position):
   touch_index = event.index
   _suppress_mouse_until = Time.get_ticks_msec() + 350
   button_down.emit()
   get_viewport().set_input_as_handled()
  elif not event.pressed and event.index == touch_index:
   touch_index = -1
   _suppress_mouse_until = Time.get_ticks_msec() + 350
   button_up.emit()
   if not event.canceled and not disabled and get_global_rect().has_point(event.position):
    if toggle_mode:
     button_pressed = not button_pressed
    pressed.emit()
   get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index == touch_index:
  get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
  touch_index = -1
