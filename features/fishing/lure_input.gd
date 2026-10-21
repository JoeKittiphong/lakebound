class_name LureInput
extends RefCounted

signal action(name: StringName)
var double_window := 0.22
var hold_threshold := 0.35
var pressed := false
var holding := false
var duration := 0.0
var tap_pending := false
var tap_elapsed := 0.0

func press() -> void:
 if pressed:
  return
 pressed = true
 duration = 0.0
 holding = false

func release() -> void:
 if not pressed:
  return
 pressed = false
 if holding:
  action.emit(&"release")
  holding = false
 elif tap_pending and tap_elapsed <= double_window:
  tap_pending = false
  action.emit(&"double_tap")
 else:
  tap_pending = true
  tap_elapsed = 0.0

func advance(delta: float) -> void:
 if pressed:
  duration += delta
  if duration >= hold_threshold and not holding:
   if tap_pending:
    tap_pending = false
    action.emit(&"tap")
   holding = true
   action.emit(&"hold")
 if tap_pending:
  tap_elapsed += delta
  if tap_elapsed > double_window:
   tap_pending = false
   action.emit(&"tap")

func reset() -> void:
 pressed = false
 holding = false
 duration = 0.0
 tap_pending = false
 tap_elapsed = 0.0
