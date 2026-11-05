extends Button
var online: Node
var map_id := ""

func bind(service: Node, region: String) -> void:
 if is_instance_valid(online):
  if online.leader_updated.is_connected(_updated): online.leader_updated.disconnect(_updated)
  online.unwatch_map(map_id)
 online = service
 map_id = region
 if online == null:
  present({"loaded": false, "record": {}})
  return
 online.leader_updated.connect(_updated)
 online.watch_map(map_id)

func _exit_tree() -> void:
 if is_instance_valid(online):
  if online.leader_updated.is_connected(_updated): online.leader_updated.disconnect(_updated)
  online.unwatch_map(map_id)

func _updated(region: String, state: Dictionary) -> void:
 if region == map_id: present(state)

func present(state: Dictionary) -> void:
 var record: Dictionary = state.get("record", {})
 $Content/Title.text = "อันดับ 1 · แคช" if state.get("cached", false) else "อันดับ 1 · แผนที่นี้"
 if not state.get("loaded", false):
  $Content/Player.text = "กำลังตรวจอันดับ…" if is_instance_valid(online) and online.enabled and not state.get("failed", false) else "ยังโหลดอันดับไม่ได้"
  $Content/Weight.text = "แตะดูอันดับแผนที่"
 elif record.is_empty():
  $Content/Player.text = "ยังไม่มีผู้ทำสถิติ"
  $Content/Weight.text = "แตะดูอันดับแผนที่"
 else:
  $Content/Player.text = str(record.player_name)
  $Content/Weight.text = "%.3f กก." % float(record.weight)
 tooltip_text = "ดูอันดับแผนที่" if record.is_empty() else "%s · %s · %.3f กก.%s" % [str(record.player_name), str(record.get("name", record.species)), float(record.weight), " · ข้อมูลที่บันทึกไว้" if state.get("cached", false) else ""]
