class_name AnglerCameraRig
extends Node3D

signal view_changed(yaw: float)
@export var look_sensitivity: float = 0.003
@export_range(-15.0, 0.0) var min_pitch: float = -10.0
@export_range(0.0, 20.0) var max_pitch: float = 15.0
@export var follow_speed: float = 5.0
var orbiting := false
var _return_rotation := Vector3.ZERO
var _return_camera_position := Vector3.ZERO
var look_finger := -1
var look_mouse := false
var touch_controls: Array[TouchJoystick] = []
@export var target: Node3D
var enabled := true:
 set(value):
  enabled = value
  if not enabled:
   reset_input()

func _process(delta: float) -> void:
 if orbiting and enabled:
  $Camera3D.position = $Camera3D.position.lerp(_return_camera_position * 0.65, 1.0 - exp(-6.0 * delta))
 rotation.x = clampf(rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
 if is_instance_valid(target):
  global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))

func reset_input() -> void:
 set_orbiting(false)
 look_finger = -1
 look_mouse = false

func set_orbiting(held: bool) -> void:
 if held == orbiting or (held and not enabled):
  return
 if held:
  _return_rotation = rotation
  _return_camera_position = $Camera3D.position
  look_finger = -1
  look_mouse = false
  orbiting = true
 else:
  rotation = _return_rotation
  $Camera3D.position = _return_camera_position
  orbiting = false
  view_changed.emit(rotation.y)

func bind_touch_controls(movement: TouchJoystick, rod: TouchJoystick) -> void:
 touch_controls = [movement, rod]

func drag_orbit(horizontal_motion: float) -> void:
 if orbiting and enabled:
  rotation.y = wrapf(rotation.y - horizontal_motion * look_sensitivity, -PI, PI)

func _is_touch_mouse_duplicate(event: InputEvent) -> bool:
 if not (event is InputEventMouseButton or event is InputEventMouseMotion):
  return false
 if OS.has_feature("mobile"):
  return true
 if event.device != InputEvent.DEVICE_ID_EMULATION:
  return false
 if look_finger != -1:
  return true
 for control in touch_controls:
  if is_instance_valid(control) and control.touch_index != -1:
   return true
 return false

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
  reset_input()

func _input(event: InputEvent) -> void:
 if _is_touch_mouse_duplicate(event):
  return
 if not enabled:
  look_finger = -1
  look_mouse = false
  return
 if event is InputEventScreenTouch and not event.pressed and event.index == look_finger:
  look_finger = -1
 elif event is InputEventScreenDrag and event.index == look_finger:
  rotate_view(event.relative)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  look_mouse = false
 elif event is InputEventMouseMotion and look_mouse:
  rotate_view(event.relative)
  get_viewport().set_input_as_handled()

func rotate_view(motion: Vector2) -> void:
 if orbiting:
  return
 rotation.y = wrapf(rotation.y - motion.x * look_sensitivity, -PI, PI)
 rotation.x = clampf(rotation.x - motion.y * look_sensitivity, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
 view_changed.emit(rotation.y)

func _unhandled_input(event: InputEvent) -> void:
 if _is_touch_mouse_duplicate(event):
  return
 # Some forwarded/emulated input reaches unhandled input after the control
 # consumed its original event. A finger starting on either pad belongs there.
 if event is InputEventScreenTouch and event.pressed:
  for control in touch_controls:
   if is_instance_valid(control) and control.enabled and control.get_global_rect().has_point(event.position):
    return
 # Only a press that escaped HUD controls can claim the camera.
 if enabled:
  if event is InputEventScreenTouch and event.pressed and look_finger == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.5:
   look_mouse = false
   look_finger = event.index
   get_viewport().set_input_as_handled()
  elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and look_finger == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.5:
   look_mouse = true
   get_viewport().set_input_as_handled()
