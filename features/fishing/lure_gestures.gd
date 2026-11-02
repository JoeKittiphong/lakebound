extends RefCounted
## Turns analog input into edges; holding a direction never repeats a twitch.
var threshold := 0.48
var minimum_interval := 0.18
var maximum_interval := 0.85
var pause_duration := 0.28
var clock := 0.0
var last_edge_time := -10.0
var direction := 0
var walk_steps := 0
var previous_side := 0
var retrieve_duration := 0.0
var neutral_duration := 0.0
var stop_cycles := 0
var pending_stop := false
var success_time := -10.0
var success_name := ""
var rhythm_steps := 0
var rhythm_pending := false
var steady_duration := 0.0

func reset() -> void:
 clock = 0.0
 last_edge_time = -10.0
 direction = 0
 walk_steps = 0
 previous_side = 0
 retrieve_duration = 0.0
 neutral_duration = 0.0
 stop_cycles = 0
 pending_stop = false
 success_time = -10.0
 success_name = ""
 rhythm_steps = 0
 rhythm_pending = false
 steady_duration = 0.0

func advance(delta: float, stick: Vector2, pattern: String) -> Dictionary:
 clock += delta
 var result := {"jerk": false, "side": 0, "pattern": ""}
 if clock - last_edge_time > maximum_interval:
  walk_steps = 0
  previous_side = 0
 var next := direction
 if stick.length() < threshold * 0.55:
  next = 0
 elif stick.length() >= threshold:
  next = (-1 if stick.x < 0 else 1) if absf(stick.x) > absf(stick.y) else (-2 if stick.y < 0 else 2)
 if next != direction:
  direction = next
  if direction == 2:
   walk_steps = 0
   previous_side = 0
  if abs(direction) == 1 or direction == -2:
   var interval := clock - last_edge_time
   if pattern in ["twitch_pause", "jerk_fall"]:
    var valid_edge: bool = direction == -2 or (pattern == "twitch_pause" and abs(direction) == 1)
    if valid_edge:
     rhythm_steps = rhythm_steps + 1 if interval >= minimum_interval and interval <= maximum_interval else 1
     rhythm_pending = rhythm_steps >= 2
    else:
     rhythm_steps = 0
     rhythm_pending = false
   result.jerk = direction == -2
   result.side = direction if abs(direction) == 1 else 0
   if abs(direction) == 1:
    var alternating := previous_side == -direction and interval >= minimum_interval and interval <= maximum_interval
    walk_steps = walk_steps + 1 if alternating else 1
    previous_side = direction
    if walk_steps >= 4 and pattern == "walk_the_dog":
     result.pattern = "Walk the Dog"
     walk_steps = 0
     previous_side = 0
   else:
    walk_steps = 0
    previous_side = 0
   last_edge_time = clock
 if stick.y >= threshold:
  rhythm_steps = 0
  rhythm_pending = false
  steady_duration += delta
  if pattern == "steady" and steady_duration >= 1.6:
   result.pattern = "Steady Retrieve"
   steady_duration = 0.0
  retrieve_duration += delta
  neutral_duration = 0.0
  pending_stop = retrieve_duration >= 0.35
 elif stick.length() < threshold * 0.55:
  steady_duration = 0.0
  neutral_duration += delta
  if rhythm_pending and neutral_duration >= (0.45 if pattern == "jerk_fall" else pause_duration):
   result.pattern = "Jerk & Fall" if pattern == "jerk_fall" else "Twitch & Pause"
   rhythm_pending = false
   rhythm_steps = 0
  if not pending_stop:
   retrieve_duration = 0.0
  if pending_stop and neutral_duration >= pause_duration:
   stop_cycles += 1
   pending_stop = false
   retrieve_duration = 0.0
   if stop_cycles >= 2 and pattern == "stop_and_go":
    result.pattern = "Stop & Go"
    stop_cycles = 0
  if neutral_duration > 1.5:
   stop_cycles = 0
   retrieve_duration = 0.0
   pending_stop = false
 else:
  steady_duration = 0.0
  retrieve_duration = 0.0
  neutral_duration = 0.0
  pending_stop = false
  stop_cycles = 0
 if not result.pattern.is_empty():
  success_name = result.pattern
  success_time = clock
 return result

func hint(pattern: String) -> String:
 if clock - success_time < 1.4:
  return success_name + " ✓"
 if pattern == "walk_the_dog":
  return "← → ← →  %d/4" % walk_steps
 if pattern == "twitch_pause":
  return "↑ • ←/→ • หยุด  %d/2" % rhythm_steps
 if pattern == "jerk_fall":
  return "↑ • ↑ • ปล่อยจม  %d/2" % rhythm_steps
 if pattern == "steady":
  return "↓ กรอสม่ำเสมอ  %.1f/1.6 วิ" % steady_duration
 return "↓ กรอ • หยุด • ↓ กรอ • หยุด  %d/2" % stop_cycles
