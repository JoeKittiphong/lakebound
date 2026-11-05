extends CanvasLayer
var service: Node
var _finished_shown := false

func _ready() -> void:
 service=get_node_or_null("/root/Competition")
 visible=service!=null and not service.room.is_empty()
 if not visible: set_process(false); return
 service.changed.connect(render)
 $MatchPanel.auto_travel=false
 render()

func _process(_delta: float) -> void:
 if service.room.is_empty():
  get_tree().paused=false
  get_tree().change_scene_to_file("res://features/menu/main_menu.tscn")
  return
 var phase: String=service.phase()
 var left: float=maxf(0.0,float(service.room.ends_at)-service.server_now())
 %Clock.text="%02d:%02d" % [int(left)/60,int(left)%60]
 %Banner.visible=phase!="running"
 %Banner.text={"loading":"กำลังเตรียมสนาม · รอผู้เล่นทุกคน","countdown":"เริ่มใน %d" % ceili(maxf(0,float(service.room.starts_at)-service.server_now())),"finishing":"หมดเวลา · กำลังยืนยันผล","finished":"จบการแข่งขัน","cancelled":"ยกเลิกรอบ","lobby":"กลับห้องเพื่อเตรียมรอบใหม่"}.get(phase,"")
 if phase in ["finished","cancelled","lobby"] and not _finished_shown:
  _finished_shown=true
  $MatchPanel.open()
 if phase in ["loading","countdown","running"]: _finished_shown=false

func render() -> void:
 if service.room.is_empty(): return
 %Connection.text="เชื่อมต่อแล้ว" if service.connected and service.realtime.joined else "กำลังเชื่อมต่อใหม่ · เวลาเดินต่อ"
 %Rule.text=MatchRules.description(service.room)
 %Rule.tooltip_text=%Rule.text
 var members: Array=service.room.members.duplicate()
 members.sort_custom(func(a: Dictionary,b: Dictionary):return int(a.rank)<int(b.rank))
 for i in %Scores.get_child_count():
  var row: HBoxContainer=%Scores.get_child(i)
  row.visible=i<members.size()
  if not row.visible:continue
  var member: Dictionary=members[i]
  row.get_node("Rank").text="%d."%int(member.rank)
  row.get_node("Name").text=str(member.name)+(" · ออก" if member.departed else "")
  row.get_node("Name").tooltip_text=str(member.name)
  row.get_node("Weight").text="%.3f กก."%(float(member.grams)/1000.0)

