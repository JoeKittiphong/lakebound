class_name MissionHUD
extends RefCounted

# Presentation state only; the owning scene supplies its authored controls.
var button: Control
var tracker: Control
var tracker_text: Label
var toast: Label
var pending_mission_completions: Array[String] = []
var mission_toast_time := 0.0
var tracker_refreshes := 0
var _profile: AnglerProfile
var _dirty := true
var _tracker_visible := false

func bind(profile: AnglerProfile) -> void:
 if profile == _profile:
  return
 if is_instance_valid(_profile) and _profile.changed.is_connected(_invalidate):
  _profile.changed.disconnect(_invalidate)
 _profile = profile
 if is_instance_valid(_profile):
  _profile.changed.connect(_invalidate)
 _dirty = true

func _invalidate() -> void:
 _dirty = true

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
 bind(profile)
 button.visible = ready
 tracker.visible = ready and _tracker_visible
 toast.visible = ready and mission_toast_time > 0.0
 if not ready:
  return
 if _dirty:
  _refresh_tracker()
 tracker.visible = _tracker_visible
 if mission_toast_time <= 0.0 and not pending_mission_completions.is_empty():
  var count := pending_mission_completions.size()
  var first := MissionCatalog.find(pending_mission_completions[0])
  toast.text = "ภารกิจสำเร็จ · %s%s\nเปิดภารกิจเพื่อรับรางวัล" % [first.title, " และอีก %d ข้อ" % (count - 1) if count > 1 else ""]
  pending_mission_completions.clear()
  mission_toast_time = 5.0
 mission_toast_time = maxf(0.0, mission_toast_time - delta)
 toast.visible = mission_toast_time > 0.0

func _refresh_tracker() -> void:
 _dirty = false
 tracker_refreshes += 1
 _tracker_visible = false
 var state: Dictionary = _profile.data.missions
 var definition := MissionCatalog.find(state.tracked)
 if definition != null:
  var entry := MissionProgress.entry(state, definition)
  _tracker_visible = not entry.claimed
  tracker_text.text = "ภารกิจ · %s\n%s%s" % [definition.title, MissionProgress.progress_text(state, definition), " · รับรางวัลได้" if MissionProgress.completed(state, definition) else ""]
