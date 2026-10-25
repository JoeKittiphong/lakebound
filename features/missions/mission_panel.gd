extends Control

signal opened
signal closed
const Row = preload("res://features/missions/mission_row.tscn")
var profile: AnglerProfile
var selected_tier := 0
var map_id := "river"
var definitions: Array[MissionDefinition] = []
var rows: Array[Control] = []

func _exit_tree() -> void:
 if is_instance_valid(profile) and profile.changed.is_connected(refresh):
  profile.changed.disconnect(refresh)

func bind(value: AnglerProfile) -> void:
 profile = value
 profile.changed.connect(refresh)
 for definition in MissionCatalog.ALL_ITEMS:
  if definition.map_id != map_id:continue
  definitions.append(definition)
  var row: Control = Row.instantiate()
  $Card/Content/Scroll/Rows.add_child(row)
  row.claim_requested.connect(_claim)
  row.track_requested.connect(_track)
  rows.append(row)
 refresh()

func open() -> void:
 if profile == null or visible:
  return
 show()
 refresh()
 opened.emit()

func close() -> void:
 if not visible:
  return
 $Card/Content/Scroll.stop_scrolling()
 hide()
 closed.emit()

func refresh() -> void:
 if profile == null:
  return
 var complete := 0
 var claimed := 0
 var available: bool = profile.data.missions.started and not profile.incompatible
 for index in definitions.size():
  var definition: MissionDefinition = definitions[index]
  complete += int(MissionProgress.completed(profile.data.missions, definition))
  claimed += int(MissionProgress.entry(profile.data.missions, definition).claimed)
  rows[index].visible = definition.tier == selected_tier
  rows[index].bind(definition, profile.data.missions, available)
 $Card/Content/Summary.text = "สำเร็จ %d / %d   ·   รับรางวัลแล้ว %d / %d   ·   %d เหรียญ" % [complete, definitions.size(), claimed, definitions.size(), profile.data.coins]
 $Card/Content/Message.text = profile.save_error
 $Card/Content/Message.visible = not profile.save_error.is_empty()
 $Card/Content/Retry.visible = not profile.data.missions.started and not profile.incompatible

func _claim(id: String) -> void:
 if profile.claim_mission(id):
  $Card/Content/Message.text = "รับรางวัลแล้ว +%d เหรียญ" % MissionCatalog.find(id).reward_coins
 else:
  $Card/Content/Message.text = profile.save_error if not profile.save_error.is_empty() else "ยังรับรางวัลไม่ได้"
 $Card/Content/Message.show()

func _track(id: String) -> void:
 profile.track_mission("" if profile.data.missions.tracked == id else id)

func _select_tier(index: int) -> void:
 selected_tier = index
 $Card/Content/Scroll.stop_scrolling()
 $Card/Content/Scroll.scroll_vertical = 0
 refresh()

func _retry() -> void:
 profile.start_missions()
 refresh()
