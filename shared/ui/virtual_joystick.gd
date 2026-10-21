class_name TouchJoystick
extends Control
signal direction_changed(direction: Vector2)
signal drag_released
@export_range(20.0, 120.0) var radius: float = 62.0
@export_range(0.0, 0.5) var deadzone: float = 0.12
@export var enabled: bool = true:
 set(value):
  enabled = value
  if not value:
   reset()
@onready var knob: Panel = $Knob
var direction := Vector2.ZERO
var touch_index: int = -1
var mouse_active := false

func _input(event: InputEvent) -> void:
 if not enabled:
  return
 # Forwarded desktop mouse events may also use DEVICE_ID_EMULATION.
 # Mobile uses real touches; desktop still accepts forwarded mouse input.
 if (OS.has_feature("mobile") or touch_index != -1) and (event is InputEventMouseButton or event is InputEventMouseMotion):
  return
 if event is InputEventScreenTouch:
  if event.pressed and touch_index == -1 and _inside(event.position):
   mouse_active = false
   touch_index = event.index
   _update_direction(event.position)
   get_viewport().set_input_as_handled()
  elif event.index == touch_index and not event.pressed:
   reset()
   if event.canceled: return
   drag_released.emit()
 elif event is InputEventScreenDrag and event.index == touch_index:
  _update_direction(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and touch_index == -1:
  if event.pressed and _inside(event.position):
   mouse_active = true
   _update_direction(event.position)
   get_viewport().set_input_as_handled()
  elif not event.pressed and mouse_active:
   reset()
   drag_released.emit()
 elif event is InputEventMouseMotion and mouse_active:
  _update_direction(event.position)
  get_viewport().set_input_as_handled()

func _inside(point: Vector2) -> bool:
 return (get_global_transform_with_canvas().affine_inverse() * point).distance_to(size * 0.5) <= size.x * 0.5

func _update_direction(point: Vector2) -> void:
 var local := get_global_transform_with_canvas().affine_inverse() * point
 var offset := (local - size * 0.5).limit_length(radius)
 var strength := offset.length() / radius
 direction = Vector2.ZERO if strength <= deadzone else offset.normalized() * ((strength - deadzone) / (1.0 - deadzone))
 knob.position = size * 0.5 + offset - knob.size * 0.5
 direction_changed.emit(direction)

func reset() -> void:
 touch_index = -1
 mouse_active = false
 direction = Vector2.ZERO
 if is_instance_valid(knob):
  knob.position = size * 0.5 - knob.size * 0.5
 direction_changed.emit(direction)

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
  reset()
