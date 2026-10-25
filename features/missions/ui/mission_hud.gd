class_name MissionHUD
extends RefCounted

# Presentation state only; the owning scene supplies its authored controls.
var button: Control
var tracker: Control
var tracker_text: Label
var toast: Label
var pending_mission_completions: Array[String] = []
var mission_toast_time := 0.0

func _init(action: Control, progress: Control, message: Label) -> void:
 button = action
 tracker = progress
 tracker_text = progress.get_node("Text")
 toast = message

func notify_completed(ids: Array[String]) -> void:
 for id in ids:
  if id not in pending_mission_completions:
   pending_mission_completions.append(id)

func refresh(profile: AnglerProfile, ready: bool, delta: float) -> void:
 button.visible = ready
 tracker.hide()
 toast.visible = ready and mission_toast_time > 0.0
 if not ready:
  return
 var state: Dictionary = profile.data.missions
 var definition := MissionCatalog.find(state.tracked)
 if definition != null:
  var entry := MissionProgress.entry(state, definition)
  tracker.visible = not entry.claimed
  tracker_text.text = "ภารกิจ · %s\n%s%s" % [definition.title, MissionProgress.progress_text(state, definition), " · รับรางวัลได้" if MissionProgress.completed(state, definition) else ""]
 if mission_toast_time <= 0.0 and not pending_mission_completions.is_empty():
  var count := pending_mission_completions.size()
  var first := MissionCatalog.find(pending_mission_completions[0])
  toast.text = "ภารกิจสำเร็จ · %s%s\nเปิดภารกิจเพื่อรับรางวัล" % [first.title, " และอีก %d ข้อ" % (count - 1) if count > 1 else ""]
  pending_mission_completions.clear()
  mission_toast_time = 5.0
 mission_toast_time = maxf(0.0, mission_toast_time - delta)
 toast.visible = mission_toast_time > 0.0
