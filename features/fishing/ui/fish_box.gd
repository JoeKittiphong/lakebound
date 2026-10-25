class_name FishBoxView
extends PanelContainer

var _profile: AnglerProfile
var _dirty := true
@onready var _count: Label = $Row/Info/Count
@onready var _weight: Label = $Row/Info/Weight
@onready var _fill: ProgressBar = $Row/Info/Fill
@onready var _status: Label = $Row/Info/State

func bind(profile: AnglerProfile) -> void:
 if profile == _profile:
  return
 _disconnect_profile()
 _profile = profile
 if is_instance_valid(_profile):
  _profile.changed.connect(_invalidate)
 _dirty = true

func _disconnect_profile() -> void:
 if is_instance_valid(_profile) and _profile.changed.is_connected(_invalidate):
  _profile.changed.disconnect(_invalidate)

func _exit_tree() -> void:
 _disconnect_profile()

func _invalidate() -> void:
 _dirty = true

func refresh_if_needed() -> void:
 if not _dirty or not is_instance_valid(_profile):
  return
 _dirty = false
 var weight := _profile.box_weight()
 var capacity: float = _profile.equipped("box").capacity
 var remaining := maxf(0.0, capacity - weight)
 var fraction := clampf(weight / maxf(capacity, 0.01), 0.0, 1.0)
 _count.text = "กล่องปลา · %d ตัว" % _profile.data.catches.size()
 _weight.text = "%.1f / %.1f กก." % [weight, capacity]
 _fill.value = fraction * 100.0
 var status_text := "เต็มแล้ว" if remaining < 0.001 else "ใกล้เต็ม" if fraction >= 0.8 else "ยังว่าง" if weight == 0.0 else "มีที่ว่าง"
 _status.text = "%s · เหลือ %.1f กก." % [status_text, remaining]
 var color := Color(1, 0.4, 0.35) if remaining < 0.001 else Color(1, 0.82, 0.35) if fraction >= 0.8 else Color(0.65, 1, 0.84)
 _status.modulate = color
 _fill.modulate = color
