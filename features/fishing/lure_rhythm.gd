extends RefCounted
## Direction sequence only: elapsed time never fails an action.
const SYMBOLS = {"left":"←", "right":"→", "up":"↑", "down":"↓"}
const RECIPES = {
 "walk_the_dog":["left","right","left","right"],
 "stop_and_go":["down","up","down"],
 "twitch_pause":["up","left","up","right","up"],
 "jerk_fall":["up","down","up"], "steady":["down","down","down"],
 "frog":["left","right","left"],
 "floating_lure":["left","right","left","right"],
 "pencil":["left","right","left","right","left","right"],
 "popper":["up","down","up","left","right"],
 "metal_jig":["up","down","up","down","up","down","up"],
 "rubber_worm":["up","down","up","down"],
 "shad":["down","up","down","left"],
 "crankbait":["down","left","down","right","down","up"]}
var pattern := ""
var steps: Array = []
var step := 0
var last_direction := "pause"
var feedback := "โยกตามลูกศร • ไม่ต้องจับเวลา"
var hit := false
var preparing := false
var completed_steps := 0

func reset(recipe: String = "") -> void:
 pattern = recipe
 steps = RECIPES.get(recipe, RECIPES.stop_and_go).duplicate()
 step = 0
 completed_steps = 0
 last_direction = "pause"
 hit = false
 feedback = "โยกตามลูกศร • ไม่ต้องจับเวลา"

func retry_without_fish() -> void:
 # Preserve the held direction: a fresh edge is required for the next formula.
 step = 0
 completed_steps = 0
 hit = false
 feedback = "ยังไม่มีปลาที่สนใจ • โยกสูตรใหม่"

func _direction(stick: Vector2) -> String:
 if stick.length() < 0.26:
  return "pause"
 if stick.length() < 0.48:
  return last_direction
 if absf(stick.x) > absf(stick.y):
  return "left" if stick.x < 0.0 else "right"
 return "up" if stick.y < 0.0 else "down"

func advance(_delta: float, stick: Vector2, recipe: String, item_id: String = "") -> Dictionary:
 var key := item_id if RECIPES.has(item_id) else recipe
 if key != pattern or steps.is_empty():
  reset(key)
 var result := {"success":false,"mistake":false,"quality":0.0,"accepted":false}
 var direction := _direction(stick)
 var edge: bool = direction != "pause" and direction != last_direction
 last_direction = direction
 if not edge or step >= steps.size():
  return result
 if direction != steps[step]:
  step = 0
  completed_steps = 0
  hit = false
  feedback = "ผิดทิศ • เริ่มสูตรและหลอดใหม่"
  result.mistake = true
  return result
 step += 1
 completed_steps = step
 hit = true
 result.accepted = true
 result.quality = progress()
 result.success = step == steps.size()
 feedback = "เต็มหลอด ✓ • รอปลาเข้าถึงเหยื่อ" if result.success else "ถูกทิศ ✓ • ทำตามลูกศรถัดไป"
 return result

func cue_text() -> String:
 if step >= steps.size():
  return "เต็มหลอด • พร้อมเข้ากัด"
 return SYMBOLS[steps[step]] + "  โยกตามลูกศร"

func sequence_text() -> String:
 var parts := PackedStringArray()
 for index in steps.size():
  parts.append("✓" if index < step else ("[%s]" % SYMBOLS[steps[index]] if index == step else SYMBOLS[steps[index]]))
 return "   ".join(parts)

func progress() -> float:
 return float(step) / maxf(1, steps.size())

func active_window() -> bool:
 return true
